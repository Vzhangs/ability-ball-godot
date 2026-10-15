extends BallVisual

func trail_alpha() -> float:
	return 0.38

func trail_width_multiplier() -> float:
	return 1.18

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	if ability == null or not bool(ability.call("is_recording_route")):
		return
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var pulse := 0.5 + 0.5 * sin(elapsed * 5.4)
	canvas.draw_arc(
		center,
		radius * (1.18 + pulse * 0.06),
		elapsed * 1.2,
		elapsed * 1.2 + PI * 1.45,
		30,
		Color(0.55, 0.9, 1.0, 0.18 + pulse * 0.14),
		maxf(1.4, radius * 0.07),
		true
	)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var pulse := 1.0 + sin(elapsed * 3.2) * 0.018
	canvas.draw_circle(center, radius * 1.16 * pulse, Color(0.36, 0.82, 1.0, 0.14))
	Surface.draw(canvas, center, radius, fighter.color, fighter.accent, Surface.Style.SOLID, context["elapsed"])
	canvas.draw_circle(center, radius, fighter.accent, false, maxf(2.5, radius * 0.09), true)
	_draw_conductor_cap(canvas, center, radius, fighter.accent)
	_draw_rail_badge(canvas, center + Vector2(0.0, radius * 0.19), radius, fighter.accent)

func _draw_conductor_cap(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	accent: Color
) -> void:
	var crown_center := center + Vector2(0.0, -radius * 0.38)
	var crown := PackedVector2Array([
		crown_center + Vector2(-radius * 0.56, radius * 0.08),
		crown_center + Vector2(-radius * 0.42, -radius * 0.28),
		crown_center + Vector2(radius * 0.42, -radius * 0.28),
		crown_center + Vector2(radius * 0.56, radius * 0.08),
	])
	canvas.draw_colored_polygon(crown, Color("102d42"))
	canvas.draw_line(
		crown_center + Vector2(-radius * 0.50, radius * 0.04),
		crown_center + Vector2(radius * 0.50, radius * 0.04),
		accent,
		maxf(2.0, radius * 0.10),
		true
	)
	canvas.draw_arc(
		crown_center + Vector2(0.0, radius * 0.10),
		radius * 0.57,
		0.12,
		PI - 0.12,
		20,
		Color("061822"),
		maxf(3.0, radius * 0.16),
		true
	)
	canvas.draw_circle(crown_center - Vector2(0.0, radius * 0.08), radius * 0.13, accent)
	canvas.draw_circle(crown_center - Vector2(0.0, radius * 0.08), radius * 0.065, Color("fff1ad"))

func _draw_rail_badge(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	accent: Color
) -> void:
	var badge_radius := radius * 0.32
	canvas.draw_circle(center, badge_radius * 1.16, Color(0.025, 0.09, 0.13, 0.88))
	canvas.draw_circle(center, badge_radius, accent, false, maxf(1.8, radius * 0.075), true)
	for spoke_index in range(6):
		var direction := Vector2.from_angle(float(spoke_index) * TAU / 6.0)
		canvas.draw_line(center, center + direction * badge_radius * 0.76, Color("ffe7a0"), maxf(1.0, radius * 0.045), true)
	canvas.draw_circle(center, badge_radius * 0.20, Color("ffe7a0"))
	canvas.draw_line(
		center + Vector2(-badge_radius * 0.82, badge_radius * 0.48),
		center + Vector2(badge_radius * 0.82, badge_radius * 0.48),
		Color("8fe6ff"),
		maxf(1.2, radius * 0.055),
		true
	)
