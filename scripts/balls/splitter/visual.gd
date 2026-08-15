extends BallVisual

func draw_underlay(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	if fighter.clone_count <= 0:
		return
	var scale_factor: float = context["scale_factor"]
	var clone_radius: float = fighter.radius * 0.46 * scale_factor
	for index in range(fighter.clone_count):
		var angle: float = fighter.aux_angle * -0.85 + TAU * float(index) / float(fighter.clone_count)
		var orbit: float = (48.0 + fighter.clone_count * 3.5 + (index % 2) * 12.0) * scale_factor
		var position: Vector2 = context["position"] + Vector2.from_angle(angle) * orbit
		var color: Color = fighter.color
		color.a = 0.84
		canvas.draw_circle(position, clone_radius * 1.25, Color(fighter.accent.r, fighter.accent.g, fighter.accent.b, 0.18))
		canvas.draw_circle(position, clone_radius, color)
		canvas.draw_circle(position, clone_radius, fighter.accent, false, 1.2)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius * 1.12, Color(fighter.accent.r, fighter.accent.g, fighter.accent.b, 0.22))
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_arc(position, radius * 0.65, -PI * 0.45, PI * 0.45, 18, fighter.accent, 3.0, true)
	canvas.draw_arc(position, radius * 0.65, PI * 0.55, PI * 1.45, 18, fighter.accent, 3.0, true)
	canvas.draw_circle(position + Vector2(-radius * 0.28, -radius * 0.28), radius * 0.13, Color.WHITE)
	canvas.draw_circle(position + Vector2(radius * 0.26, radius * 0.22), radius * 0.10, fighter.accent)
