class_name AbilityBallPickerCard
extends Control

signal selected(ball_id: String)
signal preview_requested(ball_id: String)
signal description_copied(ball_id: String, description: String)

const CARD_SIZE := Vector2(142.0, 166.0)
const MODEL_CENTER := Vector2(71.0, 62.0)
const MODEL_RADIUS := 32.0
const COPY_BUTTON_SIZE := Vector2(34.0, 34.0)
const COPY_FEEDBACK_SECONDS := 1.35
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")
const Glow := preload("res://scripts/balls/core/combat_glow.gd")

class PreviewFighter extends RefCounted:
	var color := Color.WHITE
	var accent := Color.WHITE
	var pos := Vector2.ZERO
	var velocity := Vector2.RIGHT * 180.0
	var rotation := 0.0

class CopyDescriptionButton extends Button:
	var copied := false

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func show_copied(value: bool) -> void:
		copied = value
		queue_redraw()

	func _draw() -> void:
		var icon_color := Color("83f0b6") if copied else Color("d5e4eb")
		if copied:
			draw_polyline(PackedVector2Array([
				Vector2(8.5, 17.5),
				Vector2(14.0, 23.0),
				Vector2(25.5, 10.5),
			]), icon_color, 2.6, true)
			return
		draw_rect(Rect2(7.5, 6.5, 14.0, 17.0), icon_color, false, 1.8, true)
		draw_rect(Rect2(12.5, 11.5, 14.0, 17.0), icon_color, false, 1.8, true)

var module: BallModule
var _visual: BallVisual
var _fighter := PreviewFighter.new()
var _selected := false
var _hovered := false
var _hover_progress := 0.0
var _elapsed := 0.0
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _shadow_style: StyleBoxFlat
var _copy_button: CopyDescriptionButton
var _copy_feedback_generation := 0
var _copy_feedback_visible := false

func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	_build_copy_button()

func configure(owner_module: BallModule, selected_ball: bool) -> void:
	module = owner_module
	_selected = selected_ball
	_fighter.color = module.color
	_fighter.accent = module.accent
	_fighter.velocity = Vector2.RIGHT * module.speed
	_visual = module.create_visual()
	tooltip_text = module.formatted_ability_description()
	_copy_button.tooltip_text = "复制%s的完整简介" % module.display_name
	_copy_button.show_copied(false)
	_copy_feedback_visible = false
	name = "BallCard_%s" % module.id
	_build_styles()
	pivot_offset = CARD_SIZE * 0.5
	queue_redraw()

func ball_id() -> String:
	return module.id if module != null else ""

func preview_visual() -> BallVisual:
	return _visual

func is_selected_card() -> bool:
	return _selected

func copy_button() -> Button:
	return _copy_button

func description_for_copy() -> String:
	return module.formatted_ability_description() if module != null else ""

func activate() -> void:
	if module != null:
		selected.emit(module.id)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	_fighter.rotation = _elapsed * 0.72
	var target := 1.0 if _hovered or has_focus() else 0.0
	_hover_progress = move_toward(_hover_progress, target, delta * 7.5)
	var lift := sin(_hover_progress * PI * 0.5)
	scale = Vector2.ONE * (1.0 + lift * 0.035)
	queue_redraw()

func _draw() -> void:
	if module == null or _visual == null:
		return
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	draw_style_box(_shadow_style, Rect2(Vector2(0.0, 5.0), CARD_SIZE))
	var style := _selected_style if _selected else (_hover_style if _hover_progress > 0.02 else _normal_style)
	draw_style_box(style, rect)
	var glow_alpha := 0.08 + _hover_progress * 0.14 + (0.12 if _selected else 0.0)
	Glow.halo(self, MODEL_CENTER, MODEL_RADIUS * 1.8, Color(module.accent, glow_alpha * 1.4))
	var preview_context := {
		"position": MODEL_CENTER,
		"radius": MODEL_RADIUS,
		"elapsed": _elapsed,
		"scale_factor": 1.0,
		"shake_offset": Vector2.ZERO,
	}
	_visual.draw_ball(self, _fighter, preview_context)
	_draw_name()
	if _selected:
		_draw_selected_marker()
	elif _hover_progress > 0.05:
		_draw_hover_marker()

func _draw_name() -> void:
	var font_size := 18
	var name_width := CARD_SIZE.x - 18.0
	var baseline := Vector2(9.0, 122.0)
	draw_string(
		CjkFontProviderScript.font(),
		baseline + Vector2(1.0, 1.0),
		module.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		name_width,
		font_size,
		Color(0.0, 0.0, 0.0, 0.92)
	)
	draw_string(
		CjkFontProviderScript.font(),
		baseline,
		module.display_name,
		HORIZONTAL_ALIGNMENT_CENTER,
		name_width,
		font_size,
		Color("f2f7fa")
	)
	draw_string(
		CjkFontProviderScript.font(),
		Vector2(8.0, 156.0),
		"已复制简介" if _copy_feedback_visible else "点击卡片选择",
		HORIZONTAL_ALIGNMENT_CENTER,
		94.0,
		12,
		Color("83f0b6") if _copy_feedback_visible else Color(0.61, 0.68, 0.72, 0.86)
	)

func _draw_selected_marker() -> void:
	var center := Vector2(CARD_SIZE.x - 17.0, 17.0)
	draw_circle(center, 10.5, Color(0.025, 0.055, 0.07, 0.96))
	draw_circle(center, 9.0, module.accent)
	draw_polyline(PackedVector2Array([
		center + Vector2(-4.2, 0.2),
		center + Vector2(-1.0, 3.5),
		center + Vector2(4.8, -3.3),
	]), Color("061014"), 2.2, true)

func _draw_hover_marker() -> void:
	var line_y := CARD_SIZE.y - 4.0
	draw_line(
		Vector2(18.0, line_y),
		Vector2(CARD_SIZE.x - 18.0, line_y),
		Color(module.accent.r, module.accent.g, module.accent.b, 0.78 * _hover_progress),
		2.0,
		true
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			accept_event()
			activate()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			accept_event()
			activate()

func _on_mouse_entered() -> void:
	_hovered = true
	preview_requested.emit(ball_id())

func _on_mouse_exited() -> void:
	_hovered = false

func _on_focus_entered() -> void:
	preview_requested.emit(ball_id())

func _on_focus_exited() -> void:
	queue_redraw()

func _on_copy_description_pressed() -> void:
	if module == null:
		return
	var description := description_for_copy()
	DisplayServer.clipboard_set(description)
	description_copied.emit(module.id, description)
	_copy_feedback_generation += 1
	var feedback_generation := _copy_feedback_generation
	_copy_feedback_visible = true
	_copy_button.show_copied(true)
	_copy_button.tooltip_text = "已复制%s的完整简介" % module.display_name
	queue_redraw()
	get_tree().create_timer(COPY_FEEDBACK_SECONDS).timeout.connect(func() -> void:
		if feedback_generation != _copy_feedback_generation or not is_instance_valid(_copy_button):
			return
		_copy_feedback_visible = false
		_copy_button.show_copied(false)
		_copy_button.tooltip_text = "复制%s的完整简介" % module.display_name
		queue_redraw()
	)

func _make_custom_tooltip(_for_text: String) -> Object:
	if module == null:
		return null
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440.0, 0.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("10181e")
	panel_style.border_color = module.accent
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 11.0
	panel_style.content_margin_bottom = 11.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var title_label := Label.new()
	title_label.text = module.display_name
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", module.title_color)
	content.add_child(title_label)
	var ability_label := Label.new()
	ability_label.text = module.formatted_ability_description()
	ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_label.add_theme_font_size_override("font_size", 16)
	ability_label.add_theme_constant_override("line_spacing", 4)
	ability_label.add_theme_color_override("font_color", Color("d5e0e6"))
	content.add_child(ability_label)
	return panel

func _build_styles() -> void:
	_shadow_style = _make_style(Color(0.0, 0.0, 0.0, 0.42), Color(0.0, 0.0, 0.0, 0.0), 0)
	_normal_style = _make_style(Color("0b1115"), Color("29333a"), 1)
	_hover_style = _make_style(Color("111d24"), Color(module.accent.r, module.accent.g, module.accent.b, 0.86), 2)
	_selected_style = _make_style(Color("102029"), module.accent, 3)

func _build_copy_button() -> void:
	_copy_button = CopyDescriptionButton.new()
	_copy_button.name = "CopyDescriptionButton"
	_copy_button.custom_minimum_size = COPY_BUTTON_SIZE
	_copy_button.anchor_left = 1.0
	_copy_button.anchor_top = 1.0
	_copy_button.anchor_right = 1.0
	_copy_button.anchor_bottom = 1.0
	_copy_button.offset_left = -40.0
	_copy_button.offset_top = -40.0
	_copy_button.offset_right = -6.0
	_copy_button.offset_bottom = -6.0
	_copy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_copy_button.pressed.connect(_on_copy_description_pressed)
	_copy_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.03, 0.06, 0.08, 0.72), Color("40505a"), 1))
	_copy_button.add_theme_stylebox_override("hover", _make_button_style(Color("18303b"), Color("9edff2"), 1))
	_copy_button.add_theme_stylebox_override("pressed", _make_button_style(Color("1b3d38"), Color("83f0b6"), 2))
	_copy_button.add_theme_stylebox_override("focus", _make_button_style(Color(0.0, 0.0, 0.0, 0.0), Color("f4fbff"), 2))
	add_child(_copy_button)

func _make_button_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	return style

func _make_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	return style
