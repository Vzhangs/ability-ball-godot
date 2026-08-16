extends BallEntity

var _source
var _target
var _duration := 0.0
var _field_radius := 0.0
var _vortex_radius := 0.0
var _color := Color("bc63ff")
var _target_trail: Array[Vector2] = []
var _trail_timer := 0.0

func _init(
	spawn_owner_side: int,
	source,
	target,
	duration: float,
	field_radius: float,
	vortex_radius: float,
	color: Color
) -> void:
	owner_side = spawn_owner_side
	_source = source
	_target = target
	remaining = duration
	_duration = duration
	_field_radius = field_radius
	_vortex_radius = vortex_radius
	_color = color
	pos = source.pos
	tags = PackedStringArray(["vortex_field"])
	draw_layer = -30

func step(_battle, delta: float) -> void:
	pos = _source.pos
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.045
		_target_trail.push_front(_target.pos)
		if _target_trail.size() > 16:
			_target_trail.pop_back()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var progress := 1.0 - remaining / _duration
	var alpha := minf(1.0, minf(progress * 7.0, (1.0 - progress) * 5.0))
	var position := screen_position(context)
	var vortex_radius := _vortex_radius * scale_factor
	var field_radius := _field_radius * scale_factor
	canvas.draw_circle(position, field_radius, Color(_color.r, _color.g, _color.b, alpha * 0.075))
	for spiral in range(3):
		var spiral_radius := vortex_radius * (1.0 - spiral * 0.24) - progress * 10.0 * scale_factor
		var spiral_start := progress * TAU * 2.4 + spiral * 1.7
		canvas.draw_arc(position, spiral_radius, spiral_start, spiral_start + PI * (1.18 + spiral * 0.12), 44, Color(0.78, 0.42, 1.0, alpha * (0.72 - spiral * 0.12)), 2.4 + spiral * 0.5, true)
	for ring in range(4):
		var ring_radius := (38.0 + ring * 24.0 + progress * 20.0) * scale_factor
		canvas.draw_arc(position, ring_radius, progress * TAU + ring, progress * TAU + ring + PI * 1.52, 48, Color(0.7, 0.27, 1.0, alpha * (0.34 - ring * 0.045)), 3.0, true)
	var target_position := screen_position(context, _target.pos)
	var offset := target_position - position
	if offset.length_squared() <= 1.0:
		return
	var orbit_radius := offset.length()
	var orbit_rotation := offset.angle()
	for segment in range(12):
		var start_angle := orbit_rotation + float(segment) * TAU / 12.0 + progress * 0.2
		canvas.draw_arc(
			position,
			orbit_radius,
			start_angle,
			start_angle + 0.27,
			8,
			Color(_color.r, _color.g, _color.b, alpha * (0.16 + (segment % 3) * 0.035)),
			1.5,
			true
		)
	if _target_trail.size() > 1:
		var trail_points := PackedVector2Array()
		for trail_position in _target_trail:
			trail_points.append(screen_position(context, trail_position))
		canvas.draw_polyline(trail_points, Color(_color.r, _color.g, _color.b, alpha * 0.42), 3.0, true)
	var outward := offset.normalized()
	var tangent := Vector2(-outward.y, outward.x) * (1.0 if owner_side == 0 else -1.0)
	var arrow_center := target_position + tangent * 12.0
	var arrow := PackedVector2Array([
		arrow_center + tangent * 13.0,
		arrow_center - tangent * 7.0 + outward * 6.0,
		arrow_center - tangent * 7.0 - outward * 6.0,
	])
	canvas.draw_colored_polygon(arrow, Color(0.9, 0.72, 1.0, alpha * 0.9))
