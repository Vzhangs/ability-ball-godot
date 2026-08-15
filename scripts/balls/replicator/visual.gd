extends BallVisual

func draw_underlay(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	if fighter.clone_count <= 0:
		return
	var scale_factor: float = context["scale_factor"]
	var clone_radius: float = fighter.radius * 0.36 * scale_factor
	for index in range(fighter.clone_count):
		var angle: float = fighter.aux_angle * 1.2 + TAU * float(index) / float(fighter.clone_count)
		var orbit: float = (48.0 + fighter.clone_count * 3.5 + (index % 2) * 12.0) * scale_factor
		var position: Vector2 = context["position"] + Vector2.from_angle(angle) * orbit
		var color: Color = fighter.color
		color.a = 0.62
		canvas.draw_circle(position, clone_radius * 1.25, Color(fighter.accent.r, fighter.accent.g, fighter.accent.b, 0.18))
		canvas.draw_circle(position, clone_radius, color)
		canvas.draw_circle(position, clone_radius, fighter.accent, false, 1.2)
		canvas.draw_rect(Rect2(position - Vector2.ONE * clone_radius * 0.42, Vector2.ONE * clone_radius * 0.84), Color(0.88, 1.0, 0.96, 0.72), false, 1.0)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius, fighter.accent, false, 2.2)
	for index in range(3):
		var size_value := radius * (1.05 - index * 0.22)
		var rect := Rect2(position - Vector2.ONE * size_value * 0.5 + Vector2(index * 2.0, -index * 2.0), Vector2.ONE * size_value)
		canvas.draw_rect(rect, Color(0.82, 1.0, 0.94, 0.82 - index * 0.18), false, 2.0)
