extends BallVisual

func trail_alpha() -> float:
	return 0.5

func trail_width_multiplier() -> float:
	return 1.7

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	for index in range(3):
		var offset := Vector2.from_angle(fighter.velocity.angle() + PI) * radius * (1.25 + index * 0.4)
		canvas.draw_arc(position + offset, radius * (0.58 + index * 0.16), -PI * 0.5, PI * 0.5, 18, Color(0.45, 0.93, 1.0, 0.48 - index * 0.1), 3.0, true)
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius, fighter.accent, false, 2.4)
	var direction := Vector2.from_angle(fighter.velocity.angle())
	var tangent := Vector2(-direction.y, direction.x)
	var bolt := PackedVector2Array([
		position - direction * radius * 0.58 - tangent * radius * 0.18,
		position + direction * radius * 0.05 - tangent * radius * 0.26,
		position - direction * radius * 0.02 + tangent * radius * 0.06,
		position + direction * radius * 0.62 + tangent * radius * 0.12,
	])
	canvas.draw_polyline(bolt, Color.WHITE, 4.0, true)
