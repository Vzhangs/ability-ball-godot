extends BallVisual

func trail_alpha() -> float:
	return 0.22

func trail_width_multiplier() -> float:
	return 1.08

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	canvas.draw_circle(position, radius * 1.14, Color(1.0, 0.22, 0.025, 0.18))
	for flame_index in range(7):
		var horizontal_ratio := -0.78 + float(flame_index) * 0.26
		var base := position + Vector2(
			horizontal_ratio * radius,
			radius * (0.42 - absf(horizontal_ratio) * 0.12)
		)
		var flicker := 0.84 + 0.19 * sin(elapsed * 10.2 + float(flame_index) * 1.67)
		var tip := base + Vector2(
			sin(elapsed * 7.6 + float(flame_index) * 2.03) * radius * 0.1,
			-radius * (0.8 + float(flame_index % 3) * 0.16) * flicker
		)
		_draw_flame_tongue(
			canvas,
			base,
			tip,
			radius * (0.18 + float(flame_index % 2) * 0.025)
		)
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.GRADIENT, context["elapsed"])
	_draw_core_flame(canvas, position + Vector2(0.0, radius * 0.1), radius, elapsed)
	canvas.draw_circle(position, radius, Color("ffd45b"), false, 2.4)

func _draw_flame_tongue(
	canvas: CanvasItem,
	base: Vector2,
	tip: Vector2,
	half_width: float
) -> void:
	var height := base.distance_to(tip)
	if height <= 0.001:
		return
	var upward := (tip - base) / height
	var sideways := upward.rotated(PI * 0.5)
	var shoulder := base + upward * height * 0.4
	canvas.draw_colored_polygon(PackedVector2Array([
		base - sideways * half_width,
		shoulder - sideways * half_width * 0.72,
		tip,
		shoulder + sideways * half_width * 0.5,
		base + sideways * half_width,
	]), Color("ff4315"))
	var inner_base := base + upward * height * 0.08
	var inner_tip := base + upward * height * 0.62
	var inner_shoulder := inner_base.lerp(inner_tip, 0.42)
	canvas.draw_colored_polygon(PackedVector2Array([
		inner_base - sideways * half_width * 0.42,
		inner_shoulder - sideways * half_width * 0.28,
		inner_tip,
		inner_shoulder + sideways * half_width * 0.22,
		inner_base + sideways * half_width * 0.42,
	]), Color("ffd048"))

func _draw_core_flame(
	canvas: CanvasItem,
	position: Vector2,
	radius: float,
	elapsed: float
) -> void:
	var sway := sin(elapsed * 6.8) * radius * 0.06
	var outer_points := PackedVector2Array([
		position + Vector2(-radius * 0.38, radius * 0.44),
		position + Vector2(-radius * 0.48, radius * 0.02),
		position + Vector2(-radius * 0.16, -radius * 0.28),
		position + Vector2(sway, -radius * 0.76),
		position + Vector2(radius * 0.16, -radius * 0.2),
		position + Vector2(radius * 0.44, radius * 0.08),
		position + Vector2(radius * 0.34, radius * 0.44),
	])
	canvas.draw_colored_polygon(outer_points, Color("ff6c20"))
	canvas.draw_colored_polygon(PackedVector2Array([
		position + Vector2(-radius * 0.2, radius * 0.4),
		position + Vector2(-radius * 0.22, radius * 0.1),
		position + Vector2(radius * 0.02, -radius * 0.34),
		position + Vector2(radius * 0.1, radius * 0.04),
		position + Vector2(radius * 0.24, radius * 0.22),
		position + Vector2(radius * 0.17, radius * 0.4),
	]), Color("ffe45e"))
