extends PanelContainer

const METRICS := ["damage_dealt", "damage_taken", "healing"]
const SCROLL_SPEED := 34.0
const LEAD_HOLD := 3.0
const TAIL_HOLD := 3.0

var report: Dictionary = {}
var automatic_scroll := true
var scroll: ScrollContainer
var rows_box: VBoxContainer
var _number_labels: Array[Control] = []
var _age := 0.0
var _requested_bounds := Rect2()
var _bounds_sync_queued := false
var _bottom_hold := 0.0
var _scroll_position := 0.0

func configure(data: Dictionary, headline: String, subtitle: String, accent: Color, auto_scroll: bool = true) -> void:
	report = data.duplicate(true)
	automatic_scroll = auto_scroll
	_age = 0.0
	_bottom_hold = 0.0
	_scroll_position = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	minimum_size_changed.connect(_queue_bounds_sync)
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("0a1118")
	surface.border_color = accent.darkened(0.35)
	surface.set_border_width_all(2)
	surface.set_corner_radius_all(12)
	surface.content_margin_left = 16
	surface.content_margin_right = 16
	surface.content_margin_top = 16
	surface.content_margin_bottom = 14
	add_theme_stylebox_override("panel", surface)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(layout)
	var title := _label(headline, 28, accent)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(title)
	layout.add_child(_label(subtitle, 16, Color("a6b5c3")))
	layout.add_child(_label("逐球战报 · 合计包含本体与附属物", 16, Color("e2eaf0")))
	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 6)
	var name_heading := _label("参战球 / 单位", 15, Color("a6b5c3"))
	name_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headings.add_child(name_heading)
	for heading in ["造成伤害", "承受伤害", "回复量"]:
		var heading_label := _label(heading, 15, Color("a6b5c3"))
		heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_number_labels.append(heading_label)
		headings.add_child(heading_label)
	var heading_margin := MarginContainer.new()
	heading_margin.add_theme_constant_override("margin_left", 9)
	layout.add_child(heading_margin)
	heading_margin.add_child(headings)
	scroll = ScrollContainer.new()
	scroll.name = "ReportScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.custom_minimum_size = Vector2.ZERO
	layout.add_child(scroll)
	heading_margin.add_theme_constant_override("margin_right", 8 + int(scroll.get_v_scroll_bar().get_combined_minimum_size().x))
	rows_box = VBoxContainer.new()
	rows_box.name = "ReportRows"
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 8)
	scroll.add_child(rows_box)
	var last_team := -999
	for participant: Dictionary in report.get("fighters", []):
		var team_id := int(participant["team_id"])
		var team_color := Color(String(participant["team_color"]))
		if team_color.a <= 0.01:
			team_color = accent
		if team_id != last_team:
			rows_box.add_child(_label(String(participant["team_name"]), 20, team_color))
			last_team = team_id
		_add_fighter(participant, team_color)
	var note := _label("仅统计实际扣血与回血；回复量为自身恢复。受控单位按当时归属记账。", 13, Color("8799a8"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(note)
	var hint := _label("战报自动滚动" if automatic_scroll else "滚轮查看完整记录", 13, Color("7797a8"))
	layout.add_child(hint)
	resized.connect(_resize_columns)
	_resize_columns()
	_queue_bounds_sync()

func set_report_bounds(bounds: Rect2) -> void:
	_requested_bounds = bounds
	position = bounds.position
	size = bounds.size

func _queue_bounds_sync() -> void:
	if _bounds_sync_queued:
		return
	_bounds_sync_queued = true
	_restore_bounds.call_deferred()

func _restore_bounds() -> void:
	_bounds_sync_queued = false
	if _requested_bounds.has_area():
		# Wrapped labels settle after container sorting, including while play is paused.
		# Their initial narrow-width minimum must not permanently enlarge the panel.
		position = _requested_bounds.position
		size = _requested_bounds.size

func _add_fighter(participant: Dictionary, team_color: Color) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111d27")
	style.border_color = team_color
	style.border_width_left = 3
	style.content_margin_left = 9
	style.content_margin_right = 8
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.set_corner_radius_all(5)
	card.add_theme_stylebox_override("panel", style)
	rows_box.add_child(card)
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 8)
	card.add_child(group)
	var label_text := "%d. %s · %s" % [int(participant["roster_index"]) + 1, participant["name"], participant["state"]]
	group.add_child(_metric_row(label_text, participant["totals"], team_color, 18))
	for row: Dictionary in participant["rows"]:
		var row_name := String(row["category_name"])
		var detail := ""
		if bool(row.get("controlled", false)):
			row_name = "受控 · " + row_name
			detail = "原属 " + String(row["origin_name"])
		var recovery_given := float(row.get("healing_done", 0.0))
		if recovery_given > 0.0:
			detail += ("\n" if not detail.is_empty() else "") + "治疗贡献 " + _number(recovery_given)
		var self_loss := float(row.get("self_damage", 0.0)) + float(row.get("unattributed_damage", 0.0))
		if self_loss > 0.0:
			detail += ("\n" if not detail.is_empty() else "") + "承伤中含自损 / 无来源损血 " + _number(self_loss)
		group.add_child(_metric_row(row_name, row, Color("d5e0e8"), 16, detail))

func _metric_row(caption: String, values: Dictionary, color: Color, font_size: int, detail: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	var caption_label := _label(caption, font_size, color)
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(caption_label)
	if not detail.is_empty():
		var detail_label := _label(detail, 13, Color("93a6b7"))
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names.add_child(detail_label)
	for metric: String in METRICS:
		var number_label := _label(_number(float(values.get(metric, 0.0))), font_size, color)
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		number_label.tooltip_text = str(values.get(metric, 0.0))
		_number_labels.append(number_label)
		row.add_child(number_label)
	return row

func _resize_columns() -> void:
	var column_width := clampf((size.x - 70.0) * 0.145, 62.0, 90.0)
	for number_label in _number_labels:
		number_label.custom_minimum_size.x = column_width

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _number(value: float) -> String:
	return "%.1f" % value if not is_equal_approx(value, roundf(value)) else "%.0f" % value

func scroll_distance() -> float:
	if scroll == null:
		return 0.0
	var bar := scroll.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)

func presentation_duration() -> float:
	return LEAD_HOLD + scroll_distance() / SCROLL_SPEED + TAIL_HOLD

func presentation_finished() -> bool:
	return _bottom_hold >= TAIL_HOLD

func _process(delta: float) -> void:
	if not automatic_scroll or not visible or scroll == null:
		return
	_age += delta
	if _age < LEAD_HOLD or presentation_finished():
		return
	_scroll_position = minf(scroll_distance(), maxf(0.0, _age - LEAD_HOLD) * SCROLL_SPEED)
	scroll.scroll_vertical = int(ceilf(_scroll_position))
	if float(scroll.scroll_vertical) >= scroll_distance() - 1.0:
		_bottom_hold += delta
	else:
		_bottom_hold = 0.0
