extends BallVisual

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var colors := [Color("3b73df"), Color("f7d93f"), Color("d63a35"), Color("3ba969"), Color("ef8f32"), Color("7f55c7")]
	for wedge in range(6):
		var points := PackedVector2Array([position])
		var start_angle: float = -PI * 0.5 + TAU * float(wedge) / 6.0 + fighter.rotation * 0.12
		for segment in range(7):
			points.append(position + Vector2.from_angle(start_angle + TAU / 6.0 * float(segment) / 6.0) * radius)
		canvas.draw_colored_polygon(points, colors[wedge])
	canvas.draw_circle(position, radius, Color("fff5c9"), false, 2.2)
	var crown_level := 1
	if ability != null and ability.has_method("crown_level"):
		crown_level = int(ability.call("crown_level"))
	for level_index in range(1, crown_level):
		var level_radius := radius + 5.0 + level_index * 4.0
		var level_color := Color("ffe75a")
		level_color.a = 0.56 + level_index * 0.14
		canvas.draw_arc(position, level_radius, -PI * 0.82, -PI * 0.18, 22, level_color, 2.0, true)
