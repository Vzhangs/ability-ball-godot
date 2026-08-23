extends BallVisual

func trail_alpha() -> float:
	return 0.2

func trail_width_multiplier() -> float:
	return 0.72

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position + Vector2(0.0, radius * 0.16), radius * 1.12, Color(0.02, 0.015, 0.035, 0.34))

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var rotation: float = fighter.rotation * 0.22
	canvas.draw_circle(position, radius * 1.08, Color(0.62, 0.86, 0.93, 0.11))
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius * 0.88, Color("322449"))
	_draw_web(canvas, position, radius, rotation, fighter.accent)
	_draw_spider(canvas, position + Vector2(radius * 0.28, radius * 0.3), radius, rotation)
	canvas.draw_circle(position, radius, fighter.accent, false, maxf(2.0, radius * 0.085), true)

func _draw_web(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	rotation: float,
	accent: Color
) -> void:
	var web_color := Color(accent.r, accent.g, accent.b, 0.68)
	for spoke_index in range(8):
		var angle := rotation + TAU * float(spoke_index) / 8.0
		canvas.draw_line(
			center + Vector2.from_angle(angle) * radius * 0.1,
			center + Vector2.from_angle(angle) * radius * 0.84,
			web_color,
			maxf(0.85, radius * 0.035),
			true
		)
	for ring_index in range(1, 4):
		var ring_radius := radius * (0.2 + ring_index * 0.17)
		for spoke_index in range(8):
			var start_angle := rotation + TAU * float(spoke_index) / 8.0 + 0.065
			var end_angle := rotation + TAU * float(spoke_index + 1) / 8.0 - 0.065
			canvas.draw_arc(
				center,
				ring_radius,
				start_angle,
				end_angle,
				6,
				Color(accent.r, accent.g, accent.b, 0.54),
				maxf(0.75, radius * 0.028),
				true
			)

func _draw_spider(canvas: CanvasItem, center: Vector2, radius: float, rotation: float) -> void:
	var spider_color := Color("f4fbff")
	var forward := Vector2.from_angle(rotation + PI * 0.5)
	var side := forward.orthogonal()
	canvas.draw_circle(center - forward * radius * 0.055, radius * 0.105, spider_color)
	canvas.draw_circle(center + forward * radius * 0.075, radius * 0.145, spider_color)
	for leg_index in range(4):
		var along := (float(leg_index) - 1.5) * radius * 0.065
		var root := center + forward * along
		var spread := radius * (0.19 + absf(float(leg_index) - 1.5) * 0.035)
		var bend := forward * (float(leg_index) - 1.5) * radius * 0.07
		for sign_value in [-1.0, 1.0]:
			var knee: Vector2 = root + side * spread * sign_value + bend
			var tip: Vector2 = knee + side * radius * 0.08 * sign_value + forward * radius * 0.07
			canvas.draw_polyline(
				PackedVector2Array([root, knee, tip]),
				spider_color,
				maxf(0.9, radius * 0.04),
				true
			)
