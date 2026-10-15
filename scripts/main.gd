extends Control

const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const ProceduralAudioScript := preload("res://scripts/audio/procedural_audio.gd")
const BallSettingsStoreScript := preload("res://scripts/settings/ball_settings_store.gd")
const BallSettingsDialogScript := preload("res://scripts/ui/ball_settings_dialog.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const GlobalSettingsStoreScript := preload("res://scripts/settings/global_settings_store.gd")
const GlobalSettingsDialogScript := preload("res://scripts/ui/global_settings_dialog.gd")
const BallPickerDialogScript := preload("res://scripts/ui/ball_picker_dialog.gd")
const ModeRosterEditorScript := preload("res://scripts/ui/mode_roster_editor.gd")
const BattleLoggerScript := preload("res://scripts/logging/battle_logger.gd")
const RecordingAbilityTickerScript := preload("res://scripts/ui/recording_ability_ticker.gd")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")
const RECORDING_LOGICAL_VIEWPORT_SIZE := Vector2i(720, 1280)
const INTERACTIVE_LOGICAL_VIEWPORT_SIZE := Vector2i(1180, 1280)
const INTERACTIVE_WINDOW_SIZE := Vector2i(885, 960)
const INTERACTIVE_BATTLE_CONTENT_X := 460.0
const INTERACTIVE_BATTLE_VIEW_X := 495.0
const INTERACTIVE_BATTLE_CENTER_Y := 727.0
const INTERACTIVE_BATTLE_TOP := 174.0
const INTERACTIVE_BATTLE_BOTTOM := 1280.0
const CONFIG_SIDEBAR_POSITION := Vector2(18.0, 30.0)
const CONFIG_SIDEBAR_SIZE := Vector2(420.0, 1200.0)
const RECORDING_TITLE_POSITION := Vector2(0.0, 32.0)
const RECORDING_BATTLE_VIEW_X := 35.0
const RECORDING_BATTLE_CENTER_Y := 650.0
const RECORDING_LAYOUT_TOP := 86.0
const RECORDING_LAYOUT_BOTTOM := 1272.0
const RECORDING_SECTION_GAP := 8.0
const RECORDING_TICKER_MIN_HEIGHT := 70.0
const RECORDING_FPS_OPTIONS := [24, 30, 60, 120]
const RESULT_VIEW_GAP := 18.0

var battle_view
var battle_idle_view: Control
var seed_value := 20260815
var time_limit_seconds: float = BattleSimulationScript.DEFAULT_BATTLE_TIME
var battle_arena_size: Vector2 = BattleSimulationScript.DEFAULT_ARENA_SIZE
var recording_fps := GlobalGameSettingsScript.DEFAULT_RECORDING_FPS
var result_reveal_delay_seconds := GlobalGameSettingsScript.DEFAULT_RESULT_REVEAL_DELAY
var relay_handoff_pause_seconds := GlobalGameSettingsScript.DEFAULT_RELAY_HANDOFF_PAUSE
var relay_defeat_text_font_size := GlobalGameSettingsScript.DEFAULT_RELAY_DEFEAT_TEXT_FONT_SIZE
var damage_number_font_size := GlobalGameSettingsScript.DEFAULT_DAMAGE_NUMBER_FONT_SIZE
var damage_number_duration_seconds := GlobalGameSettingsScript.DEFAULT_DAMAGE_NUMBER_DURATION
var current_left_id := "vampire"
var current_right_id := "wdc"
var battle_mode := BattleSetupScript.MODE_DUEL
var team_rosters: Array = []
var team_names: Array[String] = []
var speed_values := [1.0, 2.0, 4.0]
var speed_index := 0

var seed_edit: LineEdit
var pause_button: Button
var speed_button: Button
var result_label: Label
var left_title_label: Label
var right_title_label: Label
var mode_title_label: Label
var mode_selector: OptionButton
var mode_profile_label: Label
var mode_roster_editor
var record_button: MenuButton
var procedural_audio: ProceduralBattleAudio
var settings_dialog
var global_settings_dialog
var ball_picker_dialog
var recording_ability_ticker
var battle_logger: BattleLogger
var recording_mode := false
var _recording_quit_scheduled := false
var _startup_valid := true
var _runtime_settings := {}
var _runtime_global_settings := {}
var _recording_process_id := 0
var _recording_output_path := ""
var _recording_previous_modified_time := 0
var _mode_rosters := {}
var _mode_team_names := {}
var _ball_picker_request := {}

func _ready() -> void:
	_install_ui_font()
	recording_mode = "--render-video" in OS.get_cmdline_user_args()
	# Recording keeps the 720×1280 vertical master; the editor gets a wider logical canvas for its sidebar.
	get_window().content_scale_size = RECORDING_LOGICAL_VIEWPORT_SIZE \
		if recording_mode else INTERACTIVE_LOGICAL_VIEWPORT_SIZE
	battle_mode = _battle_mode_from_arguments(battle_mode)
	_load_ball_settings_for_mode()
	if not BallRegistry.is_valid():
		_fail_startup("球模块注册失败：%s" % ", ".join(BallRegistry.validation_errors()))
		return
	var missing_font_characters := CjkFontProviderScript.missing_characters(
		CjkFontProviderScript.validation_source(BallRegistry.modules())
	)
	if not missing_font_characters.is_empty():
		_fail_startup("中文字体缺少球名称或简介字形：%s" % missing_font_characters)
		return
	if not recording_mode and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(INTERACTIVE_WINDOW_SIZE)
	seed_value = _seed_from_arguments(seed_value)
	current_left_id = _ball_id_from_arguments("--left=", current_left_id)
	current_right_id = _ball_id_from_arguments("--right=", current_right_id)
	_apply_global_settings(GlobalSettingsStoreScript.load_mode_settings(battle_mode))
	_initialize_mode_rosters(_team_rosters_from_arguments())
	_initialize_mode_team_names(_team_names_from_arguments())
	recording_fps = _recording_fps_from_arguments(recording_fps)
	if not _startup_valid:
		return
	battle_logger = BattleLoggerScript.new()
	procedural_audio = ProceduralAudioScript.new()
	procedural_audio.configure_samples(BallRegistry.audio_samples())
	add_child(procedural_audio)
	_build_background()
	_build_header()
	_build_battle_view()
	_build_result_label()
	if recording_mode:
		_build_recording_ability_ticker()
		_build_recording_watermark()
	if not recording_mode:
		_build_controls()

func _install_ui_font() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = CjkFontProviderScript.font()
	theme = ui_theme

func _exit_tree() -> void:
	_finish_battle_log("interrupted", "process_exit")

func _process(_delta: float) -> void:
	_sync_recording_ability_ticker()
	if _recording_process_id <= 0 or OS.is_process_running(_recording_process_id):
		return
	_recording_process_id = 0
	if record_button != null:
		_update_recording_menu()
		_update_battle_action_state()
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
		kicker.text = "能力球 · 原作者：萝卜菌_Channel"
		kicker.position = Vector2(INTERACTIVE_BATTLE_CONTENT_X, 58.0)
		kicker.size = Vector2(720.0, 34.0)
		kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kicker.add_theme_font_size_override("font_size", 18)
		kicker.add_theme_color_override("font_color", Color("76808a"))
		add_child(kicker)

	var title := HBoxContainer.new()
	title.position = RECORDING_TITLE_POSITION \
		if recording_mode else Vector2(INTERACTIVE_BATTLE_CONTENT_X, 106.0)
	title.size = Vector2(720.0, 50.0 if recording_mode else 66.0)
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 18)
	add_child(title)
	var title_font_size := 36 if recording_mode else 44
	left_title_label = _add_title_label(title, _module(current_left_id).display_name, _module(current_left_id).title_color, title_font_size)
	mode_title_label = _add_title_label(title, "VS", Color.WHITE, 32 if recording_mode else 39)
	right_title_label = _add_title_label(title, _module(current_right_id).display_name, _module(current_right_id).title_color, title_font_size)

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
	if recording_mode:
		_replace_battle_view("recording_startup")
	else:
		_show_battle_idle_state()

func _build_recording_watermark() -> void:
	var watermark := Label.new()
	watermark.name = "RecordingWatermark"
	watermark.text = "开源游戏作者：萝卜菌_Channel"
	watermark.position = Vector2(24.0, 4.0)
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	watermark.add_theme_font_size_override("font_size", 18)
	watermark.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.7))
	watermark.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	watermark.add_theme_constant_override("shadow_offset_x", 1)
	watermark.add_theme_constant_override("shadow_offset_y", 1)
	add_child(watermark)

func _build_recording_ability_ticker() -> void:
	recording_ability_ticker = RecordingAbilityTickerScript.new()
	add_child(recording_ability_ticker)
	_sync_battle_layout()
	_sync_recording_ability_ticker()

func _sync_recording_ability_ticker() -> void:
	if recording_ability_ticker == null or battle_view == null or battle_view.simulation == null:
		return
	var fighters: Array = battle_view.simulation.active_fighters()
	fighters.sort_custom(func(left, right) -> bool:
		if left.team_id != right.team_id:
			return left.team_id < right.team_id
		return left.fighter_uid < right.fighter_uid
	)
	var entries: Array[Dictionary] = []
	var seen_ball_ids := {}
	for fighter in fighters:
		if fighter.hp <= 0.0 or seen_ball_ids.has(fighter.id):
			continue
		seen_ball_ids[fighter.id] = true
		var module: BallModule = battle_view.simulation.module_for_fighter(fighter)
		entries.append({
			"id": module.id,
			"name": module.display_name,
			"description": module.formatted_ability_description(),
			"color": module.title_color,
		})
	if not entries.is_empty():
		recording_ability_ticker.set_entries(entries)

func _show_battle_idle_state(end_reason: String = "battle_returned_to_setup") -> void:
	_remove_active_battle(end_reason)
	if battle_idle_view == null:
		battle_idle_view = PanelContainer.new()
		battle_idle_view.name = "BattleIdleView"
		battle_idle_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var idle_style := StyleBoxFlat.new()
		idle_style.bg_color = Color("05090b")
		idle_style.border_color = Color("31414a")
		idle_style.set_border_width_all(2)
		idle_style.set_corner_radius_all(4)
		battle_idle_view.add_theme_stylebox_override("panel", idle_style)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		battle_idle_view.add_child(center)
		var content := VBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 12)
		center.add_child(content)
		var play_icon := Label.new()
		play_icon.text = "▶"
		play_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play_icon.add_theme_font_size_override("font_size", 54)
		play_icon.add_theme_color_override("font_color", Color("76dcff"))
		content.add_child(play_icon)
		var idle_label := Label.new()
		idle_label.text = "选择玩法和阵容，然后开始对战"
		idle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		idle_label.add_theme_font_size_override("font_size", 20)
		idle_label.add_theme_color_override("font_color", Color("9aa7ae"))
		content.add_child(idle_label)
		add_child(battle_idle_view)
	_sync_battle_layout()
	battle_idle_view.show()
	_update_battle_action_state()

func _remove_active_battle(end_reason: String) -> void:
	if procedural_audio != null:
		procedural_audio.stop_all_looped_sample_events()
	if battle_view == null:
		return
	_finish_battle_log("interrupted", end_reason)
	if battle_view.get_parent() == self:
		remove_child(battle_view)
	battle_view.queue_free()
	battle_view = null

func _remove_battle_idle_view() -> void:
	if battle_idle_view == null:
		return
	if battle_idle_view.get_parent() == self:
		remove_child(battle_idle_view)
	battle_idle_view.queue_free()
	battle_idle_view = null

func _has_active_battle() -> bool:
	return battle_view != null and battle_view.simulation != null

func _update_battle_action_state() -> void:
	var active := _has_active_battle()
	if pause_button != null:
		pause_button.disabled = not active
		if not active:
			pause_button.text = "暂停"
	if record_button != null:
		record_button.disabled = not active or _recording_process_id > 0

func _replace_battle_view(end_reason: String = "battle_replaced") -> void:
	_remove_active_battle(end_reason)
	_remove_battle_idle_view()
	battle_view = BattleViewScript.new()
	battle_view.result_auto_scroll = true
	battle_view.position = _battle_view_position()
	battle_view.size = _battle_view_size()
	battle_view.result_reveal_delay_seconds = result_reveal_delay_seconds
	battle_view.relay_handoff_pause_seconds = relay_handoff_pause_seconds
	battle_view.relay_defeat_text_font_size = relay_defeat_text_font_size
	battle_view.damage_number_font_size = damage_number_font_size
	battle_view.damage_number_duration_seconds = damage_number_duration_seconds
	add_child(battle_view)
	battle_view.start_battle_setup(
		seed_value,
		_current_battle_setup(),
		time_limit_seconds,
		battle_arena_size,
		{}
	)
	_sync_battle_layout()
	battle_view.set_simulation_speed(speed_values[speed_index])
	battle_view.battle_resolved.connect(_on_battle_resolved)
	battle_view.battle_finished.connect(_on_battle_finished)
	battle_view.combat_event.connect(_on_combat_event)
	_start_battle_log()
	_update_title()
	_update_battle_action_state()

func _update_title() -> void:
	if left_title_label == null or right_title_label == null or mode_title_label == null:
		return
	if battle_mode == BattleSetupScript.MODE_DUEL:
		left_title_label.text = _module(current_left_id).display_name
		left_title_label.add_theme_color_override("font_color", _module(current_left_id).title_color)
		mode_title_label.text = "VS"
		right_title_label.text = _module(current_right_id).display_name
		right_title_label.add_theme_color_override("font_color", _module(current_right_id).title_color)
	elif battle_mode in [BattleSetupScript.MODE_RELAY, BattleSetupScript.MODE_TEAM_BRAWL]:
		left_title_label.text = "%s(%d球)" % [_current_team_name(0), team_rosters[0].size()]
		left_title_label.add_theme_color_override("font_color", BattleSetupScript.RELAY_RED_TEAM_COLOR)
		mode_title_label.text = _battle_mode_display_name()
		right_title_label.text = "%s(%d球)" % [_current_team_name(1), team_rosters[1].size()]
		right_title_label.add_theme_color_override("font_color", BattleSetupScript.RELAY_BLUE_TEAM_COLOR)
	else:
		var fighter_count := 0
		for roster in team_rosters:
			fighter_count += roster.size()
		left_title_label.text = "%d队" % team_rosters.size()
		left_title_label.add_theme_color_override("font_color", Color("8ee7ff"))
		mode_title_label.text = _battle_mode_display_name()
		right_title_label.text = "%d球" % fighter_count
		right_title_label.add_theme_color_override("font_color", Color("f1f5f7"))

func _default_rosters_for_mode(mode: String) -> Array:
	var fallback_third := "test_ball" if BallRegistry.has_id("test_ball") else BallRegistry.ids()[0]
	return [[current_left_id], [current_right_id], [fallback_third]] \
		if BattleSetupScript.is_free_for_all_mode(mode) \
		else [[current_left_id], [current_right_id]]

func _initialize_mode_rosters(requested_rosters: Array) -> void:
	_mode_rosters.clear()
	for mode in BattleSetupScript.SUPPORTED_MODES:
		_mode_rosters[mode] = _default_rosters_for_mode(mode)
	if not requested_rosters.is_empty():
		_mode_rosters[battle_mode] = requested_rosters.duplicate(true)
	_load_current_mode_rosters()

func _store_current_mode_rosters() -> void:
	if battle_mode in BattleSetupScript.SUPPORTED_MODES and not team_rosters.is_empty():
		_mode_rosters[battle_mode] = team_rosters.duplicate(true)

func _load_current_mode_rosters() -> void:
	team_rosters = (_mode_rosters.get(battle_mode, _default_rosters_for_mode(battle_mode)) as Array).duplicate(true)
	_sync_primary_ball_ids()

func _default_team_names_for_mode(mode: String) -> Array[String]:
	var names: Array[String] = []
	var rosters: Array = _mode_rosters.get(mode, _default_rosters_for_mode(mode))
	for team_index in range(rosters.size()):
		names.append(BattleSetupScript.default_team_name(mode, team_index))
	return names

func _normalize_team_names_for_mode(mode: String, requested_names: Array, team_count: int) -> Array[String]:
	var normalized: Array[String] = []
	for team_index in range(team_count):
		var raw_name := String(requested_names[team_index]) \
			if mode != BattleSetupScript.MODE_DUEL and team_index < requested_names.size() else ""
		normalized.append(BattleSetupScript.sanitize_team_name(raw_name, mode, team_index))
	return normalized

func _initialize_mode_team_names(requested_names: Array) -> void:
	_mode_team_names.clear()
	for mode in BattleSetupScript.SUPPORTED_MODES:
		_mode_team_names[mode] = _default_team_names_for_mode(mode)
	if battle_mode != BattleSetupScript.MODE_DUEL and not requested_names.is_empty():
		_mode_team_names[battle_mode] = _normalize_team_names_for_mode(
			battle_mode,
			requested_names,
			team_rosters.size()
		)
	_load_current_mode_team_names()

func _store_current_mode_team_names() -> void:
	if battle_mode in BattleSetupScript.SUPPORTED_MODES and not team_names.is_empty():
		_mode_team_names[battle_mode] = team_names.duplicate()

func _load_current_mode_team_names() -> void:
	var requested_names: Array = _mode_team_names.get(battle_mode, _default_team_names_for_mode(battle_mode))
	team_names = _normalize_team_names_for_mode(battle_mode, requested_names, team_rosters.size())

func _current_team_name(team_index: int) -> String:
	if team_index >= 0 and team_index < team_names.size():
		return team_names[team_index]
	return BattleSetupScript.default_team_name(battle_mode, team_index)

func _sync_primary_ball_ids() -> void:
	if team_rosters.size() < 2 or team_rosters[0].is_empty() or team_rosters[1].is_empty():
		return
	current_left_id = String(team_rosters[0][0])
	current_right_id = String(team_rosters[1][0])

func _current_battle_setup():
	match battle_mode:
		BattleSetupScript.MODE_RELAY:
			return BattleSetupScript.relay(team_rosters[0], team_rosters[1], team_names)
		BattleSetupScript.MODE_FREE_FOR_ALL:
			return BattleSetupScript.free_for_all(team_rosters, team_names)
		BattleSetupScript.MODE_BOSS:
			return BattleSetupScript.boss(team_rosters, team_names)
		BattleSetupScript.MODE_TEAM_BRAWL:
			return BattleSetupScript.team_brawl(team_rosters[0], team_rosters[1], team_names)
	return BattleSetupScript.duel(current_left_id, current_right_id)

func _battle_mode_display_name() -> String:
	match battle_mode:
		BattleSetupScript.MODE_RELAY:
			return "擂台"
		BattleSetupScript.MODE_FREE_FOR_ALL:
			return "自由混战"
		BattleSetupScript.MODE_BOSS:
			return "BOSS 战"
		BattleSetupScript.MODE_TEAM_BRAWL:
			return "团队混战"
	return "单挑"

func _build_result_label() -> void:
	result_label = Label.new()
	result_label.position = Vector2(
		_battle_view_position().x,
		_battle_view_position().y + _battle_view_size().y + RESULT_VIEW_GAP
	)
	result_label.size = Vector2(_battle_view_size().x, 36.0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 17)
	result_label.add_theme_color_override("font_color", Color("ffe257"))
	result_label.visible = not recording_mode
	add_child(result_label)

func _build_controls() -> void:
	var sidebar := PanelContainer.new()
	sidebar.name = "ConfigSidebar"
	sidebar.position = CONFIG_SIDEBAR_POSITION
	sidebar.size = CONFIG_SIDEBAR_SIZE
	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = Color("070b0e")
	sidebar_style.border_color = Color("31414a")
	sidebar_style.set_border_width_all(2)
	sidebar_style.set_corner_radius_all(14)
	sidebar_style.content_margin_left = 16.0
	sidebar_style.content_margin_right = 16.0
	sidebar_style.content_margin_top = 16.0
	sidebar_style.content_margin_bottom = 16.0
	sidebar.add_theme_stylebox_override("panel", sidebar_style)
	add_child(sidebar)

	var content := VBoxContainer.new()
	content.name = "ConfigSidebarContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	sidebar.add_child(content)

	var sidebar_title := Label.new()
	sidebar_title.text = "对战控制台"
	sidebar_title.add_theme_font_size_override("font_size", 28)
	sidebar_title.add_theme_color_override("font_color", Color("f1f6f8"))
	content.add_child(sidebar_title)
	var sidebar_hint := Label.new()
	sidebar_hint.text = "先配置本局阵容，再开始或录制"
	sidebar_hint.add_theme_font_size_override("font_size", 15)
	sidebar_hint.add_theme_color_override("font_color", Color("7f8d96"))
	content.add_child(sidebar_hint)
	content.add_child(HSeparator.new())
	content.add_child(_make_sidebar_section_label("玩法与阵容"))

	mode_selector = OptionButton.new()
	mode_selector.name = "BattleModeSelector"
	mode_selector.custom_minimum_size = Vector2(0.0, 46.0)
	mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_selector.add_theme_font_size_override("font_size", 17)
	for mode_entry in [
		["单挑", BattleSetupScript.MODE_DUEL],
		["擂台接力", BattleSetupScript.MODE_RELAY],
		["多方混战", BattleSetupScript.MODE_FREE_FOR_ALL],
		["双方大混战", BattleSetupScript.MODE_TEAM_BRAWL],
		["BOSS 战", BattleSetupScript.MODE_BOSS],
	]:
		mode_selector.add_item(mode_entry[0])
		mode_selector.set_item_metadata(mode_selector.item_count - 1, mode_entry[1])
		if mode_entry[1] == battle_mode:
			mode_selector.select(mode_selector.item_count - 1)
	mode_selector.item_selected.connect(_on_battle_mode_selected)
	content.add_child(mode_selector)
	mode_profile_label = Label.new()
	mode_profile_label.name = "ModeProfileLabel"
	mode_profile_label.custom_minimum_size = Vector2(0.0, 42.0)
	mode_profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_profile_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_profile_label.add_theme_font_size_override("font_size", 15)
	mode_profile_label.add_theme_color_override("font_color", Color("8f9aa3"))
	content.add_child(mode_profile_label)

	mode_roster_editor = ModeRosterEditorScript.new()
	mode_roster_editor.custom_minimum_size = Vector2(0.0, 420.0)
	mode_roster_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_roster_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_roster_editor.add_ball_requested.connect(_on_roster_add_requested)
	mode_roster_editor.replace_ball_requested.connect(_on_roster_replace_requested)
	mode_roster_editor.remove_ball_requested.connect(_on_roster_remove_requested)
	mode_roster_editor.move_ball_requested.connect(_on_roster_move_requested)
	mode_roster_editor.add_team_requested.connect(_on_add_team_requested)
	mode_roster_editor.remove_team_requested.connect(_on_remove_team_requested)
	mode_roster_editor.team_name_changed.connect(_on_team_name_changed)
	content.add_child(mode_roster_editor)

	var actions := HBoxContainer.new()
	actions.name = "PrimaryBattleActions"
	actions.custom_minimum_size = Vector2(0.0, 48.0)
	actions.add_theme_constant_override("separation", 12)
	content.add_child(actions)
	var fight_button := _make_button("开始对战", Vector2(0.0, 48.0))
	fight_button.name = "StartBattleButton"
	fight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fight_button.pressed.connect(_start_selected_match)
	actions.add_child(fight_button)
	record_button = MenuButton.new()
	record_button.name = "RecordBattleButton"
	record_button.custom_minimum_size = Vector2(0.0, 48.0)
	record_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_button.add_theme_font_size_override("font_size", 17)
	record_button.tooltip_text = "选择帧率并录制当前完整对局"
	record_button.get_popup().id_pressed.connect(_on_recording_fps_selected)
	_update_recording_menu()
	actions.add_child(record_button)
	content.add_child(HSeparator.new())

	var seed_row := HBoxContainer.new()
	seed_row.name = "SeedControls"
	seed_row.custom_minimum_size = Vector2(0.0, 46.0)
	seed_row.add_theme_constant_override("separation", 8)
	content.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "种子"
	seed_label.custom_minimum_size = Vector2(42.0, 46.0)
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_size_override("font_size", 16)
	seed_label.add_theme_color_override("font_color", Color("aab5bb"))
	seed_row.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.text = str(seed_value)
	seed_edit.placeholder_text = "种子"
	seed_edit.custom_minimum_size = Vector2(0.0, 46.0)
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.add_theme_font_size_override("font_size", 17)
	seed_edit.text_submitted.connect(_on_seed_submitted)
	seed_row.add_child(seed_edit)
	var random_button := _make_button("随机", Vector2(78.0, 46.0))
	random_button.tooltip_text = "生成随机种子"
	random_button.pressed.connect(_restart_random_seed)
	seed_row.add_child(random_button)

	var controls := HBoxContainer.new()
	controls.name = "PlaybackControls"
	controls.custom_minimum_size = Vector2(0.0, 46.0)
	controls.add_theme_constant_override("separation", 8)
	content.add_child(controls)

	pause_button = _make_button("暂停", Vector2(0.0, 46.0))
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.pressed.connect(_toggle_pause)
	controls.add_child(pause_button)

	speed_button = _make_button("速度 1×", Vector2(0.0, 46.0))
	speed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_button.pressed.connect(_cycle_speed)
	controls.add_child(speed_button)

	var restart_button := _make_button("重开", Vector2(0.0, 46.0))
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(_restart_same_seed)
	controls.add_child(restart_button)

	var settings_row := HBoxContainer.new()
	settings_row.name = "SettingsActions"
	settings_row.custom_minimum_size = Vector2(0.0, 46.0)
	settings_row.add_theme_constant_override("separation", 8)
	content.add_child(settings_row)
	var global_settings_button := _make_button("玩法设置", Vector2(0.0, 46.0))
	global_settings_button.name = "ModeGlobalSettingsButton"
	global_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	global_settings_button.tooltip_text = "只编辑当前玩法的全局规则，其他玩法保持自己的配置"
	global_settings_button.pressed.connect(_open_global_settings)
	settings_row.add_child(global_settings_button)

	var settings_button := _make_button("球参数", Vector2(0.0, 46.0))
	settings_button.name = "BallSettingsButton"
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.pressed.connect(_open_ball_settings)
	settings_row.add_child(settings_button)

	var shortcuts := Label.new()
	shortcuts.text = "空格暂停 · R 重开 · N 随机 · 1/2/4 倍速"
	shortcuts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcuts.add_theme_font_size_override("font_size", 13)
	shortcuts.add_theme_color_override("font_color", Color("66737b"))
	content.add_child(shortcuts)
	_refresh_mode_controls()
	_update_battle_action_state()

func _open_roster_ball_picker(action: String, team_index: int = -1, roster_index: int = -1) -> void:
	_ball_picker_request = {
		"action": action,
		"team_index": team_index,
		"roster_index": roster_index,
	}
	_ensure_ball_picker_dialog()
	var selected_id := current_left_id
	var context_label := "新阵营首位"
	if team_index >= 0 and team_index < team_rosters.size():
		selected_id = String(team_rosters[team_index][maxi(roster_index, 0)]) if action == "replace" else String(team_rosters[team_index][0])
		context_label = "%s%s" % [_roster_team_label(team_index), "替换" if action == "replace" else "新增"]
	ball_picker_dialog.open_picker(selected_id, context_label)

func _ensure_ball_picker_dialog() -> void:
	if ball_picker_dialog == null:
		ball_picker_dialog = BallPickerDialogScript.new()
		ball_picker_dialog.ball_selected.connect(_on_ball_picker_selected)
		ball_picker_dialog.picker_cancelled.connect(_on_ball_picker_cancelled)
		add_child(ball_picker_dialog)

func _on_ball_picker_selected(ball_id: String) -> void:
	if not BallRegistry.has_id(ball_id):
		return
	var action := String(_ball_picker_request.get("action", ""))
	if action == "settings":
		if settings_dialog != null:
			settings_dialog.select_ball_and_reopen(ball_id)
		_ball_picker_request.clear()
		return
	var team_index := int(_ball_picker_request.get("team_index", -1))
	var roster_index := int(_ball_picker_request.get("roster_index", -1))
	match action:
		"replace":
			if _valid_roster_entry(team_index, roster_index):
				team_rosters[team_index][roster_index] = ball_id
		"add":
			if team_index >= 0 and team_index < team_rosters.size() \
					and team_rosters[team_index].size() < _current_roster_limit():
				team_rosters[team_index].append(ball_id)
		"add_team":
			if BattleSetupScript.allows_team_editing(battle_mode) \
					and team_rosters.size() < _current_team_limit():
				var new_team_index := team_rosters.size()
				team_rosters.append([ball_id])
				team_names.append(BattleSetupScript.default_team_name(battle_mode, new_team_index))
		_:
			return
	_ball_picker_request.clear()
	_commit_roster_edit()

func _on_ball_picker_cancelled() -> void:
	if String(_ball_picker_request.get("action", "")) == "settings" and settings_dialog != null:
		settings_dialog.reopen_settings()
	_ball_picker_request.clear()

func _on_roster_add_requested(team_index: int) -> void:
	_open_roster_ball_picker("add", team_index)

func _on_roster_replace_requested(team_index: int, roster_index: int) -> void:
	if _valid_roster_entry(team_index, roster_index):
		_open_roster_ball_picker("replace", team_index, roster_index)

func _on_roster_remove_requested(team_index: int, roster_index: int) -> void:
	if not _valid_roster_entry(team_index, roster_index) or team_rosters[team_index].size() <= 1:
		return
	team_rosters[team_index].remove_at(roster_index)
	_commit_roster_edit()

func _on_roster_move_requested(team_index: int, roster_index: int, direction: int) -> void:
	if not _valid_roster_entry(team_index, roster_index):
		return
	var target_index := roster_index + direction
	if target_index < 0 or target_index >= team_rosters[team_index].size():
		return
	var moving_ball = team_rosters[team_index][roster_index]
	team_rosters[team_index][roster_index] = team_rosters[team_index][target_index]
	team_rosters[team_index][target_index] = moving_ball
	_commit_roster_edit()

func _on_add_team_requested() -> void:
	if BattleSetupScript.allows_team_editing(battle_mode) \
			and team_rosters.size() < _current_team_limit():
		_open_roster_ball_picker("add_team")

func _on_remove_team_requested(team_index: int) -> void:
	var minimum_teams := 3
	if not BattleSetupScript.allows_team_editing(battle_mode) \
			or team_rosters.size() <= minimum_teams:
		return
	if team_index < 0 or team_index >= team_rosters.size():
		return
	team_rosters.remove_at(team_index)
	if team_index < team_names.size():
		team_names.remove_at(team_index)
	_commit_roster_edit()

func _valid_roster_entry(team_index: int, roster_index: int) -> bool:
	return team_index >= 0 and team_index < team_rosters.size() \
		and roster_index >= 0 and roster_index < team_rosters[team_index].size()

func _current_roster_limit() -> int:
	return BattleSetupScript.MAX_ACTIVE_PER_TEAM \
		if battle_mode == BattleSetupScript.MODE_TEAM_BRAWL \
		else BattleSetupScript.MAX_ROSTER_SIZE

func _current_team_limit() -> int:
	return BattleSetupScript.MAX_TEAMS

func _commit_roster_edit() -> void:
	_sync_primary_ball_ids()
	team_names = _normalize_team_names_for_mode(battle_mode, team_names, team_rosters.size())
	_store_current_mode_rosters()
	_store_current_mode_team_names()
	_refresh_mode_controls()
	result_label.text = "本局阵容已更新 · 点击开始对战生效"

func _roster_team_label(team_index: int) -> String:
	return _current_team_name(team_index)

func _on_team_name_changed(team_index: int, display_name: String) -> void:
	if battle_mode == BattleSetupScript.MODE_DUEL or team_index < 0 or team_index >= team_names.size():
		return
	team_names[team_index] = BattleSetupScript.sanitize_team_name(display_name, battle_mode, team_index)
	_store_current_mode_team_names()
	_refresh_mode_controls()
	result_label.text = "阵营名称已更新 · 点击开始对战生效"

func _start_selected_match() -> void:
	seed_value = _parse_seed(seed_edit.text, seed_value)
	_recording_quit_scheduled = false
	result_label.text = ""
	_replace_battle_view("selection_changed")
	pause_button.text = "暂停"

func _on_battle_mode_selected(index: int) -> void:
	_store_current_mode_rosters()
	_store_current_mode_team_names()
	_remove_active_battle("battle_mode_changed")
	battle_mode = String(mode_selector.get_item_metadata(index))
	_load_ball_settings_for_mode()
	_load_current_mode_rosters()
	_load_current_mode_team_names()
	_apply_global_settings(GlobalSettingsStoreScript.load_mode_settings(battle_mode))
	_refresh_mode_controls()
	_recording_quit_scheduled = false
	result_label.text = ""
	_show_battle_idle_state("battle_mode_changed")

func _refresh_mode_controls() -> void:
	if mode_roster_editor == null:
		return
	mode_roster_editor.configure(battle_mode, team_rosters, team_names)
	mode_profile_label.text = "%s玩法设置独立保存 · 本局阵容直接在下方编辑" % _battle_mode_display_name()
	if battle_mode == BattleSetupScript.MODE_BOSS:
		mode_profile_label.text = "BOSS 战：沿用多方混战规则 · 球参数与其他玩法完全隔离"
	_update_title()

func _make_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 17)
	return button

func _make_sidebar_section_label(label_text: String) -> Label:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("76dcff"))
	return label

func _on_recording_fps_selected(fps: int) -> void:
	recording_fps = clampi(fps, 24, 120)
	_runtime_global_settings["recording_fps"] = recording_fps
	var configuration = GlobalGameSettingsScript.new(_runtime_global_settings)
	_runtime_global_settings = configuration.settings_snapshot()
	recording_fps = configuration.settingi("recording_fps")
	GlobalSettingsStoreScript.save_mode_settings(battle_mode, _runtime_global_settings)
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
	if not _has_active_battle():
		result_label.text = "请先开始对战，再录制当前局"
		return
	var script_path := ProjectSettings.globalize_path("res://tools/render_video.sh")
	if not FileAccess.file_exists(script_path):
		result_label.text = "录制失败 · 找不到录制脚本"
		return
	var recording_seed: int = battle_view.simulation.seed_value
	var recording_left_id: String = battle_view.simulation.fighter_for_side(battle_view.simulation.teams[0].team_id).id
	var recording_right_id: String = battle_view.simulation.fighter_for_side(battle_view.simulation.teams[1].team_id).id
	var recording_time_limit := int(round(battle_view.simulation.max_battle_time))
	var recording_mode_id: String = battle_view.simulation.battle_setup.mode
	var recording_rosters := _encoded_team_rosters(battle_view.simulation.battle_setup.teams)
	var recording_team_names := _encoded_team_names(battle_view.simulation.battle_setup.teams)
	_recording_output_path = _video_output_path(recording_seed, recording_left_id, recording_right_id, recording_mode_id, recording_rosters)
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
		recording_mode_id,
		recording_rosters,
		recording_team_names,
	])
	_recording_process_id = OS.create_process(shell_path, arguments)
	if _recording_process_id <= 0:
		result_label.text = "录制失败 · 无法启动后台进程"
		return
	record_button.disabled = true
	record_button.text = "录制中…"
	result_label.text = "正在后台录制本局…"

func _video_output_path(video_seed: int, left_ball_id: String, right_ball_id: String, mode: String = BattleSetupScript.MODE_DUEL, rosters: String = "") -> String:
	var output_slug := "ability-ball-seed-%d" % video_seed
	if mode != BattleSetupScript.MODE_DUEL:
		var safe_rosters := rosters.replace("|", "-vs-").replace(",", "-").left(96)
		output_slug = "ability-ball-%s-%s-seed-%d" % [mode, safe_rosters, video_seed]
	elif left_ball_id != "vampire" or right_ball_id != "wdc":
		output_slug = "ability-ball-%s-vs-%s-seed-%d" % [left_ball_id, right_ball_id, video_seed]
	return ProjectSettings.globalize_path("res://builds/%s.mp4" % output_slug)

func _encoded_team_rosters(setup_teams: Array) -> String:
	var encoded: Array[String] = []
	for team_spec in setup_teams:
		encoded.append(",".join(team_spec["roster"]))
	return "|".join(encoded)

func _encoded_team_names(setup_teams: Array) -> String:
	var encoded: Array[String] = []
	for team_spec in setup_teams:
		encoded.append(String(team_spec.get("name", "")))
	return "|".join(encoded)

func _battle_view_position() -> Vector2:
	var view_height := _battle_view_size().y
	if recording_mode:
		var desired_y := RECORDING_BATTLE_CENTER_Y - view_height * 0.5
		var maximum_y := (
			RECORDING_LAYOUT_BOTTOM
			- RECORDING_TICKER_MIN_HEIGHT
			- RECORDING_SECTION_GAP
			- view_height
		)
		var recording_y := clampf(desired_y, RECORDING_LAYOUT_TOP, maximum_y) \
			if maximum_y >= RECORDING_LAYOUT_TOP else RECORDING_LAYOUT_TOP
		return Vector2(RECORDING_BATTLE_VIEW_X, recording_y)
	var interactive_desired_y := INTERACTIVE_BATTLE_CENTER_Y - view_height * 0.5
	var interactive_maximum_y := INTERACTIVE_BATTLE_BOTTOM - view_height
	var interactive_y := clampf(
		interactive_desired_y,
		INTERACTIVE_BATTLE_TOP,
		interactive_maximum_y
	) if interactive_maximum_y >= INTERACTIVE_BATTLE_TOP else interactive_desired_y
	return Vector2(INTERACTIVE_BATTLE_VIEW_X, interactive_y)

func _battle_view_size() -> Vector2:
	return BattleViewScript.view_size_for_arena(
		battle_arena_size,
		BattleViewScript.DEFAULT_VIEW_SIZE.x,
		battle_mode,
		_battle_hud_active_counts()
	)

func _battle_hud_active_counts() -> Array:
	var counts: Array[int] = []
	for roster in team_rosters:
		counts.append(roster.size() if battle_mode == BattleSetupScript.MODE_TEAM_BRAWL else 1)
	return counts

func _sync_battle_layout() -> void:
	var view_position := _battle_view_position()
	var view_size := _battle_view_size()
	if battle_idle_view != null:
		battle_idle_view.position = view_position
		battle_idle_view.size = view_size
	if battle_view != null:
		battle_view.position = view_position
		battle_view.size = view_size
	if recording_ability_ticker != null:
		var ticker_top := view_position.y + view_size.y + RECORDING_SECTION_GAP
		recording_ability_ticker.position = Vector2(RECORDING_BATTLE_VIEW_X, ticker_top)
		recording_ability_ticker.size = Vector2(
			view_size.x,
			maxf(0.0, RECORDING_LAYOUT_BOTTOM - ticker_top)
		)
	if result_label != null:
		result_label.position = Vector2(
			view_position.x,
			view_position.y + view_size.y + RESULT_VIEW_GAP
		)
		result_label.size.x = view_size.x

func _ball_settings_path() -> String:
	return BallSettingsStoreScript.settings_path_for_mode(battle_mode)

func _load_ball_settings_for_mode() -> void:
	_runtime_settings = BallSettingsStoreScript.load_settings(_ball_settings_path())
	BallRegistry.configure_settings(_runtime_settings)
	_runtime_settings = BallRegistry.settings_snapshot()

func _open_ball_settings() -> void:
	if settings_dialog == null:
		settings_dialog = BallSettingsDialogScript.new()
		settings_dialog.settings_submitted.connect(_on_ball_settings_submitted)
		settings_dialog.ball_picker_requested.connect(_on_ball_settings_picker_requested)
		add_child(settings_dialog)
	settings_dialog.open_settings(_runtime_settings, current_left_id)
	settings_dialog.title = "BOSS 战专用球参数" if battle_mode == BattleSetupScript.MODE_BOSS else "通用球参数（BOSS 战除外）"

func _on_ball_settings_picker_requested(current_ball_id: String) -> void:
	_ball_picker_request = {"action": "settings"}
	_ensure_ball_picker_dialog()
	ball_picker_dialog.open_picker(current_ball_id, "要配置的", "球")

func _on_ball_settings_submitted(settings: Dictionary) -> void:
	var restart_active_battle := _has_active_battle()
	BallRegistry.configure_settings(settings)
	_runtime_settings = BallRegistry.settings_snapshot()
	var save_error: Error = BallSettingsStoreScript.save_settings(_runtime_settings, _ball_settings_path())
	if save_error != OK:
		result_label.text = "参数已应用，但保存失败：%s" % error_string(save_error)
	else:
		result_label.text = "BOSS 战专用球参数已保存并应用" if battle_mode == BattleSetupScript.MODE_BOSS else "通用球参数已保存并应用"
	_refresh_mode_controls()
	if restart_active_battle:
		_replace_battle_view("ball_settings_changed")
	else:
		_show_battle_idle_state()

func _open_global_settings() -> void:
	if global_settings_dialog == null:
		global_settings_dialog = GlobalSettingsDialogScript.new()
		global_settings_dialog.settings_submitted.connect(_on_global_settings_submitted)
		add_child(global_settings_dialog)
	global_settings_dialog.open_settings(
		_runtime_global_settings,
		_battle_mode_display_name(),
		battle_mode
	)

func _on_global_settings_submitted(settings: Dictionary) -> void:
	var restart_active_battle := _has_active_battle()
	_apply_global_settings(settings)
	var save_error: Error = GlobalSettingsStoreScript.save_mode_settings(battle_mode, _runtime_global_settings)
	if save_error != OK:
		result_label.text = "%s设置已应用，但保存失败：%s" % [_battle_mode_display_name(), error_string(save_error)]
	else:
		result_label.text = "%s独立设置已保存并应用" % _battle_mode_display_name()
	if restart_active_battle:
		_replace_battle_view("global_settings_changed")
	else:
		_show_battle_idle_state()

func _apply_global_settings(settings: Dictionary) -> void:
	var configuration = GlobalGameSettingsScript.new(settings)
	_runtime_global_settings = configuration.settings_snapshot()
	time_limit_seconds = _time_limit_from_arguments(configuration.settingf("battle_time_seconds"))
	battle_arena_size = configuration.arena_size()
	recording_fps = configuration.settingi("recording_fps")
	result_reveal_delay_seconds = configuration.settingf("result_reveal_delay_seconds")
	relay_handoff_pause_seconds = configuration.settingf("relay_handoff_pause_seconds")
	relay_defeat_text_font_size = configuration.settingi("relay_defeat_text_font_size")
	damage_number_font_size = configuration.settingi("damage_number_font_size")
	damage_number_duration_seconds = configuration.settingf("damage_number_duration_seconds")
	_sync_battle_layout()
	_update_recording_menu()

func _on_battle_finished(simulation) -> void:
	_finish_battle_log("completed", simulation.finish_reason)
	if simulation.is_draw():
		result_label.text = "平局 · %s · 种子 %d" % [simulation.finish_reason, simulation.seed_value]
		if recording_mode and not _recording_quit_scheduled:
			_recording_quit_scheduled = true
			_quit_after_result()
		return
	var winner_name: String = simulation.winner().display_name \
		if simulation.battle_setup.mode == BattleSetupScript.MODE_DUEL \
		else simulation.team_for_id(simulation.winner_team_id).display_name
	result_label.text = "%s获胜 · %s · 种子 %d" % [winner_name, simulation.finish_reason, simulation.seed_value]
	if recording_mode and not _recording_quit_scheduled:
		_recording_quit_scheduled = true
		_quit_after_result()

func _on_battle_resolved(_simulation) -> void:
	procedural_audio.stop_all_looped_sample_events()

func _on_combat_event(kind: String, strength: float) -> void:
	procedural_audio.play_event(kind, strength)

func _quit_after_result() -> void:
	await _wait_for_result_presentation()
	procedural_audio.shutdown()
	await get_tree().process_frame
	get_tree().quit()

func _wait_for_result_presentation() -> void:
	# Containers need a layout pass before the report's full scroll distance is known.
	await get_tree().process_frame
	await get_tree().process_frame
	if battle_view != null and battle_view.result_panel != null:
		var panel = battle_view.result_panel
		while is_instance_valid(panel) and not panel.presentation_finished():
			await get_tree().process_frame
	else:
		await get_tree().create_timer(2.0).timeout

func _toggle_pause() -> void:
	if not _has_active_battle():
		return
	var should_pause: bool = not bool(battle_view.paused)
	battle_view.set_paused(should_pause)
	procedural_audio.set_looped_sample_events_paused(should_pause)
	pause_button.text = "继续" if battle_view.paused else "暂停"

func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % speed_values.size()
	_apply_speed(speed_values[speed_index])

func _apply_speed(speed: float) -> void:
	var found_index := speed_values.find(speed)
	if found_index >= 0:
		speed_index = found_index
	if _has_active_battle():
		battle_view.set_simulation_speed(speed)
	if speed_button != null:
		speed_button.text = "速度 %d×" % int(speed)

func _restart_same_seed() -> void:
	seed_value = _parse_seed(seed_edit.text, seed_value)
	if _has_active_battle():
		_start_seed(seed_value, "same_seed_restart")
	else:
		seed_edit.text = str(seed_value)
		result_label.text = "种子已更新 · 点击开始对战"

func _restart_random_seed() -> void:
	seed_value = int(Time.get_ticks_usec() % 2147483647)
	if _has_active_battle():
		_start_seed(seed_value, "random_seed_restart")
	else:
		seed_edit.text = str(seed_value)
		result_label.text = "随机种子已生成 · 点击开始对战"

func _on_seed_submitted(value: String) -> void:
	seed_value = _parse_seed(value, seed_value)
	if _has_active_battle():
		_start_seed(seed_value, "submitted_seed_restart")
	else:
		seed_edit.text = str(seed_value)
		result_label.text = "种子已更新 · 点击开始对战"

func _start_seed(value: int, end_reason: String) -> void:
	if not _has_active_battle():
		seed_value = value if value != 0 else 20260815
		seed_edit.text = str(seed_value)
		return
	_finish_battle_log("interrupted", end_reason)
	procedural_audio.stop_all_looped_sample_events()
	seed_value = value if value != 0 else 20260815
	_recording_quit_scheduled = false
	seed_edit.text = str(seed_value)
	result_label.text = ""
	battle_view.start_battle_setup(
		seed_value,
		_current_battle_setup(),
		time_limit_seconds,
		battle_arena_size,
		{}
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

func _battle_mode_from_arguments(fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--battle-mode="):
			var requested_mode := argument.trim_prefix("--battle-mode=")
			if requested_mode in BattleSetupScript.SUPPORTED_MODES:
				return requested_mode
			_fail_startup("未知对战模式：%s" % requested_mode)
	return fallback

func _team_rosters_from_arguments() -> Array:
	if battle_mode == BattleSetupScript.MODE_DUEL:
		return []
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--team-rosters="):
			continue
		var rosters: Array = []
		for raw_team in argument.trim_prefix("--team-rosters=").split("|", false):
			var roster: Array[String] = []
			for raw_ball_id in raw_team.split(",", false):
				var ball_id := raw_ball_id.strip_edges()
				if not ball_id.is_empty():
					roster.append(ball_id)
			rosters.append(roster)
		var setup = null
		match battle_mode:
			BattleSetupScript.MODE_RELAY:
				if rosters.size() == 2: setup = BattleSetupScript.relay(rosters[0], rosters[1])
			BattleSetupScript.MODE_FREE_FOR_ALL:
				setup = BattleSetupScript.free_for_all(rosters)
			BattleSetupScript.MODE_BOSS:
				setup = BattleSetupScript.boss(rosters)
			BattleSetupScript.MODE_TEAM_BRAWL:
				if rosters.size() == 2: setup = BattleSetupScript.team_brawl(rosters[0], rosters[1])
		if setup == null or not setup.is_valid():
			_fail_startup("命令行阵容无效：%s" % argument)
			return []
		return rosters
	return []

func _team_names_from_arguments() -> Array:
	if battle_mode == BattleSetupScript.MODE_DUEL:
		return []
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--team-names="):
			continue
		var names: Array[String] = []
		for raw_name in argument.trim_prefix("--team-names=").split("|", true):
			names.append(String(raw_name))
		return names
	return []

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
				simulation.fighter_for_side(simulation.teams[0].team_id).id,
				simulation.fighter_for_side(simulation.teams[1].team_id).id,
				simulation.battle_setup.mode,
				_encoded_team_rosters(simulation.battle_setup.teams)
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
