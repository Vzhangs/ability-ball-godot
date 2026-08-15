extends BallVisual

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	for index in range(9):
		var angle: float = fighter.rotation + TAU * float(index) / 9.0
		var root: Vector2 = position + Vector2.from_angle(angle) * radius * 0.72
		var tip: Vector2 = position + Vector2.from_angle(angle) * radius * 1.35
		var tangent: Vector2 = Vector2.from_angle(angle + PI * 0.5) * radius * 0.14
		canvas.draw_colored_polygon(PackedVector2Array([root - tangent, tip, root + tangent]), Color("185d31"))
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position - Vector2(radius * 0.2, radius * 0.22), radius * 0.48, fighter.accent)
	var fang_color := Color("fff4e8")
	for x in [-0.34, 0.34]:
		var base: Vector2 = position + Vector2(radius * x, radius * 0.34)
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-4.0, -3.0), base + Vector2(4.0, -3.0), base + Vector2(0.0, 8.0)]), fang_color)
