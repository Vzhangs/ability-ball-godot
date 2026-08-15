extends BallVisual

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius, fighter.accent, false, 2.2)
	canvas.draw_line(position + Vector2(-radius * 0.68, 0.0), position + Vector2(radius * 0.68, 0.0), Color("ffb2db"), 3.0, true)
	canvas.draw_line(position + Vector2(0.0, -radius * 0.68), position + Vector2(0.0, radius * 0.68), Color("ffb2db"), 3.0, true)
	canvas.draw_circle(position, radius * 0.32, Color("230017"))
	canvas.draw_circle(position, radius * 0.19, Color.WHITE)
