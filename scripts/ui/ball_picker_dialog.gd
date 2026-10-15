class_name AbilityBallPickerDialog
extends Control

signal ball_selected(ball_id: String)
signal picker_cancelled

const CardScript := preload("res://scripts/ui/ball_picker_card.gd")
const PANEL_SIZE := Vector2(660.0, 940.0)
const GRID_COLUMNS := 4

var _selected_ball_id := ""
var _title_label: Label
var _search_edit: LineEdit
var _count_label: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty_label: Label
var _detail_name: Label
var _detail_ability: Label
var _cards: Dictionary = {}
var _visible_card_count := 0

func _ready() -> void:
	name = "BallPickerDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 1000
	_build_content()
	hide()

func open_picker(current_ball_id: String, side_label: String, purpose_label: String = "参战球") -> void:
	_selected_ball_id = current_ball_id
	_title_label.text = "选择%s%s" % [side_label, purpose_label]
	_search_edit.text = ""
	_rebuild_cards("")
	_show_detail(_selected_ball_id)
	show()
	move_to_front()
	_search_edit.grab_focus.call_deferred()

func selected_ball_id() -> String:
	return _selected_ball_id

func card_count() -> int:
	return _cards.size()

func visible_card_count() -> int:
	return _visible_card_count

func card_for_id(ball_id: String):
	return _cards.get(ball_id)

func current_description() -> String:
	return _detail_ability.text if _detail_ability != null else ""

func _build_content() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "BallPickerDimmer"
	dimmer.color = Color(0.0, 0.0, 0.0, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(_on_dimmer_input)
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.name = "BallPickerPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("080d11")
	panel_style.border_color = Color("354650")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	panel_style.shadow_size = 14
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 48.0)
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)

	_title_label = Label.new()
	_title_label.name = "BallPickerTitle"
	_title_label.text = "选择参战球"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("f0f6f9"))
	header.add_child(_title_label)

	var close_button := Button.new()
	close_button.name = "BallPickerCloseButton"
	close_button.text = "×"
	close_button.tooltip_text = "关闭选球"
	close_button.custom_minimum_size = Vector2(46.0, 46.0)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_font_size_override("font_size", 25)
	close_button.pressed.connect(_cancel_picker)
	header.add_child(close_button)

	var search_row := HBoxContainer.new()
	search_row.custom_minimum_size = Vector2(0.0, 48.0)
	search_row.add_theme_constant_override("separation", 10)
	content.add_child(search_row)

	_search_edit = LineEdit.new()
	_search_edit.name = "BallSearchInput"
	_search_edit.placeholder_text = "搜索球名、ID 或能力"
	_search_edit.clear_button_enabled = true
	_search_edit.custom_minimum_size = Vector2(0.0, 46.0)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", 17)
	_search_edit.text_changed.connect(_on_search_changed)
	search_row.add_child(_search_edit)

	_count_label = Label.new()
	_count_label.name = "BallPickerCount"
	_count_label.custom_minimum_size = Vector2(95.0, 46.0)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 15)
	_count_label.add_theme_color_override("font_color", Color("91a0aa"))
	search_row.add_child(_count_label)

	var hint := Label.new()
	hint.text = "悬浮查看能力，点击卡片完成选择；右下角可复制简介。"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("7f8d96"))
	content.add_child(hint)

	# The grid may grow to any height, but it stays inside this fixed viewport.
	var scroll_viewport := Control.new()
	scroll_viewport.name = "BallCardViewport"
	scroll_viewport.custom_minimum_size = Vector2(0.0, 457.0)
	scroll_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_viewport.clip_contents = true
	content.add_child(scroll_viewport)

	_scroll = ScrollContainer.new()
	_scroll.name = "BallCardScroll"
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_viewport.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.name = "BallCardGrid"
	_grid.columns = GRID_COLUMNS
	_grid.custom_minimum_size = Vector2(606.0, 0.0)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)

	_empty_label = Label.new()
	_empty_label.name = "BallPickerEmptyState"
	_empty_label.text = "没有匹配的球\n换个球名、ID 或能力关键词试试。"
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 17)
	_empty_label.add_theme_color_override("font_color", Color("a7b2b9"))
	_empty_label.visible = false
	scroll_viewport.add_child(_empty_label)

	var detail_panel := PanelContainer.new()
	detail_panel.name = "BallAbilityPreview"
	detail_panel.custom_minimum_size = Vector2(0.0, 212.0)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color("0b1217")
	detail_style.border_color = Color("26343d")
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(10)
	detail_style.content_margin_left = 14.0
	detail_style.content_margin_right = 14.0
	detail_style.content_margin_top = 10.0
	detail_style.content_margin_bottom = 10.0
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	content.add_child(detail_panel)

	var detail_content := VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 4)
	detail_panel.add_child(detail_content)
	_detail_name = Label.new()
	_detail_name.name = "BallAbilityName"
	_detail_name.add_theme_font_size_override("font_size", 20)
	detail_content.add_child(_detail_name)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "BallAbilityDescriptionScroll"
	detail_scroll.custom_minimum_size = Vector2(0.0, 154.0)
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_content.add_child(detail_scroll)
	_detail_ability = Label.new()
	_detail_ability.name = "BallAbilityDescription"
	_detail_ability.custom_minimum_size = Vector2(570.0, 0.0)
	_detail_ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_ability.add_theme_font_size_override("font_size", 16)
	_detail_ability.add_theme_constant_override("line_spacing", 4)
	_detail_ability.add_theme_color_override("font_color", Color("d0dbe1"))
	detail_scroll.add_child(_detail_ability)

func _on_search_changed(query: String) -> void:
	_rebuild_cards(query)

func _rebuild_cards(query: String) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	_visible_card_count = 0
	var normalized_query := query.strip_edges().to_lower()
	var name_matches := _name_query_matches(normalized_query)
	for module: BallModule in BallRegistry.modules():
		if not name_matches.is_empty() and not name_matches.has(module.id):
			continue
		if name_matches.is_empty() and not _matches_query(module, normalized_query):
			continue
		var card: Control = CardScript.new()
		card.configure(module, module.id == _selected_ball_id)
		card.selected.connect(_on_card_selected)
		card.preview_requested.connect(_show_detail)
		_grid.add_child(card)
		_cards[module.id] = card
		_visible_card_count += 1
	_count_label.text = "%d / %d 个" % [_visible_card_count, BallRegistry.ids().size()]
	_empty_label.visible = _visible_card_count == 0
	_scroll.visible = _visible_card_count > 0

func _name_query_matches(query: String) -> Array[String]:
	var matches: Array[String] = []
	if query.is_empty():
		return matches
	for module: BallModule in BallRegistry.modules():
		if module.id.to_lower().contains(query) or module.display_name.to_lower().contains(query):
			matches.append(module.id)
	return matches

func _matches_query(module: BallModule, query: String) -> bool:
	if query.is_empty():
		return true
	var searchable := "%s %s %s" % [
		module.display_name,
		module.id,
		module.ability_description,
	]
	return searchable.to_lower().contains(query)

func _show_detail(ball_id: String) -> void:
	if not BallRegistry.has_id(ball_id):
		return
	var module: BallModule = BallRegistry.get_module(ball_id)
	_detail_name.text = "%s  ·  %s" % [module.display_name, module.id]
	_detail_name.add_theme_color_override("font_color", module.title_color)
	_detail_ability.text = module.formatted_ability_description()

func _on_card_selected(ball_id: String) -> void:
	_selected_ball_id = ball_id
	ball_selected.emit(ball_id)
	hide()

func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_cancel_picker()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_picker()
		get_viewport().set_input_as_handled()

func _cancel_picker() -> void:
	hide()
	picker_cancelled.emit()
