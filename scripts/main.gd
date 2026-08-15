extends Control

const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const RosterBattleViewScript := preload("res://scripts/ui/roster_battle_view.gd")
const ProceduralAudioScript := preload("res://scripts/audio/procedural_audio.gd")

var battle_view
var seed_value := 20260815
var current_left_id := "vampire"
var current_right_id := "six_king"
var speed_values := [1.0, 2.0, 4.0]
var speed_index := 0

var status_label: Label
var seed_edit: LineEdit
var pause_button: Button
var speed_button: Button
var result_label: Label
var left_title_label: Label
var right_title_label: Label
var left_selector: OptionButton
var right_selector: OptionButton
var procedural_audio: ProceduralBattleAudio
var recording_mode := false
var _recording_quit_scheduled := false
var _startup_valid := true

func _ready() -> void:
	if not BallRegistry.is_valid():
		_fail_startup("球模块注册失败：%s" % ", ".join(BallRegistry.validation_errors()))
		return
	recording_mode = "--render-video" in OS.get_cmdline_user_args()
	if not recording_mode and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(540, 960))
	seed_value = _seed_from_arguments(seed_value)
	current_left_id = _ball_id_from_arguments("--left=", current_left_id)
	current_right_id = _ball_id_from_arguments("--right=", current_right_id)
	if not _startup_valid:
		return
	procedural_audio = ProceduralAudioScript.new()
	add_child(procedural_audio)
	_build_background()
	_build_header()
	_build_battle_view()
	_build_status()
	_build_controls()
	_build_footer()
	_update_status(battle_view.simulation)

func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("030405")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

func _build_header() -> void:
	var kicker := Label.new()
	kicker.text = "ABILITY BALL · 自动演算"
	kicker.position = Vector2(0.0, 58.0)
	kicker.size = Vector2(720.0, 34.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 18)
	kicker.add_theme_color_override("font_color", Color("76808a"))
	add_child(kicker)

	var title := HBoxContainer.new()
	title.position = Vector2(0.0, 106.0)
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

func _replace_battle_view() -> void:
	if battle_view != null:
		remove_child(battle_view)
		battle_view.queue_free()
	if _is_reference_match():
		battle_view = BattleViewScript.new()
	else:
		battle_view = RosterBattleViewScript.new()
	battle_view.position = Vector2(35.0, 190.0)
	battle_view.size = Vector2(650.0, 650.0)
	add_child(battle_view)
	if _is_reference_match():
		battle_view.start_battle(seed_value)
	else:
		battle_view.start_battle(seed_value, current_left_id, current_right_id)
	battle_view.set_simulation_speed(speed_values[speed_index])
	battle_view.state_changed.connect(_update_status)
	battle_view.battle_finished.connect(_on_battle_finished)
	battle_view.combat_event.connect(_on_combat_event)
	_update_title()

func _is_reference_match() -> bool:
	return current_left_id == "vampire" and current_right_id == "six_king"

func _update_title() -> void:
	if left_title_label == null or right_title_label == null:
		return
	left_title_label.text = _module(current_left_id).display_name
	left_title_label.add_theme_color_override("font_color", _module(current_left_id).title_color)
	right_title_label.text = _module(current_right_id).display_name
	right_title_label.add_theme_color_override("font_color", _module(current_right_id).title_color)

func _build_status() -> void:
	status_label = Label.new()
	status_label.position = Vector2(35.0, 858.0)
	status_label.size = Vector2(650.0, 82.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("d8dde2"))
	add_child(status_label)

	result_label = Label.new()
	result_label.position = Vector2(35.0, 938.0)
	result_label.size = Vector2(650.0, 36.0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 17)
	result_label.add_theme_color_override("font_color", Color("ffe257"))
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

	var controls := HBoxContainer.new()
	controls.position = Vector2(35.0, 1042.0)
	controls.size = Vector2(650.0, 52.0)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	add_child(controls)

	pause_button = _make_button("暂停", Vector2(90.0, 46.0))
	pause_button.pressed.connect(_toggle_pause)
	controls.add_child(pause_button)

	speed_button = _make_button("速度 1×", Vector2(100.0, 46.0))
	speed_button.pressed.connect(_cycle_speed)
	controls.add_child(speed_button)

	var restart_button := _make_button("重开", Vector2(78.0, 46.0))
	restart_button.pressed.connect(_restart_same_seed)
	controls.add_child(restart_button)

	var random_button := _make_button("随机种子", Vector2(108.0, 46.0))
	random_button.pressed.connect(_restart_random_seed)
	controls.add_child(random_button)

	seed_edit = LineEdit.new()
	seed_edit.text = str(seed_value)
	seed_edit.placeholder_text = "种子"
	seed_edit.custom_minimum_size = Vector2(130.0, 46.0)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.add_theme_font_size_override("font_size", 17)
	seed_edit.text_submitted.connect(_on_seed_submitted)
	controls.add_child(seed_edit)

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
	_replace_battle_view()
	pause_button.text = "暂停"
	_update_status(battle_view.simulation)

func _make_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 17)
	return button

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

func _update_status(simulation) -> void:
	if status_label == null or simulation == null:
		return
	if simulation is BattleSimulation:
		status_label.text = "时间 %05.1fs　阶段 %d\n吸血鬼 %d / %d　　六王球 %d / %d" % [
			simulation.elapsed, simulation.phase,
			int(ceil(simulation.vampire.hp)), int(simulation.vampire.max_hp),
			int(ceil(simulation.six_king.hp)), int(simulation.six_king.max_hp),
		]
	else:
		status_label.text = "时间 %05.1fs　阶段 %d\n%s %d / %d　　%s %d / %d" % [
			simulation.elapsed, simulation.phase,
			simulation.left.display_name, int(ceil(simulation.left.hp)), int(simulation.left.max_hp),
			simulation.right.display_name, int(ceil(simulation.right.hp)), int(simulation.right.max_hp),
		]

func _on_battle_finished(simulation) -> void:
	var winner_name := ""
	if simulation is BattleSimulation:
		winner_name = simulation.vampire.display_name if simulation.winner_id == "vampire" else simulation.six_king.display_name
	else:
		winner_name = simulation.winner().display_name
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
	_start_seed(seed_value)

func _restart_random_seed() -> void:
	seed_value = int(Time.get_ticks_usec() % 2147483647)
	_start_seed(seed_value)

func _on_seed_submitted(value: String) -> void:
	seed_value = _parse_seed(value, seed_value)
	_start_seed(seed_value)

func _start_seed(value: int) -> void:
	seed_value = value if value != 0 else 20260815
	_recording_quit_scheduled = false
	seed_edit.text = str(seed_value)
	result_label.text = ""
	if _is_reference_match():
		battle_view.start_battle(seed_value)
	else:
		battle_view.start_battle(seed_value, current_left_id, current_right_id)
	battle_view.set_paused(false)
	pause_button.text = "暂停"
	_update_status(battle_view.simulation)

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
