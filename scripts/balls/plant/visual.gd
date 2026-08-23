extends BallVisual

func trail_alpha() -> float:
	return 0.24

func draw_ball(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var pulse := 1.0 + sin(elapsed * 3.2) * 0.025
	var body_color := Color("39f05f")
	var body_shadow := Color("12a847")
	var body_light := Color("a9ff76")
	var outline := Color("d8ff67")

	# A bright layered green body that stays readable beneath the health number.
	canvas.draw_circle(position, radius * 1.2 * pulse, Color(0.28, 1.0, 0.38, 0.16))
	canvas.draw_circle(position, radius, body_shadow)
	canvas.draw_circle(position + Vector2(-radius * 0.08, -radius * 0.08), radius * 0.87, body_color)
	canvas.draw_circle(position + Vector2(-radius * 0.25, -radius * 0.3), radius * 0.34, Color(0.72, 1.0, 0.45, 0.34))
	canvas.draw_arc(position, radius, 0.0, TAU, 40, outline, maxf(2.5, radius * 0.1), true)

	# A polished sprout emblem: dark stem for silhouette, luminous leaf fills and veins.
	var sway := sin(elapsed * 2.5) * radius * 0.045
	var root := position + Vector2(0.0, radius * 0.48)
	var stem_top := position + Vector2(sway, -radius * 0.58)
	canvas.draw_line(root, stem_top, Color("08743a"), maxf(4.0, radius * 0.18), true)
	canvas.draw_line(root + Vector2(-radius * 0.04, 0.0), stem_top + Vector2(-radius * 0.03, 0.0), body_light, maxf(1.4, radius * 0.055), true)
	_draw_leaf(canvas, stem_top + Vector2(0.0, radius * 0.13), -2.63, radius, Color("8cff5b"), Color("e5ff7d"))
	_draw_leaf(canvas, stem_top, -0.51, radius, Color("b9ff55"), Color("f3ff9a"))
	canvas.draw_circle(stem_top + Vector2(-radius * 0.04, radius * 0.16), radius * 0.1, body_light)

func _draw_leaf(
	canvas: CanvasItem,
	root: Vector2,
	angle: float,
	radius: float,
	leaf_color: Color,
	vein_color: Color
) -> void:
	var direction := Vector2.from_angle(angle)
	var perpendicular := direction.rotated(PI * 0.5)
	var length := radius * 0.8
	var half_width := radius * 0.27
	var tip := root + direction * length
	var points := PackedVector2Array([
		root,
		root + direction * length * 0.46 + perpendicular * half_width,
		tip,
		root + direction * length * 0.46 - perpendicular * half_width,
	])
	canvas.draw_colored_polygon(points, leaf_color)
	var outline_points := points.duplicate()
	outline_points.append(points[0])
	canvas.draw_polyline(outline_points, Color("137f3b"), maxf(1.2, radius * 0.05), true)
	canvas.draw_line(root, tip * 0.82 + root * 0.18, vein_color, maxf(1.0, radius * 0.04), true)
