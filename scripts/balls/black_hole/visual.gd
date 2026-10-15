extends BallVisual

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	for ring in range(3):
		canvas.draw_arc(position, radius * (1.18 + ring * 0.18), fighter.rotation + ring, fighter.rotation + ring + PI * 1.5, 32, Color(0.65, 0.27, 1.0, 0.52 - ring * 0.1), 3.0, true)
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.ORBIT, context["elapsed"])
	canvas.draw_circle(position, radius * 0.42, Color("000000"))
	canvas.draw_circle(position - Vector2(radius * 0.18, radius * 0.2), radius * 0.11, fighter.accent)
