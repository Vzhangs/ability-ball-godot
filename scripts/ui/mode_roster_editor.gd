class_name ModeRosterEditor
extends PanelContainer

signal add_ball_requested(team_index: int)
signal replace_ball_requested(team_index: int, roster_index: int)
signal remove_ball_requested(team_index: int, roster_index: int)
signal move_ball_requested(team_index: int, roster_index: int, direction: int)
signal add_team_requested()
signal remove_team_requested(team_index: int)
signal team_name_changed(team_index: int, display_name: String)

const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")

var _mode := BattleSetupScript.MODE_DUEL
var _rosters: Array = []
var _team_names: Array[String] = []
var _heading: Label
var _team_action_button: Button
var _roster_list: VBoxContainer

func _ready() -> void:
	name = "ModeRosterEditor"
	custom_minimum_size = Vector2(0.0, 122.0)
	_build_shell()
	_rebuild()

func configure(requested_mode: String, requested_rosters: Array, requested_team_names: Array = []) -> void:
	_mode = requested_mode
	_rosters = requested_rosters.duplicate(true)
	_team_names.clear()
	for team_index in range(_rosters.size()):
		var raw_name := String(requested_team_names[team_index]) \
			if team_index < requested_team_names.size() else ""
		_team_names.append(BattleSetupScript.sanitize_team_name(raw_name, _mode, team_index))
	if is_node_ready():
		_rebuild()

func roster_snapshot() -> Array:
	return _rosters.duplicate(true)

func team_names_snapshot() -> Array[String]:
	return _team_names.duplicate()

func _build_shell() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("070c0f")
	panel_style.border_color = Color("2b3941")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 7.0
	panel_style.content_margin_bottom = 7.0
	add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 27.0)
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	_heading = Label.new()
	_heading.name = "ModeRosterHeading"
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.clip_text = true
	_heading.add_theme_font_size_override("font_size", 15)
	_heading.add_theme_color_override("font_color", Color("cbd6dc"))
	header.add_child(_heading)
	_team_action_button = _make_button("＋ 阵营", "ModeAddTeamButton", 78.0)
	_team_action_button.tooltip_text = "从球库选择一个球并新增为独立阵营"
	_team_action_button.pressed.connect(_emit_add_team)
	header.add_child(_team_action_button)

	var scroll := ScrollContainer.new()
	scroll.name = "ModeRosterScroll"
	scroll.custom_minimum_size = Vector2(0.0, 74.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(scroll)
	_roster_list = VBoxContainer.new()
	_roster_list.name = "ModeRosterList"
	_roster_list.custom_minimum_size = Vector2.ZERO
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_roster_list)

func _rebuild() -> void:
	if _roster_list == null:
		return
	for child in _roster_list.get_children():
		_roster_list.remove_child(child)
		child.queue_free()
	_heading.text = _mode_heading()
	_heading.tooltip_text = _heading.text
	_team_action_button.visible = BattleSetupScript.allows_team_editing(_mode)
	_team_action_button.disabled = _rosters.size() >= _team_limit()
	for team_index in range(_rosters.size()):
		_roster_list.add_child(_build_team_section(team_index, _rosters[team_index]))

func _build_team_section(team_index: int, roster: Array) -> Control:
	var section := PanelContainer.new()
	section.name = "RosterTeam_%d" % team_index
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var section_style := StyleBoxFlat.new()
	section_style.bg_color = Color("0b1216")
	section_style.border_color = Color("26343c")
	section_style.set_border_width_all(1)
	section_style.set_corner_radius_all(8)
	section_style.content_margin_left = 6.0
	section_style.content_margin_right = 6.0
	section_style.content_margin_top = 5.0
	section_style.content_margin_bottom = 6.0
	section.add_theme_stylebox_override("panel", section_style)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	section.add_child(content)

	var header := HBoxContainer.new()
	header.name = "RosterTeamHeader_%d" % team_index
	header.custom_minimum_size = Vector2(0.0, 36.0)
	header.add_theme_constant_override("separation", 5)
	content.add_child(header)

	var team_color := BattleSetupScript.competitive_team_color(team_index)
	if _mode == BattleSetupScript.MODE_DUEL:
		var team_label := Label.new()
		team_label.text = _team_label(team_index)
		team_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team_label.custom_minimum_size = Vector2(0.0, 36.0)
		team_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		team_label.add_theme_font_size_override("font_size", 14)
		team_label.add_theme_color_override("font_color", team_color)
		header.add_child(team_label)
	else:
		var name_edit := LineEdit.new()
		name_edit.name = "RosterTeamName_%d" % team_index
		name_edit.text = _team_label(team_index)
		name_edit.placeholder_text = BattleSetupScript.default_team_name(_mode, team_index)
		name_edit.max_length = BattleSetupScript.MAX_TEAM_NAME_LENGTH
		name_edit.clear_button_enabled = true
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.custom_minimum_size = Vector2(84.0, 36.0)
		name_edit.tooltip_text = "自定义阵营名；留空后恢复默认名称“%s”" % name_edit.placeholder_text
		name_edit.add_theme_font_size_override("font_size", 14)
		name_edit.add_theme_color_override("font_color", team_color)
		name_edit.add_theme_color_override("font_placeholder_color", Color(team_color.r, team_color.g, team_color.b, 0.48))
		name_edit.text_submitted.connect(_on_team_name_submitted.bind(name_edit, team_index))
		name_edit.focus_exited.connect(_commit_team_name_edit.bind(name_edit, team_index))
		header.add_child(name_edit)

	if _mode != BattleSetupScript.MODE_DUEL:
		var add_button := _make_button("＋ 添加球", "RosterAdd_%d" % team_index, 82.0)
		add_button.tooltip_text = "从球库给%s增加一个球" % _team_label(team_index)
		add_button.disabled = roster.size() >= _roster_limit()
		add_button.pressed.connect(_emit_add_ball.bind(team_index))
		header.add_child(add_button)
	var minimum_team_count := 3
	if BattleSetupScript.allows_team_editing(_mode) \
			and _rosters.size() > minimum_team_count:
		var remove_team_button := _make_button("×", "RosterRemoveTeam_%d" % team_index, 34.0)
		remove_team_button.tooltip_text = "删除整个%s" % _team_label(team_index)
		remove_team_button.pressed.connect(_emit_remove_team.bind(team_index))
		header.add_child(remove_team_button)

	var balls := VBoxContainer.new()
	balls.name = "RosterBalls_%d" % team_index
	balls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balls.add_theme_constant_override("separation", 4)
	content.add_child(balls)
	for roster_index in range(roster.size()):
		balls.add_child(_build_ball_chip(team_index, roster_index, String(roster[roster_index]), roster.size()))
	return section

func _build_ball_chip(team_index: int, roster_index: int, ball_id: String, roster_size: int) -> Control:
	var module: BallModule = BallRegistry.get_module(ball_id)
	var chip := PanelContainer.new()
	chip.name = "RosterChip_%d_%d" % [team_index, roster_index]
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size = Vector2(0.0, 40.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10181d")
	style.border_color = Color(module.accent.r, module.accent.g, module.accent.b, 0.74)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	chip.add_theme_stylebox_override("panel", style)
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 1)
	chip.add_child(actions)

	if _mode != BattleSetupScript.MODE_DUEL:
		var move_up := _make_button("↑", "RosterMoveUp_%d_%d" % [team_index, roster_index], 30.0)
		move_up.tooltip_text = "向上调整出场顺序"
		move_up.disabled = roster_index == 0
		move_up.pressed.connect(_emit_move_ball.bind(team_index, roster_index, -1))
		actions.add_child(move_up)

	var ball_button := _make_button(
		"%d · %s" % [roster_index + 1, module.display_name],
		"RosterBall_%d_%d" % [team_index, roster_index],
		0.0
	)
	ball_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ball_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ball_button.tooltip_text = "%s\n%s\n点击后从球库替换" % [
		module.display_name,
		module.formatted_ability_description(),
	]
	ball_button.add_theme_color_override("font_color", module.title_color)
	ball_button.pressed.connect(_emit_replace_ball.bind(team_index, roster_index))
	actions.add_child(ball_button)

	if _mode != BattleSetupScript.MODE_DUEL:
		var move_down := _make_button("↓", "RosterMoveDown_%d_%d" % [team_index, roster_index], 30.0)
		move_down.tooltip_text = "向下调整出场顺序"
		move_down.disabled = roster_index >= roster_size - 1
		move_down.pressed.connect(_emit_move_ball.bind(team_index, roster_index, 1))
		actions.add_child(move_down)
		var remove_button := _make_button("×", "RosterRemove_%d_%d" % [team_index, roster_index], 32.0)
		remove_button.tooltip_text = "从阵容移除%s" % module.display_name
		remove_button.disabled = roster_size <= 1
		remove_button.pressed.connect(_emit_remove_ball.bind(team_index, roster_index))
		actions.add_child(remove_button)
	return chip

func _mode_heading() -> String:
	match _mode:
		BattleSetupScript.MODE_RELAY:
			return "本局出场顺序 · 从上到下依次接力，点击球名可替换"
		BattleSetupScript.MODE_FREE_FOR_ALL, BattleSetupScript.MODE_BOSS:
			return "本局多方阵容 · 可加球、加阵营，顺序决定接替次序"
		BattleSetupScript.MODE_TEAM_BRAWL:
			return "本局双方阵容 · 全员同时上场，可加球、删除和排序"
	return "本局对阵 · 点击左右球名打开卡片球库"

func _team_label(team_index: int) -> String:
	if _mode != BattleSetupScript.MODE_DUEL and team_index >= 0 and team_index < _team_names.size():
		return _team_names[team_index]
	return BattleSetupScript.default_team_name(_mode, team_index)

func _roster_limit() -> int:
	return BattleSetupScript.MAX_ACTIVE_PER_TEAM \
		if _mode == BattleSetupScript.MODE_TEAM_BRAWL \
		else BattleSetupScript.MAX_ROSTER_SIZE

func _team_limit() -> int:
	return BattleSetupScript.MAX_TEAMS

func _make_button(button_text: String, node_name: String, width: float) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = button_text
	button.custom_minimum_size = Vector2(width, 36.0)
	button.add_theme_font_size_override("font_size", 14)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button

func _emit_add_ball(team_index: int) -> void:
	add_ball_requested.emit(team_index)

func _emit_replace_ball(team_index: int, roster_index: int) -> void:
	replace_ball_requested.emit(team_index, roster_index)

func _emit_remove_ball(team_index: int, roster_index: int) -> void:
	remove_ball_requested.emit(team_index, roster_index)

func _emit_move_ball(team_index: int, roster_index: int, direction: int) -> void:
	move_ball_requested.emit(team_index, roster_index, direction)

func _emit_add_team() -> void:
	add_team_requested.emit()

func _emit_remove_team(team_index: int) -> void:
	remove_team_requested.emit(team_index)

func _on_team_name_submitted(_submitted_text: String, name_edit: LineEdit, team_index: int) -> void:
	_commit_team_name_edit(name_edit, team_index)
	if is_instance_valid(name_edit) and name_edit.is_inside_tree():
		name_edit.release_focus()

func _commit_team_name_edit(name_edit: LineEdit, team_index: int) -> void:
	if _mode == BattleSetupScript.MODE_DUEL or team_index < 0 or team_index >= _team_names.size():
		return
	var normalized := BattleSetupScript.sanitize_team_name(name_edit.text, _mode, team_index)
	name_edit.text = normalized
	if normalized == _team_names[team_index]:
		return
	_team_names[team_index] = normalized
	team_name_changed.emit(team_index, normalized)
