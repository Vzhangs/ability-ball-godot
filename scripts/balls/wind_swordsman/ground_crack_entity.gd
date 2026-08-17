extends BallEntity

var _duration := 1.0
var _extent := 54.0
var _color := Color("8ff5ff")
var _direction := Vector2.RIGHT

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_direction: Vector2,
	slash_reach: float,
	duration: float,
	color: Color
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_direction = spawn_direction.normalized()
	_duration = duration
	remaining = duration
	_extent = slash_reach * 0.5
	_color = color
	tags = PackedStringArray(["wind_ground_crack"])
	draw_layer = -24

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := 1.0 - remaining / _duration
	var reveal := 1.0 - pow(1.0 - clampf(progress / 0.09, 0.0, 1.0), 3.0)
	var fade := clampf(remaining / minf(_duration, 0.85), 0.0, 1.0)
	var alpha := reveal * fade
	var center := screen_position(context)
	var crack_scale := _extent / 64.0 * context.scale_factor
	var left_edge := PackedVector2Array([
		Vector2(-2.0, -64.0), Vector2(-9.0, -47.0), Vector2(-5.0, -30.0),
		Vector2(-15.0, -11.0), Vector2(-7.0, 9.0), Vector2(-17.0, 28.0),
		Vector2(-9.0, 48.0), Vector2(-5.0, 64.0),
	])
	var right_edge := PackedVector2Array([
		Vector2(3.0, -64.0), Vector2(11.0, -46.0), Vector2(7.0, -28.0),
		Vector2(17.0, -9.0), Vector2(9.0, 11.0), Vector2(20.0, 30.0),
		Vector2(11.0, 49.0), Vector2(7.0, 64.0),
	])
	var screen_left := _screen_points(left_edge, center, crack_scale)
	var screen_right := _screen_points(right_edge, center, crack_scale)
	var trench := PackedVector2Array()
	trench.append_array(screen_left)
	for index in range(screen_right.size() - 1, -1, -1):
		trench.append(screen_right[index])

	# A filled, uneven center channel reads as a real gap in the arena floor.
	canvas.draw_colored_polygon(trench, Color(0.0, 0.012, 0.018, alpha * 0.98))
	canvas.draw_polyline(screen_left, Color(_color.r, _color.g, _color.b, alpha * 0.18), maxf(3.0, 7.0 * context.scale_factor), true)
	canvas.draw_polyline(screen_right, Color(_color.r, _color.g, _color.b, alpha * 0.18), maxf(3.0, 7.0 * context.scale_factor), true)
	canvas.draw_polyline(screen_left, Color(_color.r, _color.g, _color.b, alpha * 0.62), maxf(1.0, 1.5 * context.scale_factor), true)
	canvas.draw_polyline(screen_right, Color(_color.r, _color.g, _color.b, alpha * 0.62), maxf(1.0, 1.5 * context.scale_factor), true)

	var fragments := [
		{"push": Vector2(-10.0, -2.0), "points": PackedVector2Array([Vector2(-8.0, -51.0), Vector2(-34.0, -47.0), Vector2(-27.0, -25.0), Vector2(-6.0, -31.0)])},
		{"push": Vector2(-13.0, 1.0), "points": PackedVector2Array([Vector2(-13.0, -15.0), Vector2(-43.0, -5.0), Vector2(-31.0, 18.0), Vector2(-7.0, 9.0)])},
		{"push": Vector2(-11.0, 4.0), "points": PackedVector2Array([Vector2(-14.0, 25.0), Vector2(-40.0, 36.0), Vector2(-25.0, 57.0), Vector2(-8.0, 47.0)])},
		{"push": Vector2(11.0, -3.0), "points": PackedVector2Array([Vector2(9.0, -50.0), Vector2(35.0, -42.0), Vector2(28.0, -21.0), Vector2(7.0, -29.0)])},
		{"push": Vector2(14.0, 1.0), "points": PackedVector2Array([Vector2(14.0, -13.0), Vector2(44.0, -1.0), Vector2(32.0, 21.0), Vector2(8.0, 10.0)])},
		{"push": Vector2(12.0, 4.0), "points": PackedVector2Array([Vector2(16.0, 27.0), Vector2(43.0, 40.0), Vector2(28.0, 58.0), Vector2(10.0, 48.0)])},
	]
	for fragment: Dictionary in fragments:
		var push: Vector2 = fragment["push"] * reveal
		var polygon := _screen_points(fragment["points"], center, crack_scale, push)
		canvas.draw_colored_polygon(polygon, Color(0.025, 0.075, 0.09, alpha * 0.84))
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		canvas.draw_polyline(outline, Color(_color.r, _color.g, _color.b, alpha * 0.34), maxf(1.0, 1.25 * context.scale_factor), true)

	var branch_paths := [
		PackedVector2Array([Vector2(-10.0, -39.0), Vector2(-39.0, -29.0), Vector2(-54.0, -12.0)]),
		PackedVector2Array([Vector2(12.0, -25.0), Vector2(38.0, -15.0), Vector2(54.0, 4.0)]),
		PackedVector2Array([Vector2(-12.0, 13.0), Vector2(-40.0, 24.0), Vector2(-55.0, 43.0)]),
		PackedVector2Array([Vector2(15.0, 34.0), Vector2(40.0, 44.0), Vector2(53.0, 59.0)]),
	]
	for path: PackedVector2Array in branch_paths:
		var screen_path := _screen_points(path, center, crack_scale)
		canvas.draw_polyline(screen_path, Color(0.0, 0.018, 0.025, alpha * 0.94), maxf(1.5, 3.3 * context.scale_factor), true)
		canvas.draw_polyline(screen_path, Color(_color.r, _color.g, _color.b, alpha * 0.28), maxf(1.0, 0.9 * context.scale_factor), true)

func _screen_points(
	points: PackedVector2Array,
	center: Vector2,
	crack_scale: float,
	offset: Vector2 = Vector2.ZERO
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		var local_point := point + offset
		var tangent := Vector2(-_direction.y, _direction.x)
		result.append(
			center
			+ tangent * local_point.x * crack_scale
			+ _direction * local_point.y * crack_scale
		)
	return result
