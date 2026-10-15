extends BallVisual

func trail_alpha() -> float:
	return 0.0

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var p: Vector2 = context["position"]
	var r: float = context["radius"]
	var age: float = context["elapsed"]
	Surface.draw(canvas, p, r, fighter.color, fighter.accent, Surface.Style.GRADIENT, age)
	for index in range(3):
		var points := PackedVector2Array()
		for step in range(19):
			var t := step / 18.0
			var angle := age * 0.5 + index * TAU / 3.0 + t * PI * 0.9
			points.append(p + Vector2.from_angle(angle) * r * (0.18 + t * 0.6))
		canvas.draw_polyline(points, Color("f0fff7"), maxf(1.3, r * 0.1), true)
	canvas.draw_circle(p, r * 0.13, Color("104f49"))
