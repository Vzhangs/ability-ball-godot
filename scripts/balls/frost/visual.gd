extends BallVisual

func trail_alpha() -> float:
	return 0.2

func trail_width_multiplier() -> float:
	return 1.02

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var pulse := 0.96 + sin(elapsed * 3.4) * 0.035
	canvas.draw_circle(position, radius * 1.18 * pulse, Color(0.25, 0.85, 1.0, 0.16))
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.CRYSTAL, context["elapsed"])
	for facet_index in range(6):
		var angle := -PI * 0.86 + float(facet_index) * PI * 0.31
		var direction := Vector2.from_angle(angle)
		var tangent := direction.rotated(PI * 0.5)
		var base := position + direction * radius * 0.18
		var tip := position + direction * radius * 0.82
		var width := radius * (0.17 + float(facet_index % 2) * 0.035)
		canvas.draw_colored_polygon(PackedVector2Array([
			base - tangent * width,
			tip,
			base + tangent * width,
		]), Color(0.66, 0.94, 1.0, 0.18 + float(facet_index % 3) * 0.05))
	_draw_snowflake(canvas, position, radius * 0.66, elapsed * 0.18)
	canvas.draw_arc(position, radius, 0.0, TAU, 40, fighter.accent, maxf(2.2, radius * 0.08), true)
	canvas.draw_arc(position, radius * 0.78, -PI * 0.82, -PI * 0.18, 16, Color(0.9, 1.0, 1.0, 0.76), maxf(1.4, radius * 0.05), true)

func _draw_snowflake(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	rotation: float
) -> void:
	for arm_index in range(6):
		var direction := Vector2.from_angle(rotation + float(arm_index) * TAU / 6.0)
		var tangent := direction.rotated(PI * 0.5)
		var tip := center + direction * size
		var branch_root := center + direction * size * 0.56
		canvas.draw_line(center, tip, Color(0.92, 1.0, 1.0, 0.98), maxf(1.5, size * 0.11), true)
		canvas.draw_line(
			branch_root,
			branch_root - direction * size * 0.19 + tangent * size * 0.22,
			Color(0.85, 0.99, 1.0, 0.96),
			maxf(1.1, size * 0.08),
			true
		)
		canvas.draw_line(
			branch_root,
			branch_root - direction * size * 0.19 - tangent * size * 0.22,
			Color(0.85, 0.99, 1.0, 0.96),
			maxf(1.1, size * 0.08),
			true
		)
	canvas.draw_circle(center, maxf(1.6, size * 0.12), Color("efffff"))
