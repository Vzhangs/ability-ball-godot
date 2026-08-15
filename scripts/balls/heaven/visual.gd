extends BallVisual

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([
			position + Vector2(radius * side * 0.75, -radius * 0.2),
			position + Vector2(radius * side * 1.65, -radius * 0.78),
			position + Vector2(radius * side * 1.35, radius * 0.0),
			position + Vector2(radius * side * 1.72, radius * 0.28),
			position + Vector2(radius * side * 0.72, radius * 0.42),
		])
		canvas.draw_colored_polygon(wing, Color("f6f2df"))
		canvas.draw_polyline(wing, Color("ffd85a"), 1.5, true)
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius, fighter.accent, false, 2.4)
	canvas.draw_arc(position + Vector2(0.0, -radius * 0.92), radius * 0.52, 0.0, TAU, 32, Color("ffe56d"), 3.0, true)
	canvas.draw_circle(position - Vector2(radius * 0.22, radius * 0.22), radius * 0.22, Color.WHITE)
