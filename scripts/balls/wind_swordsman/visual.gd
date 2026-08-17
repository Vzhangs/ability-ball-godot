extends BallVisual

func trail_alpha() -> float:
	return 0.18

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	for index in range(3):
		var start := elapsed * (0.65 + float(index) * 0.08) + float(index) * 1.8
		canvas.draw_arc(
			position,
			radius * (1.24 + float(index) * 0.16),
			start,
			start + PI * 0.52,
			18,
			Color(0.36, 0.92, 1.0, 0.16 - float(index) * 0.03),
			1.6,
			true
		)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius * 0.82, Color("0b3445"))
	canvas.draw_circle(position, radius, fighter.accent, false, 2.5)
	canvas.draw_arc(position, radius * 0.58, -PI * 0.78, PI * 0.32, 22, Color("d6feff"), 3.2, true)
	canvas.draw_arc(position, radius * 0.38, PI * 0.16, PI * 1.18, 18, Color("55d8e8"), 2.2, true)
	var blade_direction := Vector2(0.72, -0.69)
	canvas.draw_line(
		position - blade_direction * radius * 0.58,
		position + blade_direction * radius * 0.66,
		Color("e9ffff"),
		2.4,
		true
	)
	canvas.draw_circle(position + blade_direction * radius * 0.13, radius * 0.12, Color("8ff5ff"))
