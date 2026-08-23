extends BallVisual

const STEEL_DARK := Color("536271")
const STEEL_MID := Color("c8d4dc")
const STEEL_LIGHT := Color("f5fbff")
const BLUE_DARK := Color("102b5c")
const BLUE_MID := Color("214f9c")
const BLUE_LIGHT := Color("4d83d1")
const GOLD_DARK := Color("9d701d")
const GOLD_MID := Color("e0ad3f")
const GOLD_LIGHT := Color("ffe49a")

func trail_alpha() -> float:
	return 0.2

func trail_width_multiplier() -> float:
	return 0.92

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var scale_factor: float = context["scale_factor"]
	var sword_length := module.settingf("sword_length") * scale_factor
	var sword_width := module.settingf("sword_width") * scale_factor
	var angle := _sword_angle()
	if _spin_active():
		_draw_spin_wake(canvas, position, radius, sword_length, sword_width, angle)
		var direction_sign := _spin_direction_sign()
		for afterimage_index in range(3, 0, -1):
			var trail_angle := angle - direction_sign * float(afterimage_index) * 0.13
			_draw_blade(
				canvas,
				position,
				radius,
				sword_length,
				sword_width,
				trail_angle,
				0.08 + float(3 - afterimage_index) * 0.055
			)
	_draw_blade(canvas, position, radius, sword_length, sword_width, angle, 1.0)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var scale_factor: float = context["scale_factor"]
	var direction := Vector2.from_angle(_sword_angle())
	var perpendicular := direction.orthogonal()

	canvas.draw_circle(position + Vector2(0.0, radius * 0.12), radius * 1.02, Color(0.0, 0.0, 0.0, 0.34))
	canvas.draw_circle(position, radius, BLUE_DARK)
	canvas.draw_circle(position, radius * 0.91, BLUE_MID)
	canvas.draw_circle(position + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.58, BLUE_LIGHT)

	var shield := PackedVector2Array([
		position + Vector2(-radius * 0.48, -radius * 0.42),
		position + Vector2(radius * 0.48, -radius * 0.42),
		position + Vector2(radius * 0.39, radius * 0.2),
		position + Vector2(0.0, radius * 0.66),
		position + Vector2(-radius * 0.39, radius * 0.2),
	])
	canvas.draw_colored_polygon(shield, Color(BLUE_DARK, 0.72))
	canvas.draw_polyline(_closed(shield), GOLD_LIGHT, maxf(1.5, radius * 0.07), true)
	canvas.draw_line(
		position + Vector2(0.0, -radius * 0.3),
		position + Vector2(0.0, radius * 0.39),
		GOLD_MID,
		maxf(2.0, radius * 0.1),
		true
	)
	canvas.draw_line(
		position + Vector2(-radius * 0.29, -radius * 0.06),
		position + Vector2(radius * 0.29, -radius * 0.06),
		GOLD_LIGHT,
		maxf(1.4, radius * 0.055),
		true
	)
	canvas.draw_circle(position, radius, fighter.accent, false, maxf(2.0, radius * 0.075), true)

	var guard_center := position + direction * radius * 0.78
	var guard_half_width := maxf(module.settingf("sword_width") * scale_factor * 1.25, radius * 0.27)
	canvas.draw_line(
		guard_center - perpendicular * guard_half_width,
		guard_center + perpendicular * guard_half_width,
		Color(0.06, 0.08, 0.12, 0.88),
		maxf(5.0, module.settingf("sword_width") * scale_factor * 0.34),
		true
	)
	canvas.draw_line(
		guard_center - perpendicular * guard_half_width,
		guard_center + perpendicular * guard_half_width,
		GOLD_LIGHT,
		maxf(2.8, module.settingf("sword_width") * scale_factor * 0.2),
		true
	)
	canvas.draw_circle(guard_center, maxf(3.0, radius * 0.1), GOLD_MID)
	canvas.draw_circle(guard_center, maxf(1.2, radius * 0.045), Color("80b7ff"))

func _draw_blade(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	length: float,
	width: float,
	angle: float,
	alpha: float
) -> void:
	var direction := Vector2.from_angle(angle)
	var perpendicular := direction.orthogonal()
	var blade_start := center + direction * radius * 0.72
	var shoulder := center + direction * (radius + length * 0.82)
	var tip := center + direction * (radius + length)
	var half_width := width * 0.5
	var blade := PackedVector2Array([
		blade_start - perpendicular * half_width * 0.78,
		shoulder - perpendicular * half_width,
		tip,
		shoulder + perpendicular * half_width,
		blade_start + perpendicular * half_width * 0.78,
	])
	canvas.draw_line(
		blade_start,
		tip,
		Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.18 * alpha),
		width * 1.85,
		true
	)
	canvas.draw_colored_polygon(blade, Color(STEEL_MID.r, STEEL_MID.g, STEEL_MID.b, alpha))
	canvas.draw_polyline(_closed(blade), Color(STEEL_DARK.r, STEEL_DARK.g, STEEL_DARK.b, alpha), maxf(1.2, width * 0.12), true)
	canvas.draw_line(
		blade_start + perpendicular * width * 0.12,
		shoulder + perpendicular * width * 0.16,
		Color(STEEL_LIGHT.r, STEEL_LIGHT.g, STEEL_LIGHT.b, 0.92 * alpha),
		maxf(1.0, width * 0.16),
		true
	)
	canvas.draw_line(
		center + direction * radius * 0.78,
		center + direction * radius * 0.18,
		Color(GOLD_DARK.r, GOLD_DARK.g, GOLD_DARK.b, alpha),
		maxf(2.5, width * 0.26),
		true
	)

func _draw_spin_wake(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	length: float,
	width: float,
	angle: float
) -> void:
	var outer_radius := radius + length * 0.92
	var direction_sign := _spin_direction_sign()
	for wake_index in range(3):
		var wake_radius := outer_radius - float(wake_index) * maxf(5.0, width * 0.72)
		var wake_span := 0.62 + float(wake_index) * 0.12
		var start_angle := angle - direction_sign * wake_span
		var finish_angle := angle
		if direction_sign < 0.0:
			var swap := start_angle
			start_angle = finish_angle
			finish_angle = swap
		canvas.draw_arc(
			center,
			wake_radius,
			start_angle,
			finish_angle,
			24,
			Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, 0.22 - float(wake_index) * 0.045),
			maxf(1.2, width * (0.22 - float(wake_index) * 0.035)),
			true
		)

func _sword_angle() -> float:
	return float(ability.call("sword_angle")) if ability != null else 0.0

func _spin_active() -> bool:
	return bool(ability.call("spin_active")) if ability != null else false

func _spin_direction_sign() -> float:
	return float(ability.call("spin_direction_sign")) if ability != null else 1.0

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
