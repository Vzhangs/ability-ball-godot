class_name RecordingAbilityTicker
extends PanelContainer

const START_HOLD_SECONDS := 1.2
const STATIC_ENTRY_SECONDS := 6.5
const END_HOLD_SECONDS := 1.0
const SCROLL_SPEED := 17.0

var _entries: Array[Dictionary] = []
var _entry_signature := ""
var _entry_index := 0
var _entry_elapsed := 0.0
var _scroll_offset := 0.0
var _content_height := 0.0
var _accent_bar: ColorRect
var _title_label: Label
var _counter_label: Label
var _body_clip: Control
var _body_text: RichTextLabel

func _ready() -> void:
	name = "RecordingAbilityTicker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_content()
	set_process(true)

func set_entries(entries: Array) -> void:
	var sanitized: Array[Dictionary] = []
	var signature_parts := PackedStringArray()
	for raw_entry in entries:
		var ball_id := String(raw_entry.get("id", "")).strip_edges()
		var display_name := String(raw_entry.get("name", "")).strip_edges()
		var description := String(raw_entry.get("description", "")).strip_edges()
		if ball_id.is_empty() or display_name.is_empty() or description.is_empty():
			continue
		var accent = raw_entry.get("color", Color.WHITE)
		if not accent is Color:
			accent = Color.WHITE
		sanitized.append({
			"id": ball_id,
			"name": display_name,
			"description": description,
			"color": accent,
		})
		signature_parts.append("%s:%s" % [ball_id, description.sha256_text()])
	var signature := "|".join(signature_parts)
	if signature == _entry_signature:
		return
	_entries = sanitized
	_entry_signature = signature
	_entry_index = 0
	_show_current_entry()

func entry_count() -> int:
	return _entries.size()

func current_entry_id() -> String:
	return String(_entries[_entry_index].get("id", "")) if not _entries.is_empty() else ""

func current_title() -> String:
	return _title_label.text if _title_label != null else ""

func current_body_text() -> String:
	return _body_text.text if _body_text != null else ""

func scroll_offset() -> float:
	return _scroll_offset

func advance(delta: float) -> void:
	if _entries.is_empty() or _body_clip == null or _body_text == null:
		return
	_entry_elapsed += maxf(0.0, delta)
	var maximum_scroll := maxf(0.0, _content_height - _body_clip.size.y)
	if maximum_scroll <= 0.5:
		if _entry_elapsed >= START_HOLD_SECONDS + STATIC_ENTRY_SECONDS:
			_advance_entry()
		return
	var scrolling_elapsed := maxf(0.0, _entry_elapsed - START_HOLD_SECONDS)
	_scroll_offset = minf(maximum_scroll, scrolling_elapsed * SCROLL_SPEED)
	_apply_scroll_position()
	var finish_time := START_HOLD_SECONDS + maximum_scroll / SCROLL_SPEED + END_HOLD_SECONDS
	if _entry_elapsed >= finish_time:
		_advance_entry()

func _process(delta: float) -> void:
	advance(delta)

func _build_content() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("070a0c")
	panel_style.border_color = Color("26333a")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.64)
	panel_style.shadow_size = 9
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 22.0)
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)

	_accent_bar = ColorRect.new()
	_accent_bar.custom_minimum_size = Vector2(4.0, 20.0)
	_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_accent_bar)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	header.add_child(_title_label)

	_counter_label = Label.new()
	_counter_label.custom_minimum_size = Vector2(52.0, 0.0)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter_label.add_theme_font_size_override("font_size", 12)
	_counter_label.add_theme_color_override("font_color", Color("7f8d94"))
	header.add_child(_counter_label)

	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0.0, 1.0)
	separator.color = Color("243037")
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(separator)

	_body_clip = Control.new()
	_body_clip.name = "AbilityTickerBodyClip"
	_body_clip.custom_minimum_size = Vector2(0.0, 14.0)
	_body_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_clip.clip_contents = true
	_body_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_clip.resized.connect(_layout_body)
	content.add_child(_body_clip)

	_body_text = RichTextLabel.new()
	_body_text.name = "AbilityTickerBody"
	_body_text.bbcode_enabled = false
	_body_text.fit_content = true
	_body_text.scroll_active = false
	_body_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_text.add_theme_font_size_override("normal_font_size", 18)
	_body_text.add_theme_color_override("default_color", Color("d6e0e5"))
	_body_text.add_theme_constant_override("line_separation", 4)
	_body_clip.add_child(_body_text)

func _show_current_entry() -> void:
	_entry_elapsed = 0.0
	_scroll_offset = 0.0
	if _title_label == null or _body_text == null:
		return
	if _entries.is_empty():
		_title_label.text = ""
		_counter_label.text = ""
		_body_text.text = ""
		visible = false
		return
	visible = true
	var entry: Dictionary = _entries[_entry_index]
	var accent: Color = entry.get("color", Color.WHITE)
	_title_label.text = "能力介绍 · %s" % String(entry.get("name", ""))
	_title_label.add_theme_color_override("font_color", accent)
	_accent_bar.color = accent
	_counter_label.text = "%d / %d" % [_entry_index + 1, _entries.size()]
	_body_text.text = BallModule.sanitize_ability_text(String(entry.get("description", "")))
	_layout_body.call_deferred()

func _layout_body() -> void:
	if _body_clip == null or _body_text == null:
		return
	var body_width := maxf(1.0, _body_clip.size.x)
	_body_text.position = Vector2.ZERO
	_body_text.size = Vector2(body_width, maxf(1.0, _body_clip.size.y))
	_content_height = maxf(_body_clip.size.y, float(_body_text.get_content_height()) + 4.0)
	_body_text.size.y = _content_height
	_apply_scroll_position()

func _apply_scroll_position() -> void:
	if _body_text != null:
		_body_text.position.y = -_scroll_offset

func _advance_entry() -> void:
	if _entries.is_empty():
		return
	_entry_index = (_entry_index + 1) % _entries.size()
	_show_current_entry()
