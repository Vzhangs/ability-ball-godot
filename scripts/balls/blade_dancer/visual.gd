extends BallVisual

func trail_alpha() -> float:
	return 0.22 if ability != null and bool(ability.call("dash_active")) else 0.14

func trail_width_multiplier() -> float:
	return 1.25 if ability != null and bool(ability.call("dash_active")) else 0.9

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	for index in range(2):
		var angle := elapsed * (0.7 + float(index) * 0.18) + float(index) * PI
		canvas.draw_arc(
			position,
			radius * (1.16 + float(index) * 0.13),
			angle,
			angle + PI * 0.7,
			20,
			Color(0.56, 0.78, 1.0, 0.15 - float(index) * 0.03),
			1.5,
			true
		)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.CRYSTAL, context["elapsed"])
	canvas.draw_circle(position, radius, fighter.accent, false, 2.6)
	canvas.draw_arc(
		position,
		radius * 0.7,
		-PI * 0.86,
		-PI * 0.14,
		24,
		Color("d7efff"),
		2.4,
		true
	)
	canvas.draw_arc(
		position,
		radius * 0.7,
		PI * 0.14,
		PI * 0.86,
		24,
		Color("7dc5ff"),
		2.0,
		true
	)
	var crest := PackedVector2Array([
		position + Vector2(0.0, -radius * 0.58),
		position + Vector2(radius * 0.22, -radius * 0.08),
		position + Vector2(0.0, radius * 0.54),
		position + Vector2(-radius * 0.22, -radius * 0.08),
	])
	canvas.draw_colored_polygon(crest, Color("7bc9ff"))
	var inner_crest := PackedVector2Array([
		position + Vector2(0.0, -radius * 0.37),
		position + Vector2(radius * 0.1, -radius * 0.05),
		position + Vector2(0.0, radius * 0.34),
		position + Vector2(-radius * 0.1, -radius * 0.05),
	])
	canvas.draw_colored_polygon(inner_crest, Color("f4fbff"))
	canvas.draw_circle(position + Vector2(0.0, -radius * 0.04), radius * 0.09, Color("e7b5ff"))
