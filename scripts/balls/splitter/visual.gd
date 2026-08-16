extends BallVisual

func draw_underlay(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	pass

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius * 1.12, Color(fighter.accent.r, fighter.accent.g, fighter.accent.b, 0.22))
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_arc(position, radius * 0.65, -PI * 0.45, PI * 0.45, 18, fighter.accent, 3.0, true)
	canvas.draw_arc(position, radius * 0.65, PI * 0.55, PI * 1.45, 18, fighter.accent, 3.0, true)
	canvas.draw_circle(position + Vector2(-radius * 0.28, -radius * 0.28), radius * 0.13, Color.WHITE)
	canvas.draw_circle(position + Vector2(radius * 0.26, radius * 0.22), radius * 0.10, fighter.accent)
