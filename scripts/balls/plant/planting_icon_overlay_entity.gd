extends BallEntity

const START_SCALE := 0.72
const PEAK_SCALE := 1.46

var _source
var _duration := 1.0
var _body_color := Color("39f05f")
var _accent_color := Color("d8ff67")

func _init(
	spawn_owner_side: int,
	source,
	duration: float,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	_source = source
	pos = source.pos
	radius = source.radius
	_duration = maxf(0.001, duration)
	remaining = _duration
	_body_color = body_color
	_accent_color = accent_color
	tags = PackedStringArray(["planting_icon_overlay_vfx"])
	draw_layer = 110

func step(_battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	pos = _source.pos

func animation_scale() -> float:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	return lerpf(START_SCALE, PEAK_SCALE, sin(progress * PI))

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _source == null:
		return
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var envelope := sin(progress * PI)
	var center := screen_position(context, _source.pos)
	var draw_radius := radius * context.scale_factor
	var icon_size := draw_radius * 0.74 * animation_scale()
	canvas.draw_circle(
		center,
		icon_size * 1.08,
		Color(_body_color.r, _body_color.g, _body_color.b, envelope * 0.16)
	)
	canvas.draw_circle(
		center,
		icon_size * 0.86,
		Color(0.015, 0.17, 0.075, envelope * 0.72)
	)
	_draw_sprout(canvas, center, icon_size, envelope)

func _draw_sprout(
	canvas: CanvasItem,
	center: Vector2,
	icon_size: float,
	alpha: float
) -> void:
	var stem_bottom := center + Vector2(0.0, icon_size * 0.58)
	var stem_top := center + Vector2(0.0, -icon_size * 0.34)
	canvas.draw_line(
		stem_bottom,
		stem_top,
		Color(0.01, 0.2, 0.08, alpha * 0.96),
		maxf(3.4, icon_size * 0.18),
		true
	)
	canvas.draw_line(
		stem_bottom + Vector2(-icon_size * 0.045, 0.0),
		stem_top + Vector2(-icon_size * 0.025, 0.0),
		Color(_accent_color.r, _accent_color.g, _accent_color.b, alpha),
		maxf(1.3, icon_size * 0.06),
		true
	)
	var left_leaf := PackedVector2Array([
		center + Vector2(-icon_size * 0.02, -icon_size * 0.12),
		center + Vector2(-icon_size * 0.82, -icon_size * 0.55),
		center + Vector2(-icon_size * 0.54, -icon_size * 0.94),
		center + Vector2(-icon_size * 0.12, -icon_size * 0.52),
	])
	var right_leaf := PackedVector2Array([
		center + Vector2(icon_size * 0.02, -icon_size * 0.18),
		center + Vector2(icon_size * 0.82, -icon_size * 0.66),
		center + Vector2(icon_size * 0.58, -icon_size * 1.0),
		center + Vector2(icon_size * 0.12, -icon_size * 0.55),
	])
	_draw_leaf(
		canvas,
		left_leaf,
		Color(_body_color.r, _body_color.g, _body_color.b, alpha * 0.98),
		Color(_accent_color.r, _accent_color.g, _accent_color.b, alpha),
		icon_size
	)
	_draw_leaf(
		canvas,
		right_leaf,
		Color(_accent_color.r, _accent_color.g, _accent_color.b, alpha * 0.98),
		Color(0.93, 1.0, 0.56, alpha),
		icon_size
	)
	canvas.draw_circle(
		stem_bottom,
		icon_size * 0.22,
		Color(0.67, 0.43, 0.16, alpha * 0.98)
	)
	canvas.draw_circle(
		stem_bottom + Vector2(-icon_size * 0.055, -icon_size * 0.055),
		icon_size * 0.085,
		Color(1.0, 0.88, 0.45, alpha * 0.94)
	)

func _draw_leaf(
	canvas: CanvasItem,
	points: PackedVector2Array,
	fill_color: Color,
	outline_color: Color,
	icon_size: float
) -> void:
	canvas.draw_colored_polygon(points, fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, outline_color, maxf(1.3, icon_size * 0.055), true)
