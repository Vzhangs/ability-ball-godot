extends BallVisual

func trail_alpha() -> float:
	return 0.12

func trail_width_multiplier() -> float:
	return 0.9

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var flash := _cast_flash_ratio()
	var domain_flash := _domain_flash_ratio()
	if domain_flash > 0.0:
		canvas.draw_circle(
			position,
			radius * (1.35 + domain_flash * 0.35),
			Color(0.34, 0.18, 0.78, domain_flash * 0.18)
		)
	for index in range(2):
		var angle := elapsed * (0.8 + float(index) * 0.22) + float(index) * PI
		var color := Color("54dcff") if _last_cast_kind() == "blue" else Color("ff4c70")
		color.a = 0.11 + flash * 0.16 - float(index) * 0.025
		canvas.draw_arc(
			position,
			radius * (1.08 + float(index) * 0.17 + flash * 0.18),
			angle,
			angle + PI * 0.82,
			28,
			color,
			1.5 + flash,
			true
		)

func draw_ball(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius, Color("f4d6b9"), true, -1.0, true)
	canvas.draw_circle(position, radius, Color("3b3544"), false, maxf(0.8, radius * 0.035), true)

	# A small collar leaves the lower face open.
	_shape(canvas, position, radius, [
		Vector2(-0.79, 0.60), Vector2(-0.49, 0.55), Vector2(0.0, 0.79),
		Vector2(0.49, 0.55), Vector2(0.79, 0.60), Vector2(0.63, 0.80),
		Vector2(0.35, 0.94), Vector2(0.0, 1.0), Vector2(-0.35, 0.94), Vector2(-0.63, 0.80),
	], Color("181c2b"))

	# A narrow cloth band wraps the eye line, with no visible eye painted on it.
	_shape(canvas, position, radius, [
		Vector2(-0.97, -0.25), Vector2(-0.49, -0.22), Vector2(0.0, -0.25),
		Vector2(0.50, -0.29), Vector2(0.96, -0.32), Vector2(0.98, -0.06),
		Vector2(0.51, 0.02), Vector2(0.0, 0.065), Vector2(-0.53, 0.025), Vector2(-0.99, -0.055),
	], Color("10131c"))
	_draw_hair(canvas, position, radius)

func _draw_hair(canvas: CanvasItem, position: Vector2, radius: float) -> void:
	var silhouette := [
		Vector2(-0.91, -0.28), Vector2(-1.02, -0.69), Vector2(-0.74, -0.55),
		Vector2(-0.70, -1.03), Vector2(-0.40, -0.78), Vector2(-0.20, -1.24),
		Vector2(0.03, -0.91), Vector2(0.34, -1.23), Vector2(0.43, -0.81),
		Vector2(0.82, -1.01), Vector2(0.75, -0.57), Vector2(1.02, -0.68),
		Vector2(0.87, -0.27), Vector2(0.57, -0.37), Vector2(0.36, -0.22),
		Vector2(0.09, -0.36), Vector2(-0.16, -0.22), Vector2(-0.41, -0.37),
		Vector2(-0.68, -0.23),
	]
	_shape(canvas, position, radius, silhouette, Color("f5f7fc"))
	var contour := silhouette.duplicate()
	contour.append(silhouette[0])
	_line(canvas, position, radius, contour, Color("a9b5c9"), 0.02)
	_line(canvas, position, radius, [Vector2(-0.34, -0.67), Vector2(-0.20, -0.40)], Color("d1dbea"), 0.026)
	_line(canvas, position, radius, [Vector2(0.37, -0.68), Vector2(0.48, -0.44)], Color("d1dbea"), 0.026)

func _shape(canvas: CanvasItem, position: Vector2, radius: float, points: Array, color: Color) -> void:
	var polygon := PackedVector2Array()
	for point: Vector2 in points:
		polygon.append(position + point * radius)
	canvas.draw_colored_polygon(polygon, color)

func _line(canvas: CanvasItem, position: Vector2, radius: float, points: Array, color: Color, width: float) -> void:
	var line := PackedVector2Array()
	for point: Vector2 in points:
		line.append(position + point * radius)
	canvas.draw_polyline(line, color, maxf(0.65, radius * width), true)

func _last_cast_kind() -> String:
	return String(ability.call("last_cast_kind")) if ability != null else "blue"

func _cast_flash_ratio() -> float:
	return float(ability.call("cast_flash_ratio")) if ability != null else 0.0

func _domain_flash_ratio() -> float:
	return float(ability.call("domain_flash_ratio")) if ability != null else 0.0
