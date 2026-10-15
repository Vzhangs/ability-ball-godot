extends BallVisual

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var p: Vector2 = context["position"]
	var r: float = context["radius"]
	Surface.draw(canvas, p, r, fighter.color, fighter.accent, Surface.Style.METAL, context["elapsed"])
	canvas.draw_circle(p, r * 0.6, Color("174052"))
	for index in range(3):
		var n := Vector2.from_angle(index * TAU / 3.0 - PI / 2.0)
		var t := n.orthogonal()
		canvas.draw_colored_polygon(PackedVector2Array([p + n * r * 0.82, p + n * r * 0.32 + t * r * 0.15, p + n * r * 0.32 - t * r * 0.15]), Color("f8dc85"))
	canvas.draw_circle(p, r * 0.23, fighter.accent)
