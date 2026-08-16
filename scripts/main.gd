extends Control

const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const ProceduralAudioScript := preload("res://scripts/audio/procedural_audio.gd")
const BallSettingsStoreScript := preload("res://scripts/settings/ball_settings_store.gd")
const BallSettingsDialogScript := preload("res://scripts/ui/ball_settings_dialog.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const GlobalSettingsStoreScript := preload("res://scripts/settings/global_settings_store.gd")
const GlobalSettingsDialogScript := preload("res://scripts/ui/global_settings_dialog.gd")
const BattleLoggerScript := preload("res://scripts/logging/battle_logger.gd")
const LOGICAL_VIEWPORT_SIZE := Vector2i(720, 1280)
const BATTLE_VIEW_POSITION := Vector2(35.0, 190.0)
const RECORDING_TITLE_POSITION := Vector2(0.0, 12.0)
const RECORDING_BATTLE_VIEW_POSITION := Vector2(35.0, 90.0)
const RECORDING_FPS_OPTIONS := [24, 30, 60, 120]
const RESULT_VIEW_GAP := 18.0

var battle_view
var seed_value := 20260815
var time_limit_seconds: float = BattleSimulationScript.DEFAULT_BATTLE_TIME
var battle_arena_size: Vector2 = BattleSimulationScript.DEFAULT_ARENA_SIZE
var recording_fps := GlobalGameSettingsScript.DEFAULT_RECORDING_FPS
var current_left_id := "vampire"
var current_right_id := "six_king"
var speed_values := [1.0, 2.0, 4.0]
var speed_index := 0

var seed_edit: LineEdit
var pause_button: Button
var speed_button: Button
var result_label: Label
var left_title_label: Label
var right_title_label: Label
var left_selector: OptionButton
var right_selector: OptionButton
var record_button: MenuButton
var procedural_audio: ProceduralBattleAudio
var settings_dialog
var global_settings_dialog
var battle_logger: BattleLogger
var recording_mode := false
var _recording_quit_scheduled := false
var _startup_valid := true
var _runtime_settings := {}
var _runtime_global_settings := {}
var _recording_process_id := 0
var _recording_output_path := ""
var _recording_previous_modified_time := 0

func _ready() -> void:
	# Keep UI coordinates stable while Godot rasterizes them into the native 1080×1920 render target.
	get_window().content_scale_size = LOGICAL_VIEWPORT_SIZE
	_apply_global_settings(GlobalSettingsStoreScript.load_settings())
	_runtime_settings = BallSettingsStoreScript.load_settings()
	BallRegistry.configure_settings(_runtime_settings)
	_runtime_settings = BallRegistry.settings_snapshot()
	if not BallRegistry.is_valid():
		_fail_startup("球模块注册失败：%s" % ", ".join(BallRegistry.validation_errors()))
		return
	recording_mode = "--render-video" in OS.get_cmdline_user_args()
	if not recording_mode and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(540, 960))
	seed_value = _seed_from_arguments(seed_value)
	current_left_id = _ball_id_from_arguments("--left=", current_left_id)
	current_right_id = _ball_id_from_arguments("--right=", current_right_id)
	recording_fps = _recording_fps_from_arguments(recording_fps)
	if not _startup_valid:
		return
	battle_logger = BattleLoggerScript.new()
	procedural_audio = ProceduralAudioScript.new()
	add_child(procedural_audio)
	_build_background()
	_build_header()
	_build_battle_view()
	_build_result_label()
	if not recording_mode:
		_build_controls()
		_build_footer()

func _exit_tree() -> void:
	_finish_battle_log("interrupted", "process_exit")

func _process(_delta: float) -> void:
	if _recording_process_id <= 0 or OS.is_process_running(_recording_process_id):
		return
	_recording_process_id = 0
	if record_button != null:
		record_button.disabled = false
		_update_recording_menu()
	var modified_time := FileAccess.get_modified_time(_recording_output_path) \
		if FileAccess.file_exists(_recording_output_path) else 0
	if modified_time > _recording_previous_modified_time:
		result_label.text = "录制完成 · builds/%s" % _recording_output_path.get_file()
	else:
		result_label.text = "录制失败 · 请检查 Godot / FFmpeg 输出"

func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("030405")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

func _build_header() -> void:
	if not recording_mode:
		var kicker := Label.new()
		kicker.text = "ABILITY BALL · 自动演算"
		kicker.position = Vector2(0.0, 58.0)
		kicker.size = Vector2(720.0, 34.0)
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kicker.add_theme_font_size_override("font_size", 18)
		kicker.add_theme_color_override("font_color", Color("76808a"))
		add_child(kicker)

	var title := HBoxContainer.new()
	title.position = RECORDING_TITLE_POSITION if recording_mode else Vector2(0.0, 106.0)
	title.size = Vector2(720.0, 66.0)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 18)
	add_child(title)
	left_title_label = _add_title_label(title, _module(current_left_id).display_name, _module(current_left_id).title_color, 44)
	_add_title_label(title, "VS", Color.WHITE, 39)
	right_title_label = _add_title_label(title, _module(current_right_id).display_name, _module(current_right_id).title_color, 44)

func _add_title_label(parent: Container, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	parent.add_child(label)
	return label

func _build_battle_view() -> void:
	_replace_battle_view()

func _replace_battle_view(end_reason: String = "battle_replaced") -> void:
	if battle_view != null:
		_finish_battle_log("interrupted", end_reason)
		remove_child(battle_view)
		battle_view.queue_free()
	battle_view = BattleViewScript.new()
	battle_view.position = _battle_view_position()
	battle_view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	add_child(battle_view)
	battle_view.start_battle(
		seed_value,
		current_left_id,
		current_right_id,
		time_limit_seconds,
		battle_arena_size
	)
	battle_view.set_simulation_speed(speed_values[speed_index])
	battle_view.battle_finished.connect(_on_battle_finished)
	battle_view.combat_event.connect(_on_combat_event)
	_start_battle_log()
	_update_title()

func _update_title() -> void:
	if left_title_label == null or right_title_label == null:
		return
	left_title_label.text = _module(current_left_id).display_name
	left_title_label.add_theme_color_override("font_color", _module(current_left_id).title_color)
	right_title_label.text = _module(current_right_id).display_name
	right_title_label.add_theme_color_override("font_color", _module(current_right_id).title_color)

func _build_result_label() -> void:
	result_label = Label.new()
	result_label.position = Vector2(
		_battle_view_position().x,
		_battle_view_position().y + BattleViewScript.DEFAULT_VIEW_SIZE.y + RESULT_VIEW_GAP
	)
	result_label.size = Vector2(650.0, 36.0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 17)
	result_label.add_theme_color_override("font_color", Color("ffe257"))
	result_label.visible = not recording_mode
	add_child(result_label)

func _build_controls() -> void:
	var selectors := HBoxContainer.new()
	selectors.position = Vector2(35.0, 985.0)
	selectors.size = Vector2(650.0, 50.0)
	selectors.alignment = BoxContainer.ALIGNMENT_CENTER
	selectors.add_theme_constant_override("separation", 9)
	add_child(selectors)

	left_selector = _make_selector(current_left_id)
	selectors.add_child(left_selector)
	var versus := Label.new()
	versus.text = "VS"
	versus.custom_minimum_size = Vector2(42.0, 46.0)
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	versus.add_theme_font_size_override("font_size", 18)
	versus.add_theme_color_override("font_color", Color("8f9aa3"))
	selectors.add_child(versus)
	right_selector = _make_selector(current_right_id)
	selectors.add_child(right_selector)
	var fight_button := _make_button("开始对战", Vector2(108.0, 46.0))
	fight_button.pressed.connect(_start_selected_match)
	selectors.add_child(fight_button)
	record_button = MenuButton.new()
	record_button.custom_minimum_size = Vector2(86.0, 46.0)
	record_button.add_theme_font_size_override("font_size", 17)
	record_button.tooltip_text = "选择帧率并录制当前完整对局"
	record_button.get_popup().id_pressed.connect(_on_recording_fps_selected)
	_update_recording_menu()
	selectors.add_child(record_button)

	var controls := HBoxContainer.new()
	controls.position = Vector2(35.0, 1042.0)
	controls.size = Vector2(650.0, 52.0)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	add_child(controls)

	pause_button = _make_button("暂停", Vector2(64.0, 46.0))
	pause_button.pressed.connect(_toggle_pause)
	controls.add_child(pause_button)

	speed_button = _make_button("速度 1×", Vector2(80.0, 46.0))
	speed_button.pressed.connect(_cycle_speed)
	controls.add_child(speed_button)

	var restart_button := _make_button("重开", Vector2(60.0, 46.0))
	restart_button.pressed.connect(_restart_same_seed)
	controls.add_child(restart_button)

	var random_button := _make_button("随机种子", Vector2(86.0, 46.0))
	random_button.pressed.connect(_restart_random_seed)
	controls.add_child(random_button)

	seed_edit = LineEdit.new()
	seed_edit.text = str(seed_value)
	seed_edit.placeholder_text = "种子"
	seed_edit.custom_minimum_size = Vector2(105.0, 46.0)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.add_theme_font_size_override("font_size", 17)
	seed_edit.text_submitted.connect(_on_seed_submitted)
	controls.add_child(seed_edit)

	var global_settings_button := _make_button("全局设置", Vector2(84.0, 46.0))
	global_settings_button.pressed.connect(_open_global_settings)
	controls.add_child(global_settings_button)

	var settings_button := _make_button("球参数", Vector2(76.0, 46.0))
	settings_button.pressed.connect(_open_ball_settings)
	controls.add_child(settings_button)

func _make_selector(selected_id: String) -> OptionButton:
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(185.0, 46.0)
	selector.add_theme_font_size_override("font_size", 17)
	for ball_id in BallRegistry.ids():
		var index := selector.item_count
		selector.add_item(_module(ball_id).display_name)
		selector.set_item_metadata(index, ball_id)
		if ball_id == selected_id:
			selector.select(index)
	return selector

func _start_selected_match() -> void:
	current_left_id = String(left_selector.get_item_metadata(left_selector.selected))
	current_right_id = String(right_selector.get_item_metadata(right_selector.selected))
	seed_value = _parse_seed(seed_edit.text, seed_value)
	_recording_quit_scheduled = false
	result_label.text = ""
	_replace_battle_view("selection_changed")
	pause_button.text = "暂停"

func _make_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 17)
	return button

func _on_recording_fps_selected(fps: int) -> void:
	recording_fps = clampi(fps, 24, 120)
	_runtime_global_settings["recording_fps"] = recording_fps
	var configuration = GlobalGameSettingsScript.new(_runtime_global_settings)
	_runtime_global_settings = configuration.settings_snapshot()
	recording_fps = configuration.settingi("recording_fps")
	GlobalSettingsStoreScript.save_settings(_runtime_global_settings)
	_update_recording_menu()
	_record_current_battle()

func _update_recording_menu() -> void:
	if record_button == null:
		return
	record_button.text = "录制 %d帧" % recording_fps
	var popup := record_button.get_popup()
	popup.clear()
	var fps_options := RECORDING_FPS_OPTIONS.duplicate()
	if not fps_options.has(recording_fps):
		fps_options.append(recording_fps)
		fps_options.sort()
	for fps in fps_options:
		popup.add_check_item("%d FPS" % fps, fps)
		popup.set_item_checked(popup.item_count - 1, fps == recording_fps)

func _record_current_battle() -> void:
	if recording_mode or _recording_process_id > 0:
		return
	var script_path := ProjectSettings.globalize_path("res://tools/render_video.sh")
	if not FileAccess.file_exists(script_path):
		result_label.text = "录制失败 · 找不到录制脚本"
		return
	var recording_seed: int = battle_view.simulation.seed_value
	var recording_left_id: String = battle_view.simulation.left.id
	var recording_right_id: String = battle_view.simulation.right.id
	var recording_time_limit := int(round(battle_view.simulation.max_battle_time))
	_recording_output_path = _video_output_path(recording_seed, recording_left_id, recording_right_id)
	_recording_previous_modified_time = FileAccess.get_modified_time(_recording_output_path) \
		if FileAccess.file_exists(_recording_output_path) else 0
	var shell_path := OS.get_environment("SHELL")
	if shell_path.is_empty() or not FileAccess.file_exists(shell_path):
		shell_path = "/bin/bash"
	var arguments := PackedStringArray([
		"-l",
		script_path,
		str(recording_seed),
		recording_left_id,
		recording_right_id,
		str(recording_time_limit),
		str(recording_fps),
	])
	_recording_process_id = OS.create_process(shell_path, arguments)
	if _recording_process_id <= 0:
		result_label.text = "录制失败 · 无法启动后台进程"
		return
	record_button.disabled = true
	record_button.text = "录制中…"
	result_label.text = "正在后台录制本局…"

func _video_output_path(seed: int, left_ball_id: String, right_ball_id: String) -> String:
	var output_slug := "ability-ball-seed-%d" % seed
	if left_ball_id != "vampire" or right_ball_id != "six_king":
		output_slug = "ability-ball-%s-vs-%s-seed-%d" % [left_ball_id, right_ball_id, seed]
	return ProjectSettings.globalize_path("res://builds/%s.mp4" % output_slug)

func _battle_view_position() -> Vector2:
	return RECORDING_BATTLE_VIEW_POSITION if recording_mode else BATTLE_VIEW_POSITION

func _open_ball_settings() -> void:
	if settings_dialog == null:
		settings_dialog = BallSettingsDialogScript.new()
		settings_dialog.settings_submitted.connect(_on_ball_settings_submitted)
		add_child(settings_dialog)
	var preferred_id := current_left_id
	if left_selector != null and left_selector.selected >= 0:
		preferred_id = String(left_selector.get_item_metadata(left_selector.selected))
	settings_dialog.open_settings(_runtime_settings, preferred_id)

func _on_ball_settings_submitted(settings: Dictionary) -> void:
	_finish_battle_log("interrupted", "ball_settings_changed")
	BallRegistry.configure_settings(settings)
	_runtime_settings = BallRegistry.settings_snapshot()
	var save_error: Error = BallSettingsStoreScript.save_settings(_runtime_settings)
	if save_error != OK:
		result_label.text = "参数已应用，但保存失败：%s" % error_string(save_error)
	else:
		result_label.text = "球参数已保存并应用"
	_replace_battle_view("ball_settings_changed")
	pause_button.text = "暂停"

func _open_global_settings() -> void:
	if global_settings_dialog == null:
		global_settings_dialog = GlobalSettingsDialogScript.new()
		global_settings_dialog.settings_submitted.connect(_on_global_settings_submitted)
		add_child(global_settings_dialog)
	global_settings_dialog.open_settings(_runtime_global_settings)

func _on_global_settings_submitted(settings: Dictionary) -> void:
	_finish_battle_log("interrupted", "global_settings_changed")
	_apply_global_settings(settings)
	var save_error: Error = GlobalSettingsStoreScript.save_settings(_runtime_global_settings)
	if save_error != OK:
		result_label.text = "全局设置已应用，但保存失败：%s" % error_string(save_error)
	else:
		result_label.text = "全局设置已保存并应用"
	_replace_battle_view("global_settings_changed")
	pause_button.text = "暂停"

func _apply_global_settings(settings: Dictionary) -> void:
	var configuration = GlobalGameSettingsScript.new(settings)
	_runtime_global_settings = configuration.settings_snapshot()
	time_limit_seconds = _time_limit_from_arguments(configuration.settingf("battle_time_seconds"))
	battle_arena_size = configuration.arena_size()
	recording_fps = configuration.settingi("recording_fps")
	_update_recording_menu()

func _build_footer() -> void:
	var instructions := Label.new()
	instructions.text = "空格：暂停　R：重开　N：随机　1/2/4：速度"
	instructions.position = Vector2(0.0, 1110.0)
	instructions.size = Vector2(720.0, 34.0)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.add_theme_color_override("font_color", Color("79838c"))
	add_child(instructions)

	var brand := Label.new()
	brand.text = "原创程序化战斗 · 固定种子可复现"
	brand.position = Vector2(0.0, 1188.0)
	brand.size = Vector2(720.0, 32.0)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 15)
	brand.add_theme_color_override("font_color", Color("4e5962"))
	add_child(brand)

func _on_battle_finished(simulation) -> void:
	_finish_battle_log("completed", simulation.finish_reason)
	var winner_name: String = simulation.winner().display_name
	result_label.text = "%s获胜 · %s · 种子 %d" % [winner_name, simulation.finish_reason, simulation.seed_value]
	if recording_mode and not _recording_quit_scheduled:
		_recording_quit_scheduled = true
		_quit_after_result()

func _on_combat_event(kind: String, strength: float) -> void:
	procedural_audio.play_event(kind, strength)

func _quit_after_result() -> void:
	await get_tree().create_timer(2.0).timeout
	procedural_audio.shutdown()
	await get_tree().process_frame
	get_tree().quit()

func _toggle_pause() -> void:
	battle_view.set_paused(not battle_view.paused)
	pause_button.text = "继续" if battle_view.paused else "暂停"

func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % speed_values.size()
	_apply_speed(speed_values[speed_index])

func _apply_speed(speed: float) -> void:
	var found_index := speed_values.find(speed)
	if found_index >= 0:
		speed_index = found_index
	battle_view.set_simulation_speed(speed)
	speed_button.text = "速度 %d×" % int(speed)

func _restart_same_seed() -> void:
	seed_value = _parse_seed(seed_edit.text, seed_value)
	_start_seed(seed_value, "same_seed_restart")

func _restart_random_seed() -> void:
	seed_value = int(Time.get_ticks_usec() % 2147483647)
	_start_seed(seed_value, "random_seed_restart")

func _on_seed_submitted(value: String) -> void:
	seed_value = _parse_seed(value, seed_value)
	_start_seed(seed_value, "submitted_seed_restart")

func _start_seed(value: int, end_reason: String) -> void:
	_finish_battle_log("interrupted", end_reason)
	seed_value = value if value != 0 else 20260815
	_recording_quit_scheduled = false
	seed_edit.text = str(seed_value)
	result_label.text = ""
	battle_view.start_battle(
		seed_value,
		current_left_id,
		current_right_id,
		time_limit_seconds,
		battle_arena_size
	)
	_start_battle_log()
	battle_view.set_paused(false)
	pause_button.text = "暂停"

func _parse_seed(text: String, fallback: int) -> int:
	if text.is_valid_int():
		var parsed := text.to_int()
		return parsed if parsed != 0 else 20260815
	return fallback

func _seed_from_arguments(fallback: int) -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			return _parse_seed(argument.trim_prefix("--seed="), fallback)
	return fallback

func _time_limit_from_arguments(fallback: float) -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--time-limit="):
			var value := argument.trim_prefix("--time-limit=")
			if value.is_valid_float():
				return clampf(value.to_float(), 15.0, 600.0)
	return fallback

func _recording_fps_from_arguments(fallback: int) -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--recording-fps="):
			var value := argument.trim_prefix("--recording-fps=")
			if value.is_valid_int():
				return clampi(value.to_int(), 24, 120)
	return fallback

func _start_battle_log() -> void:
	if battle_logger == null or battle_view == null or battle_view.simulation == null:
		return
	var simulation: BattleSimulation = battle_view.simulation
	var log_error := battle_logger.begin(simulation, {
		"mode": "recording" if recording_mode else "interactive",
		"global_settings": _runtime_global_settings,
		"all_ball_settings": _runtime_settings,
		"recording": {
			"fps": recording_fps,
			"video_output_path": _video_output_path(
				simulation.seed_value,
				simulation.left.id,
				simulation.right.id
			) if recording_mode else "",
		},
		"view": {
			"size": battle_view.size,
			"position": battle_view.position,
			"visible_world_size": battle_view.visible_world_size(),
			"arena_screen_rect": battle_view.arena_screen_rect(),
		},
	})
	if log_error != OK:
		push_warning("对局开始日志写入失败：%s" % error_string(log_error))

func _finish_battle_log(outcome: String, reason: String) -> void:
	if battle_logger == null or battle_view == null or battle_view.simulation == null:
		return
	var log_error := battle_logger.finish(battle_view.simulation, outcome, reason)
	if log_error != OK:
		push_warning("对局结束日志写入失败：%s" % error_string(log_error))

func _ball_id_from_arguments(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			var ball_id := argument.trim_prefix(prefix)
			if not BallRegistry.has_id(ball_id):
				_fail_startup("未知球 ID：%s。可用：%s" % [ball_id, " ".join(BallRegistry.ids())])
				return fallback
			return ball_id
	return fallback

func _module(ball_id: String) -> BallModule:
	return BallRegistry.get_module(ball_id)

func _fail_startup(message: String) -> void:
	_startup_valid = false
	push_error(message)
	get_tree().quit(2)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_SPACE:
		_toggle_pause()
	elif event.keycode == KEY_R:
		_restart_same_seed()
	elif event.keycode == KEY_N:
		_restart_random_seed()
	elif event.keycode == KEY_1:
		_apply_speed(1.0)
	elif event.keycode == KEY_2:
		_apply_speed(2.0)
	elif event.keycode == KEY_4:
		_apply_speed(4.0)
