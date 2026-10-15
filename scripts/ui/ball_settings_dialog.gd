class_name BallSettingsDialog
extends AcceptDialog

signal settings_submitted(settings: Dictionary)
signal ball_picker_requested(current_ball_id: String)

const DIALOG_SIZE := Vector2i(620, 900)

var _working_settings := {}
var _ball_picker_button: Button
var _scroll: ScrollContainer
var _fields: VBoxContainer
var _field_controls := {}
var _current_ball_id := ""
var _popup_layout_revision := 0

func _ready() -> void:
	title = "球参数"
	# The form is rebuilt from each ball's schema. Keep the dialog at the
	# requested viewport size so a long first schema scrolls instead of making
	# the native popup taller than the game window.
	wrap_controls = false
	ok_button_text = "保存并应用"
	confirmed.connect(_on_confirmed)
	custom_action.connect(_on_custom_action)
	_build_content()

func open_settings(_settings: Dictionary, preferred_ball_id: String = "") -> void:
	# The registry has already applied and normalized the persisted settings.
	# Start from that safe snapshot so legacy audience copy cannot reappear here.
	_working_settings = BallRegistry.settings_snapshot()
	var modules := BallRegistry.modules()
	if modules.is_empty():
		return
	_current_ball_id = preferred_ball_id if BallRegistry.has_id(preferred_ball_id) else modules[0].id
	_show_current_ball()
	_popup_current_layout()

func select_ball_and_reopen(ball_id: String) -> void:
	_collect_current_ball()
	if BallRegistry.has_id(ball_id):
		_current_ball_id = ball_id
		_show_current_ball()
	_popup_current_layout()

func reopen_settings() -> void:
	_popup_current_layout()

func current_ball_id() -> String:
	return _current_ball_id

func working_settings_snapshot() -> Dictionary:
	_collect_current_ball()
	return _working_settings.duplicate(true)

func _popup_current_layout() -> void:
	_popup_layout_revision += 1
	var layout_revision := _popup_layout_revision
	popup_centered(DIALOG_SIZE)
	_settle_first_popup_layout(layout_revision)

func _settle_first_popup_layout(layout_revision: int) -> void:
	# A newly realized AcceptDialog performs its first child layout against the
	# pre-popup content rect. A dynamic long form can therefore make the internal
	# margin taller than the actual window while the outer window is already the
	# requested size. Reapplying the same popup geometry on the next frame gives
	# the ScrollContainer the real viewport height; later opens are guarded from
	# stale settlement calls by the revision token.
	await get_tree().process_frame
	if layout_revision != _popup_layout_revision or not visible:
		return
	popup_centered(DIALOG_SIZE)

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

	_ball_picker_button = Button.new()
	_ball_picker_button.name = "BallSettingsPickerButton"
	_ball_picker_button.custom_minimum_size = Vector2(0.0, 54.0)
	_ball_picker_button.add_theme_font_size_override("font_size", 18)
	_ball_picker_button.tooltip_text = "打开卡片式球库，选择要编辑参数的球"
	_ball_picker_button.pressed.connect(_on_ball_picker_pressed)
	content.add_child(_ball_picker_button)

	var hint := Label.new()
	hint.text = "保存后立即重开当前对局，并自动写入本机用户配置。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("8f9aa3"))
	content.add_child(hint)

	_scroll = ScrollContainer.new()
	_scroll.name = "BallSettingsScroll"
	_scroll.custom_minimum_size = Vector2(0.0, 650.0)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(_scroll)

	_fields = VBoxContainer.new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.add_theme_constant_override("separation", 7)
	_scroll.add_child(_fields)

	add_button("恢复此球默认", true, "reset_current")

func _on_ball_picker_pressed() -> void:
	_collect_current_ball()
	hide()
	ball_picker_requested.emit(_current_ball_id)

func _show_current_ball() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_field_controls.clear()
	var module: BallModule = BallRegistry.get_module(_current_ball_id)
	_ball_picker_button.text = "选择配置球　%s  ·  %s" % [module.display_name, module.id]
	_ball_picker_button.add_theme_color_override("font_color", module.title_color)
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
		if String(spec["kind"]) == "text":
			var text_block := VBoxContainer.new()
			text_block.add_theme_constant_override("separation", 6)
			var text_label := Label.new()
			text_label.text = String(spec["label"])
			text_label.tooltip_text = String(spec.get("tooltip", ""))
			text_block.add_child(text_label)
			var text_edit := TextEdit.new()
			text_edit.name = "BallDescriptionEditor"
			text_edit.custom_minimum_size = Vector2(0.0, 180.0)
			text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			text_edit.text = String(values.get(key, spec["default"]))
			text_edit.placeholder_text = "只说明能力规则、有效目标、结果和限制；不要写数值、配置、特效或音效。"
			text_edit.tooltip_text = text_label.tooltip_text
			text_edit.add_theme_font_size_override("font_size", 16)
			text_block.add_child(text_edit)
			_fields.add_child(text_block)
			_field_controls[key] = text_edit
		else:
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
	_scroll.scroll_vertical = 0

func _collect_current_ball() -> void:
	if _current_ball_id.is_empty() or _field_controls.is_empty():
		return
	var module: BallModule = BallRegistry.get_module(_current_ball_id)
	var specs := module.setting_specs()
	var values := module.settings_snapshot()
	for key in _field_controls:
		var kind := String(specs[key]["kind"])
		if kind == "text":
			values[key] = (_field_controls[key] as TextEdit).text
		else:
			var spin := _field_controls[key] as SpinBox
			if kind == "int":
				values[key] = int(round(spin.value))
			else:
				values[key] = spin.value
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
