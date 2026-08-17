extends BallEntity

const LENS_SEGMENTS := 18

var _reach := 100.0
var _half_width := 20.0
var _color := Color("8ff5ff")
var _direction := Vector2.RIGHT
var _duration := 0.6

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_direction: Vector2,
	visual_reach: float,
	visual_half_width: float,
	visual_duration: float,
	color: Color
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_direction = spawn_direction.normalized()
	_reach = visual_reach
	_half_width = visual_half_width
	_duration = maxf(0.001, visual_duration)
	_color = color
	remaining = _duration
	tags = PackedStringArray(["wind_slash_vfx"])
	draw_layer = 30

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := 1.0 - remaining / _duration
	var alpha := pow(1.0 - progress, 1.18)
	var center := screen_position(context)
	var scale_factor := context.scale_factor
	var reveal := 1.0 - pow(1.0 - clampf(progress * 3.2, 0.0, 1.0), 3.0)
	var full_start := center
	var full_finish := center + _direction * _reach * scale_factor
	var visible_finish := full_start.lerp(full_finish, maxf(0.08, reveal))
	var blade_center := (full_start + visible_finish) * 0.5
	var half_length := full_start.distance_to(visible_finish) * 0.5
	var half_width := maxf(3.5, _half_width * scale_factor)
	var bloom := sin(clampf(progress * 2.2, 0.0, 1.0) * PI)

	# Every layer keeps the same tapered fruit-core silhouette. Width and opacity alone
	# create the bloom, avoiding a rectangular light-column appearance.
	_draw_lens(
		canvas,
		blade_center,
		half_length * 1.04,
		half_width * (1.22 + bloom * 0.18),
		Color(_color.r, _color.g, _color.b, alpha * 0.16)
	)
	_draw_lens(
		canvas,
		blade_center,
		half_length,
		half_width * 0.68,
		Color(_color.r, _color.g, _color.b, alpha * 0.72)
	)
	_draw_lens(
		canvas,
		blade_center,
		half_length * 0.985,
		half_width * 0.31,
		Color(0.72, 0.98, 1.0, alpha * 0.92)
	)
	_draw_lens(
		canvas,
		blade_center,
		half_length * 0.94,
		maxf(1.0, half_width * 0.105),
		Color(1.0, 1.0, 1.0, alpha),
		_direction
	)
	canvas.draw_circle(blade_center, half_width * 1.34, Color(_color.r, _color.g, _color.b, alpha * 0.08))
	canvas.draw_circle(blade_center, maxf(1.0, half_width * 0.24), Color(1.0, 1.0, 1.0, alpha * 0.72))

func _draw_lens(
	canvas: CanvasItem,
	center: Vector2,
	half_length: float,
	half_width: float,
	color: Color,
	direction: Vector2 = _direction
) -> void:
	if half_length <= 0.01 or half_width <= 0.01 or color.a <= 0.001:
		return
	var points := PackedVector2Array()
	var tangent := Vector2(-direction.y, direction.x)
	for index in range(LENS_SEGMENTS + 1):
		var progress := float(index) / float(LENS_SEGMENTS)
		var envelope := pow(maxf(0.0, sin(progress * PI)), 0.72)
		points.append(
			center
			+ direction * lerpf(-half_length, half_length, progress)
			- tangent * half_width * envelope
		)
	for index in range(LENS_SEGMENTS, -1, -1):
		var progress := float(index) / float(LENS_SEGMENTS)
		var envelope := pow(maxf(0.0, sin(progress * PI)), 0.72)
		points.append(
			center
			+ direction * lerpf(-half_length, half_length, progress)
			+ tangent * half_width * envelope
		)
	canvas.draw_colored_polygon(points, color)
