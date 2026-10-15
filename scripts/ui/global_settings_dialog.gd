class_name GlobalSettingsDialog
extends AcceptDialog

const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")

signal settings_submitted(settings: Dictionary)

const DIALOG_SIZE := Vector2i(560, 650)

var _working_settings := {}
var _fields: VBoxContainer
var _field_controls := {}
var _hint_label: Label
var _scroll: ScrollContainer
var _mode_id := ""
var _popup_layout_revision := 0

func _ready() -> void:
	title = "全局设置"
	wrap_controls = false
	ok_button_text = "保存并应用"
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)
	_build_content()

func open_settings(
	settings: Dictionary,
	mode_display_name: String = "当前玩法",
	mode_id: String = ""
) -> void:
	var configuration = GlobalGameSettingsScript.new(settings)
	_working_settings = configuration.settings_snapshot()
	_mode_id = mode_id
	title = "%s · 独立全局设置" % mode_display_name
	_hint_label.text = _mode_hint(mode_display_name)
	_show_fields(configuration)
	_popup_current_layout()

func _popup_current_layout() -> void:
	_popup_layout_revision += 1
	var layout_revision := _popup_layout_revision
	popup_centered(DIALOG_SIZE)
	_settle_first_popup_layout(layout_revision)

func _settle_first_popup_layout(layout_revision: int) -> void:
	# A freshly realized native dialog can propagate the dynamic form's full
	# minimum height through ScrollContainer before it knows the popup viewport.
	# Reapplying the requested geometry after the first layout pass makes the
	# scroll view consume the fixed viewport instead of extending below it.
	await get_tree().process_frame
	if layout_revision != _popup_layout_revision or not visible:
		return
	popup_centered(DIALOG_SIZE)

func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(500.0, 360.0)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	_hint_label = Label.new()
	_hint_label.text = "只影响当前玩法。竞技场宽高就是白框内实际可碰撞、可对战的区域。"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_color_override("font_color", Color("8f9aa3"))
	content.add_child(_hint_label)

	_scroll = ScrollContainer.new()
	_scroll.name = "GlobalSettingsScroll"
	_scroll.custom_minimum_size = Vector2(0.0, 380.0)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(_scroll)

	_fields = VBoxContainer.new()
	_fields.name = "GlobalSettingsFields"
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.add_theme_constant_override("separation", 8)
	_scroll.add_child(_fields)

	add_button("恢复本玩法默认", true, "reset_defaults")

func _show_fields(configuration) -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_field_controls.clear()
	var specs: Dictionary = configuration.setting_specs()
	var current_group := ""
	for key in configuration.ordered_setting_keys():
		var spec: Dictionary = specs[key]
		var group := String(spec["group"])
		if group != current_group:
			current_group = group
			var heading := Label.new()
			heading.text = current_group
			heading.add_theme_font_size_override("font_size", 19)
			heading.add_theme_color_override("font_color", Color("76dcff"))
			_fields.add_child(heading)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 46.0)
		var label := Label.new()
		label.text = String(spec["label"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.tooltip_text = String(spec.get("tooltip", ""))
		row.add_child(label)
		var spin := SpinBox.new()
		spin.name = "GlobalSetting_%s" % String(key)
		spin.custom_minimum_size = Vector2(190.0, 42.0)
		spin.min_value = float(spec["min"])
		spin.max_value = float(spec["max"])
		spin.step = float(spec["step"])
		spin.value = float(_working_settings.get(key, spec["default"]))
		spin.rounded = String(spec["kind"]) == "int"
		spin.suffix = String(spec.get("suffix", ""))
		spin.tooltip_text = label.tooltip_text
		row.add_child(spin)
		_fields.add_child(row)
		_field_controls[key] = spin
	_scroll.scroll_vertical = 0

func _mode_hint(mode_display_name: String) -> String:
	return "只影响%s，不会改动其他玩法。竞技场宽高是白框内实际可碰撞、可对战的区域。" % mode_display_name

func _collect_fields() -> Dictionary:
	var values := _working_settings.duplicate(true)
	var configuration = GlobalGameSettingsScript.new(values)
	var specs: Dictionary = configuration.setting_specs()
	for key in _field_controls:
		var spin: SpinBox = _field_controls[key]
		if String(specs[key]["kind"]) == "int":
			values[key] = int(round(spin.value))
		else:
			values[key] = spin.value
	return GlobalGameSettingsScript.new(values).settings_snapshot()

func _on_confirmed() -> void:
	_working_settings = _collect_fields()
	settings_submitted.emit(_working_settings.duplicate(true))

func _on_custom_action(action: StringName) -> void:
	if action != &"reset_defaults":
		return
	var configuration = GlobalGameSettingsScript.new()
	_working_settings = configuration.default_settings_snapshot()
	_show_fields(GlobalGameSettingsScript.new(_working_settings))
