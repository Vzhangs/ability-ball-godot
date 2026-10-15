extends BallVisual

func draw_underlay(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	pass

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.ORBIT, context["elapsed"])
	for index in range(3):
		var size_value := radius * (1.05 - index * 0.22)
		var rect := Rect2(position - Vector2.ONE * size_value * 0.5 + Vector2(index * 2.0, -index * 2.0), Vector2.ONE * size_value)
		canvas.draw_rect(rect, Color(0.82, 1.0, 0.94, 0.82 - index * 0.18), false, 2.0)
