class_name BattleSetupDialog
extends AcceptDialog

signal setup_submitted(mode: String, team_rosters: Array)

const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")

var _mode := BattleSetupScript.MODE_RELAY
var _team_rosters: Array = []
var _team_count_spin: SpinBox
var _roster_container: VBoxContainer
var _roster_edits: Array[LineEdit] = []
var _error_label: Label

func _ready() -> void:
	title = "对战模式阵容"
	size = Vector2i(650, 610)
	min_size = Vector2i(620, 560)
	confirmed.connect(_submit)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var help := Label.new()
	help.text = "每行是一支队伍；用英文逗号按出场顺序填写球 ID。擂台依次接替，大混战则同时上场。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(590.0, 52.0)
	help.add_theme_font_size_override("font_size", 16)
	root.add_child(help)

	var count_row := HBoxContainer.new()
	root.add_child(count_row)
	var count_label := Label.new()
	count_label.text = "混战阵营数"
	count_label.custom_minimum_size = Vector2(120.0, 40.0)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_row.add_child(count_label)
	_team_count_spin = SpinBox.new()
	_team_count_spin.min_value = 3.0
	_team_count_spin.max_value = BattleSetupScript.MAX_TEAMS
	_team_count_spin.step = 1.0
	_team_count_spin.value = 3.0
	_team_count_spin.custom_minimum_size = Vector2(120.0, 40.0)
	_team_count_spin.value_changed.connect(_on_team_count_changed)
	count_row.add_child(_team_count_spin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(590.0, 270.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_roster_container = VBoxContainer.new()
	_roster_container.custom_minimum_size = Vector2(570.0, 0.0)
	_roster_container.add_theme_constant_override("separation", 9)
	scroll.add_child(_roster_container)

	var available := Label.new()
	available.text = "可用 ID：" + "、".join(BallRegistry.ids())
	available.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	available.custom_minimum_size = Vector2(590.0, 70.0)
	available.add_theme_font_size_override("font_size", 14)
	available.add_theme_color_override("font_color", Color("93a0aa"))
	root.add_child(available)

	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_font_size_override("font_size", 15)
	_error_label.add_theme_color_override("font_color", Color("ff8178"))
	root.add_child(_error_label)
	get_ok_button().text = "应用阵容"

func open_config(requested_mode: String, current_rosters: Array) -> void:
	_mode = requested_mode
	_team_rosters = current_rosters.duplicate(true)
	var requested_count := 3 if _mode == BattleSetupScript.MODE_FREE_FOR_ALL else 2
	if _mode == BattleSetupScript.MODE_FREE_FOR_ALL:
		requested_count = clampi(_team_rosters.size(), 3, BattleSetupScript.MAX_TEAMS)
	_team_count_spin.value = requested_count
	_team_count_spin.visible = _mode == BattleSetupScript.MODE_FREE_FOR_ALL
	_error_label.text = ""
	_rebuild_roster_edits(requested_count)
	popup_centered(size)

func _on_team_count_changed(value: float) -> void:
	if _mode == BattleSetupScript.MODE_FREE_FOR_ALL:
		_rebuild_roster_edits(int(value))

func _rebuild_roster_edits(team_count: int) -> void:
	var preserved: Array[String] = []
	for edit in _roster_edits:
		preserved.append(edit.text)
	for child in _roster_container.get_children():
		child.queue_free()
	_roster_edits.clear()
	for team_index in range(team_count):
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "队伍 %d" % (team_index + 1)
		label.custom_minimum_size = Vector2(72.0, 42.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(480.0, 42.0)
		edit.placeholder_text = "例如：vampire,wind_swordsman,plant"
		if team_index < preserved.size():
			edit.text = preserved[team_index]
		elif team_index < _team_rosters.size():
			edit.text = ",".join(_team_rosters[team_index])
		else:
			edit.text = BallRegistry.ids()[team_index % BallRegistry.ids().size()]
		row.add_child(edit)
		_roster_container.add_child(row)
		_roster_edits.append(edit)

func _submit() -> void:
	var rosters: Array = []
	for edit in _roster_edits:
		var roster: Array[String] = []
		for raw_id in edit.text.split(",", false):
			var ball_id := raw_id.strip_edges()
			if not ball_id.is_empty():
				roster.append(ball_id)
		rosters.append(roster)
	var setup = _setup_for(_mode, rosters)
	if setup == null or not setup.is_valid():
		_error_label.text = "阵容无效：" + (", ".join(setup.validation_errors()) if setup != null else "未知模式")
		popup_centered.call_deferred(size)
		return
	_team_rosters = rosters.duplicate(true)
	setup_submitted.emit(_mode, _team_rosters)

func _setup_for(setup_mode: String, rosters: Array):
	match setup_mode:
		BattleSetupScript.MODE_RELAY:
			return BattleSetupScript.relay(rosters[0], rosters[1])
		BattleSetupScript.MODE_FREE_FOR_ALL:
			return BattleSetupScript.free_for_all(rosters)
		BattleSetupScript.MODE_TEAM_BRAWL:
			return BattleSetupScript.team_brawl(rosters[0], rosters[1])
	return null
