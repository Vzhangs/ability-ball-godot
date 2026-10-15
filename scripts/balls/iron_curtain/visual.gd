extends BallVisual

const IRON_BLACK := Color("101317")
const IRON_DARK := Color("242930")
const IRON_MID := Color("59616a")
const IRON_LIGHT := Color("c7ced1")
const CURTAIN_DARK := Color("4b080d")
const CURTAIN_RED := Color("a71920")
const CURTAIN_LIGHT := Color("ff6a54")
const ENERGY_WHITE := Color("ffe4ce")

func trail_alpha() -> float:
	return 0.25 if _curtain_form() else 0.2

func trail_width_multiplier() -> float:
	return 0.96 if _curtain_form() else 1.12

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	if _curtain_form():
		canvas.draw_circle(position, radius * 1.38, Color(1.0, 0.05, 0.035, 0.08))
		canvas.draw_circle(position, radius * 1.17, Color(0.0, 0.0, 0.0, 0.36))
		if _transform_animation_active():
			var progress := _transform_progress()
			var wave := sin(progress * PI)
			canvas.draw_circle(position, radius * (1.25 + progress * 1.6), Color(1.0, 0.06, 0.035, wave * 0.16))
			for ring_index in range(3):
				var ring_radius := radius * (1.08 + progress * (1.4 + ring_index * 0.36))
				canvas.draw_arc(position, ring_radius, progress * TAU + ring_index * 1.7, progress * TAU + ring_index * 1.7 + PI * 1.2, 32, Color(1.0, 0.25, 0.12, wave * (0.82 - ring_index * 0.18)), maxf(1.4, radius * 0.07), true)
		return
	_draw_dragon_cannon(
		canvas,
		position,
		radius,
		_facing_direction(),
		context
	)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	if _curtain_form():
		if _transform_animation_active():
			var transformed_context := context.duplicate()
			var radius: float = context["radius"]
			var transform_scale := _transform_body_scale()
			transformed_context["radius"] = radius * transform_scale
			transformed_context["position"] = (
				Vector2(context["position"])
				+ Vector2(0.0, radius * (1.0 - transform_scale) * 0.16)
			)
			_draw_curtain_ball(canvas, fighter, transformed_context)
			_draw_transform_overlay(canvas, context)
		else:
			_draw_curtain_ball(canvas, fighter, context)
	else:
		_draw_dragon_ball(canvas, fighter, context)

func _draw_transform_overlay(canvas: CanvasItem, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var progress := _transform_progress()
	var energy := sin(progress * PI)
	var collapse_ease := 1.0 - pow(1.0 - progress, 3.0)
	var shell_radius := lerpf(radius * 2.75, radius * 1.02, collapse_ease)
	var glow_alpha := energy * 0.24
	canvas.draw_circle(position, shell_radius * 1.08, Color(1.0, 0.025, 0.018, glow_alpha))
	canvas.draw_circle(
		position,
		shell_radius,
		Color(1.0, 0.18, 0.08, energy * 0.88),
		false,
		maxf(2.2, radius * 0.085),
		true
	)
	for ring_index in range(3):
		var ring_radius := shell_radius * (0.72 + float(ring_index) * 0.13)
		var rotation := progress * TAU * (1.2 + ring_index * 0.22) + ring_index * 1.42
		canvas.draw_arc(
			position,
			ring_radius,
			rotation,
			rotation + PI * (0.62 + ring_index * 0.13),
			30,
			Color(1.0, 0.42 + ring_index * 0.1, 0.24, energy * (0.9 - ring_index * 0.15)),
			maxf(1.5, radius * (0.075 - ring_index * 0.012)),
			true
		)
	for plate_index in range(8):
		var angle := TAU * float(plate_index) / 8.0 - progress * TAU * 0.92
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var plate_center := position + direction * shell_radius
		var half_radial := radius * (0.12 + energy * 0.05)
		var half_tangent := radius * (0.17 + energy * 0.08)
		var plate := PackedVector2Array([
			plate_center - direction * half_radial - tangent * half_tangent,
			plate_center + direction * half_radial - tangent * half_tangent * 0.66,
			plate_center + direction * half_radial + tangent * half_tangent * 0.66,
			plate_center - direction * half_radial + tangent * half_tangent,
		])
		canvas.draw_colored_polygon(plate, Color(0.55, 0.035, 0.04, energy * 0.9))
		canvas.draw_polyline(
			_closed(plate),
			Color(1.0, 0.45, 0.26, energy),
			maxf(1.2, radius * 0.045),
			true
		)
		canvas.draw_line(
			plate_center - direction * half_radial,
			position + direction * radius * 0.62,
			Color(1.0, 0.12, 0.06, energy * 0.42),
			maxf(1.1, radius * 0.035),
			true
		)
	var ignition := clampf(1.0 - absf(progress - 0.56) / 0.2, 0.0, 1.0)
	canvas.draw_circle(position, radius * (0.42 + ignition * 0.78), Color(1.0, 0.12, 0.045, ignition * 0.28))
	canvas.draw_circle(position, radius * (0.16 + ignition * 0.32), Color(1.0, 0.88, 0.68, ignition * 0.86))
	for spark_index in range(6):
		var spark_direction := Vector2.from_angle(
			TAU * float(spark_index) / 6.0 + progress * TAU * 0.58
		)
		canvas.draw_line(
			position + spark_direction * radius * 0.52,
			position + spark_direction * radius * (1.18 + ignition * 0.62),
			Color(1.0, 0.74, 0.48, energy * 0.86),
			maxf(1.2, radius * 0.042),
			true
		)

func _draw_curtain_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	canvas.draw_circle(position + Vector2(0.0, radius * 0.16), radius * 1.03, Color(0.0, 0.0, 0.0, 0.42))
	Surface.draw(canvas, position, radius, CURTAIN_RED, CURTAIN_LIGHT, Surface.Style.GRADIENT, context["elapsed"])
	for segment_index in range(8):
		var angle := TAU * float(segment_index) / 8.0 + elapsed * 0.18
		var direction := Vector2.from_angle(angle)
		var perpendicular := direction.orthogonal()
		var inner := position + direction * radius * 0.73
		var outer := position + direction * radius * 0.98
		var half_width := radius * 0.12
		var plate := PackedVector2Array([
			inner - perpendicular * half_width,
			outer - perpendicular * half_width * 0.72,
			outer + perpendicular * half_width * 0.72,
			inner + perpendicular * half_width,
		])
		canvas.draw_colored_polygon(plate, IRON_MID if segment_index % 2 == 0 else IRON_DARK)
		canvas.draw_polyline(_closed(plate), IRON_BLACK, maxf(1.0, radius * 0.035), true)
	var pulse := 0.88 + 0.12 * sin(elapsed * 4.8)
	canvas.draw_circle(position, radius * 0.42 * pulse, Color("ff241e"))
	canvas.draw_circle(position, radius * 0.27 * pulse, CURTAIN_LIGHT)
	canvas.draw_circle(position - Vector2(radius * 0.08, radius * 0.1), radius * 0.1, ENERGY_WHITE)
	for brace_angle in [0.0, PI * 0.5]:
		var direction := Vector2.from_angle(brace_angle)
		canvas.draw_line(position - direction * radius * 0.62, position + direction * radius * 0.62, Color(0.15, 0.02, 0.025, 0.78), maxf(2.3, radius * 0.095), true)
	canvas.draw_circle(position, radius, fighter.accent, false, maxf(2.1, radius * 0.065), true)

func _draw_dragon_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var direction := _facing_direction()
	var perpendicular := direction.orthogonal()
	canvas.draw_circle(position + Vector2(0.0, radius * 0.17), radius * 1.08, Color(0.0, 0.0, 0.0, 0.46))
	Surface.draw(canvas, position, radius, IRON_DARK, IRON_MID, Surface.Style.METAL, context["elapsed"])
	for side_sign in [-1.0, 1.0]:
		var pod_center: Vector2 = position + perpendicular * radius * 0.65 * side_sign - direction * radius * 0.05
		var pod := _oriented_box(pod_center, direction, perpendicular, radius * 0.58, radius * 0.25)
		canvas.draw_colored_polygon(pod, Color("373d44"))
		canvas.draw_polyline(_closed(pod), IRON_BLACK, maxf(1.5, radius * 0.055), true)
		for tread_index in range(3):
			var tread_center: Vector2 = pod_center + direction * radius * (-0.34 + tread_index * 0.34)
			canvas.draw_circle(tread_center, radius * 0.105, Color("111418"))
			canvas.draw_circle(tread_center, radius * 0.052, IRON_MID)
	var front_center := position + direction * radius * 0.48
	var front_armor := PackedVector2Array([
		position - perpendicular * radius * 0.5 - direction * radius * 0.18,
		front_center - perpendicular * radius * 0.44,
		position + direction * radius * 0.84,
		front_center + perpendicular * radius * 0.44,
		position + perpendicular * radius * 0.5 - direction * radius * 0.18,
	])
	canvas.draw_colored_polygon(front_armor, IRON_MID)
	canvas.draw_polyline(_closed(front_armor), IRON_BLACK, maxf(1.7, radius * 0.065), true)
	for vent_sign in [-1.0, 1.0]:
		var vent_start: Vector2 = position + direction * radius * 0.12 + perpendicular * radius * 0.26 * vent_sign
		canvas.draw_line(vent_start - direction * radius * 0.2, vent_start + direction * radius * 0.34, Color("ff3228"), maxf(2.0, radius * 0.09), true)
		canvas.draw_line(vent_start - direction * radius * 0.18, vent_start + direction * radius * 0.3, Color("ff9275"), maxf(0.9, radius * 0.028), true)
	var turret_center := position - direction * radius * 0.06
	canvas.draw_circle(turret_center, radius * 0.43, IRON_BLACK)
	canvas.draw_circle(turret_center, radius * 0.34, Color("656d73"))
	canvas.draw_circle(turret_center - direction * radius * 0.03, radius * 0.18, Color("a51a20"))
	canvas.draw_circle(turret_center, radius * 0.08, Color("ff6e4c"))
	canvas.draw_circle(position, radius, fighter.accent, false, maxf(2.1, radius * 0.067), true)
	_draw_muzzle_flash(canvas, position, radius, direction)

func _draw_dragon_cannon(
	canvas: CanvasItem,
	position: Vector2,
	radius: float,
	direction: Vector2,
	_context: Dictionary
) -> void:
	var perpendicular := direction.orthogonal()
	var barrel_start := position + direction * radius * 0.12
	var barrel_end := position + direction * radius * 2.38
	canvas.draw_line(barrel_start, barrel_end, Color(0.0, 0.0, 0.0, 0.48), maxf(9.0, radius * 0.34), true)
	canvas.draw_line(barrel_start, barrel_end, IRON_MID, maxf(6.0, radius * 0.23), true)
	canvas.draw_line(barrel_start + perpendicular * radius * 0.06, barrel_end + perpendicular * radius * 0.06, IRON_LIGHT, maxf(1.2, radius * 0.045), true)
	for collar_ratio in [0.42, 0.72, 0.92]:
		var collar := barrel_start.lerp(barrel_end, collar_ratio)
		canvas.draw_line(collar - perpendicular * radius * 0.18, collar + perpendicular * radius * 0.18, IRON_BLACK, maxf(4.5, radius * 0.15), true)
		canvas.draw_line(collar - perpendicular * radius * 0.15, collar + perpendicular * radius * 0.15, Color("7b848a"), maxf(2.0, radius * 0.065), true)
	canvas.draw_circle(barrel_end, radius * 0.17, IRON_BLACK)
	canvas.draw_circle(barrel_end, radius * 0.1, Color("d51d20"))

func _draw_muzzle_flash(canvas: CanvasItem, position: Vector2, radius: float, direction: Vector2) -> void:
	if not _muzzle_flash_active():
		return
	var progress := _muzzle_flash_progress()
	var alpha := sin(progress * PI)
	var center := position + direction * radius * 2.48
	canvas.draw_circle(center, radius * (0.22 + alpha * 0.32), Color(1.0, 0.16, 0.08, alpha * 0.26))
	canvas.draw_circle(center, radius * (0.12 + alpha * 0.18), Color(1.0, 0.56, 0.3, alpha * 0.82))
	canvas.draw_circle(center, radius * (0.04 + alpha * 0.07), Color(1.0, 0.94, 0.8, alpha))

func _curtain_form() -> bool:
	return bool(ability.call("is_curtain_form")) if ability != null else false

func _facing_direction() -> Vector2:
	var direction := Vector2(ability.call("facing_direction")) if ability != null else Vector2.RIGHT
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT

func _transform_progress() -> float:
	return float(ability.call("transform_animation_progress")) if ability != null else 1.0

func _transform_animation_active() -> bool:
	return bool(ability.call("transform_animation_active")) if ability != null else false

func _transform_body_scale() -> float:
	if not _transform_animation_active():
		return 1.0
	var progress := _transform_progress()
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	return lerpf(0.42, 1.0, eased) + sin(progress * PI) * 0.14

func _muzzle_flash_progress() -> float:
	return float(ability.call("muzzle_flash_progress")) if ability != null else 1.0

func _muzzle_flash_active() -> bool:
	return bool(ability.call("muzzle_flash_active")) if ability != null else false

func _oriented_box(
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	half_length: float,
	half_width: float
) -> PackedVector2Array:
	return PackedVector2Array([
		center - direction * half_length - perpendicular * half_width,
		center + direction * half_length - perpendicular * half_width,
		center + direction * half_length + perpendicular * half_width,
		center - direction * half_length + perpendicular * half_width,
	])

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
