extends BallVisual

func trail_alpha() -> float:
	return 0.5

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	for index in range(9):
		var angle: float = fighter.rotation + TAU * float(index) / 9.0
		var root: Vector2 = position + Vector2.from_angle(angle) * radius * 0.72
		var tip: Vector2 = position + Vector2.from_angle(angle) * radius * (1.28 + 0.18 * sin(index * 2.0 + elapsed * 7.0))
		var tangent: Vector2 = Vector2.from_angle(angle + PI * 0.5) * radius * 0.15
		canvas.draw_colored_polygon(PackedVector2Array([root - tangent, tip, root + tangent]), Color("ff8b24"))
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position - Vector2(radius * 0.18, radius * 0.2), radius * 0.48, fighter.accent)
	canvas.draw_circle(position, radius, Color("ffd34b"), false, 2.0)
