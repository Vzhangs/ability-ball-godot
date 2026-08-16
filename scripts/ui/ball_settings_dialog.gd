class_name BallSettingsDialog
extends AcceptDialog

signal settings_submitted(settings: Dictionary)

var _working_settings := {}
var _ball_selector: OptionButton
var _fields: VBoxContainer
var _field_controls := {}
var _current_ball_id := ""

func _ready() -> void:
	title = "球参数"
	ok_button_text = "保存并应用"
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)
	_build_content()

func open_settings(settings: Dictionary, preferred_ball_id: String = "") -> void:
	_working_settings = settings.duplicate(true)
	_ball_selector.clear()
	var selected_index := 0
	for module: BallModule in BallRegistry.modules():
		var index := _ball_selector.item_count
		_ball_selector.add_item(module.display_name)
		_ball_selector.set_item_metadata(index, module.id)
		if module.id == preferred_ball_id:
			selected_index = index
	_ball_selector.select(selected_index)
	_current_ball_id = String(_ball_selector.get_item_metadata(selected_index))
	_show_current_ball()
	popup_centered(Vector2i(620, 900))

func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(560.0, 760.0)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	_ball_selector = OptionButton.new()
	_ball_selector.custom_minimum_size = Vector2(0.0, 46.0)
	_ball_selector.add_theme_font_size_override("font_size", 18)
	_ball_selector.item_selected.connect(_on_ball_selected)
	content.add_child(_ball_selector)

	var hint := Label.new()
	hint.text = "保存后立即重开当前对局，并自动写入本机用户配置。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("8f9aa3"))
	content.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 650.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)

	_fields = VBoxContainer.new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.add_theme_constant_override("separation", 7)
	scroll.add_child(_fields)

	add_button("恢复此球默认", true, "reset_current")

func _on_ball_selected(index: int) -> void:
	_collect_current_ball()
	_current_ball_id = String(_ball_selector.get_item_metadata(index))
	_show_current_ball()

func _show_current_ball() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_field_controls.clear()
	var module: BallModule = BallRegistry.get_module(_current_ball_id)
	var values: Dictionary = _working_settings.get(_current_ball_id, module.settings_snapshot())
	var specs := module.setting_specs()
	var current_group := ""
	for key in module.ordered_setting_keys():
		var spec: Dictionary = specs[key]
		var group := String(spec["group"])
		if group != current_group:
			current_group = group
			var heading := Label.new()
			heading.text = current_group
			heading.add_theme_font_size_override("font_size", 19)
			heading.add_theme_color_override("font_color", module.accent)
			_fields.add_child(heading)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 44.0)
		var label := Label.new()
		label.text = String(spec["label"])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.tooltip_text = String(spec.get("tooltip", ""))
		row.add_child(label)
		var spin := SpinBox.new()
		spin.custom_minimum_size = Vector2(180.0, 42.0)
		spin.min_value = float(spec["min"])
		spin.max_value = float(spec["max"])
		spin.step = float(spec["step"])
		spin.value = float(values.get(key, spec["default"]))
		spin.rounded = String(spec["kind"]) == "int"
		spin.suffix = String(spec.get("suffix", ""))
		spin.tooltip_text = label.tooltip_text
		row.add_child(spin)
		_fields.add_child(row)
		_field_controls[key] = spin

func _collect_current_ball() -> void:
	if _current_ball_id.is_empty() or _field_controls.is_empty():
		return
	var module: BallModule = BallRegistry.get_module(_current_ball_id)
	var specs := module.setting_specs()
	var values := module.settings_snapshot()
	for key in _field_controls:
		var spin: SpinBox = _field_controls[key]
		values[key] = int(round(spin.value)) if String(specs[key]["kind"]) == "int" else spin.value
	_working_settings[_current_ball_id] = values

func _on_confirmed() -> void:
	_collect_current_ball()
	settings_submitted.emit(_working_settings.duplicate(true))

func _on_custom_action(action: StringName) -> void:
	if action != &"reset_current":
		return
	var module: BallModule = BallRegistry.get_module(_current_ball_id)
	_working_settings[_current_ball_id] = module.default_settings_snapshot()
	_show_current_ball()
