extends BallVisual

func draw_underlay(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var scale_factor: float = context["scale_factor"]
	var position: Vector2 = context["position"]
	var shake_offset: Vector2 = context["shake_offset"]
	canvas.draw_set_transform(position + shake_offset, fighter.aux_angle, Vector2.ONE * scale_factor)
	canvas.draw_line(Vector2(8.0, 0.0), Vector2(116.0, 0.0), Color("b8936c"), 9.0, true)
	canvas.draw_line(Vector2(14.0, -2.0), Vector2(112.0, -2.0), Color(0.9, 0.78, 0.62, 0.65), 2.0, true)
	canvas.draw_rect(Rect2(Vector2(94.0, -28.0), Vector2(52.0, 56.0)), Color("5e646b"))
	canvas.draw_rect(Rect2(Vector2(98.0, -24.0), Vector2(44.0, 48.0)), Color("b4bbc1"), false, 3.0)
	canvas.draw_circle(Vector2(106.0, -16.0), 3.5, Color("eef1f4"))
	canvas.draw_circle(Vector2(134.0, 16.0), 3.5, Color("eef1f4"))
	canvas.draw_set_transform(shake_offset, 0.0, Vector2.ONE)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius, fighter.accent, false, 2.4)
	canvas.draw_circle(position, radius * 0.48, Color("50331f"))
	for index in range(4):
		canvas.draw_circle(position + Vector2.from_angle(TAU * index / 4.0 + PI * 0.25) * radius * 0.68, radius * 0.09, Color("d9c5ad"))
