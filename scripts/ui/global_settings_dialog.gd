class_name GlobalSettingsDialog
extends AcceptDialog

const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")

signal settings_submitted(settings: Dictionary)

var _working_settings := {}
var _fields: VBoxContainer
var _field_controls := {}

func _ready() -> void:
	title = "全局设置"
	ok_button_text = "保存并应用"
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)
	_build_content()

func open_settings(settings: Dictionary) -> void:
	var configuration = GlobalGameSettingsScript.new(settings)
	_working_settings = configuration.settings_snapshot()
	_show_fields(configuration)
	popup_centered(Vector2i(560, 500))

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
	margin.add_child(content)

	var hint := Label.new()
	hint.text = "影响所有球和所有组合。竞技场宽高就是白框内实际可碰撞、可对战的区域。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("8f9aa3"))
	content.add_child(hint)

	_fields = VBoxContainer.new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.add_theme_constant_override("separation", 8)
	content.add_child(_fields)

	add_button("恢复全局默认", true, "reset_defaults")

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

func _collect_fields() -> Dictionary:
	var values := _working_settings.duplicate(true)
	var configuration = GlobalGameSettingsScript.new(values)
	var specs: Dictionary = configuration.setting_specs()
	for key in _field_controls:
		var spin: SpinBox = _field_controls[key]
		values[key] = int(round(spin.value)) if String(specs[key]["kind"]) == "int" else spin.value
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
