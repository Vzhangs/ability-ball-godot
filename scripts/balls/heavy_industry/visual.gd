extends BallVisual

const OUTER_BLACK := Color("111619")
const BODY_SHADOW := Color("34171a")
const BODY_RED := Color("7b292d")
const BODY_RED_LIGHT := Color("aa4140")
const BRICK_DARK := Color("4a2023")
const BRICK_RED := Color("8f3034")
const VENT_RED := Color("c14845")
const METAL_DARK := Color("303a3f")
const METAL_MID := Color("718087")
const METAL_LIGHT := Color("d8dfdc")
const GATE_BLACK := Color("101719")
const GATE_INNER := Color("202a2e")
const GOLD_DARK := Color("9d6d22")
const GOLD_LIGHT := Color("f1c95c")
const HAZARD_DARK := Color("2c2415")
const PORT_BACK_RADIUS_SCALE := 0.84
const PORT_FRONT_RADIUS_SCALE := 1.62
const PORT_HALF_WIDTH_RADIUS_SCALE := 0.55

func trail_alpha() -> float:
	return 0.18

func trail_width_multiplier() -> float:
	return 0.86

func deployment_port_width_to_length_ratio() -> float:
	return (
		PORT_HALF_WIDTH_RADIUS_SCALE * 2.0
		/ (PORT_FRONT_RADIUS_SCALE - PORT_BACK_RADIUS_SCALE)
	)

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius * 1.16, Color(0.72, 0.13, 0.12, 0.1))
	canvas.draw_circle(
		position + Vector2(0.0, radius * 0.23),
		radius * 1.09,
		Color(0.0, 0.0, 0.0, 0.38)
	)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var port_direction := Vector2.from_angle(_port_angle())
	var deployment_active := _deployment_animation_active()
	var deployment_progress := _deployment_animation_progress()
	var gate_open_amount := _deployment_gate_open_amount()

	# The factory shell stays frontal; its single deployment port rotates as one assembly.
	canvas.draw_circle(position, radius, OUTER_BLACK)
	canvas.draw_circle(position, radius * 0.93, BODY_SHADOW)
	canvas.draw_circle(position, radius * 0.86, BODY_RED)
	canvas.draw_circle(
		position + Vector2(-radius * 0.11, -radius * 0.16),
		radius * 0.67,
		BODY_RED_LIGHT
	)
	_draw_side_exhaust_towers(canvas, position, radius)
	_draw_central_tower(canvas, position, radius)
	canvas.draw_circle(position, radius * 0.965, METAL_MID, false, maxf(2.8, radius * 0.105), true)
	canvas.draw_arc(
		position,
		radius * 0.965,
		PI * 1.04,
		PI * 1.82,
		24,
		METAL_LIGHT,
		maxf(1.2, radius * 0.042),
		true
	)
	canvas.draw_circle(position, radius, fighter.accent, false, maxf(1.7, radius * 0.055), true)
	_draw_deployment_port(
		canvas,
		position,
		port_direction,
		radius,
		fighter.accent,
		gate_open_amount,
		deployment_progress,
		deployment_active
	)

func _draw_side_exhaust_towers(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	for side_sign in [-1.0, 1.0]:
		var tower_center := center + Vector2(radius * 0.56 * side_sign, -radius * 0.12)
		var tower_shape := PackedVector2Array([
			tower_center + Vector2(-radius * 0.18, radius * 0.42),
			tower_center + Vector2(-radius * 0.2, -radius * 0.25),
			tower_center + Vector2(-radius * 0.1, -radius * 0.42),
			tower_center + Vector2(radius * 0.15, -radius * 0.34),
			tower_center + Vector2(radius * 0.18, radius * 0.42),
		])
		canvas.draw_colored_polygon(tower_shape, BRICK_DARK)
		var front_face := PackedVector2Array([
			tower_center + Vector2(-radius * 0.13, radius * 0.35),
			tower_center + Vector2(-radius * 0.13, -radius * 0.24),
			tower_center + Vector2(radius * 0.11, -radius * 0.19),
			tower_center + Vector2(radius * 0.12, radius * 0.35),
		])
		canvas.draw_colored_polygon(front_face, BRICK_RED)
		canvas.draw_polyline(_closed(tower_shape), OUTER_BLACK, maxf(1.2, radius * 0.045), true)
		for slit_index in range(3):
			var slit_y := tower_center.y - radius * (0.27 - float(slit_index) * 0.105)
			canvas.draw_line(
				Vector2(tower_center.x - radius * 0.095, slit_y),
				Vector2(tower_center.x + radius * 0.085, slit_y + radius * 0.025),
				OUTER_BLACK,
				maxf(1.7, radius * 0.06),
				true
			)
		canvas.draw_line(
			tower_center + Vector2(-radius * 0.135, radius * 0.04),
			tower_center + Vector2(-radius * 0.135, radius * 0.31),
			VENT_RED,
			maxf(1.5, radius * 0.05),
			true
		)

func _draw_central_tower(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	var tower_bounds := Rect2(
		center + Vector2(-radius * 0.24, -radius * 0.56),
		Vector2(radius * 0.48, radius * 0.37)
	)
	canvas.draw_rect(tower_bounds, METAL_DARK)
	canvas.draw_rect(tower_bounds, OUTER_BLACK, false, maxf(1.4, radius * 0.05))
	for window_index in range(3):
		var window_x := center.x + radius * (-0.14 + float(window_index) * 0.14)
		canvas.draw_line(
			Vector2(window_x, center.y - radius * 0.49),
			Vector2(window_x, center.y - radius * 0.28),
			METAL_LIGHT,
			maxf(1.5, radius * 0.05),
			true
		)
	var dome := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.92),
		center + Vector2(radius * 0.075, -radius * 0.78),
		center + Vector2(radius * 0.235, -radius * 0.66),
		center + Vector2(radius * 0.19, -radius * 0.53),
		center + Vector2(radius * 0.08, -radius * 0.46),
		center + Vector2(-radius * 0.08, -radius * 0.46),
		center + Vector2(-radius * 0.19, -radius * 0.53),
		center + Vector2(-radius * 0.235, -radius * 0.66),
		center + Vector2(-radius * 0.075, -radius * 0.78),
	])
	canvas.draw_colored_polygon(dome, GOLD_DARK)
	canvas.draw_polyline(_closed(dome), OUTER_BLACK, maxf(1.2, radius * 0.04), true)
	var dome_highlight := PackedVector2Array([
		center + Vector2(-radius * 0.02, -radius * 0.87),
		center + Vector2(radius * 0.09, -radius * 0.75),
		center + Vector2(radius * 0.15, -radius * 0.65),
		center + Vector2(radius * 0.1, -radius * 0.55),
		center + Vector2(radius * 0.02, -radius * 0.5),
	])
	canvas.draw_polyline(dome_highlight, GOLD_LIGHT, maxf(1.7, radius * 0.06), true)
	canvas.draw_line(
		center + Vector2(0.0, -radius * 0.92),
		center + Vector2(0.0, -radius * 0.99),
		GOLD_LIGHT,
		maxf(1.4, radius * 0.045),
		true
	)

func _draw_deployment_port(
	canvas: CanvasItem,
	center: Vector2,
	direction: Vector2,
	radius: float,
	accent: Color,
	gate_open_amount: float,
	deployment_progress: float,
	deployment_active: bool
) -> void:
	var perpendicular := direction.orthogonal()

	# The bay is wider across its mouth than it is long, with only a shallow in-body socket.
	var port_back: Vector2 = center + direction * radius * PORT_BACK_RADIUS_SCALE
	var port_front: Vector2 = center + direction * radius * PORT_FRONT_RADIUS_SCALE
	var port_half_width := radius * PORT_HALF_WIDTH_RADIUS_SCALE
	var port_shape := PackedVector2Array([
		port_back - perpendicular * port_half_width,
		port_front - perpendicular * port_half_width,
		port_front + perpendicular * port_half_width,
		port_back + perpendicular * port_half_width,
	])
	var port_shadow := PackedVector2Array()
	for point in port_shape:
		port_shadow.append(point + Vector2(0.0, radius * 0.09))
	canvas.draw_colored_polygon(port_shadow, Color(0.0, 0.0, 0.0, 0.34))
	canvas.draw_colored_polygon(port_shape, METAL_MID)
	canvas.draw_polyline(_closed(port_shape), OUTER_BLACK, maxf(3.2, radius * 0.11), true)
	canvas.draw_polyline(_closed(port_shape), METAL_LIGHT, maxf(1.35, radius * 0.045), true)

	var tunnel_back: Vector2 = center + direction * radius * 0.92
	var tunnel_front: Vector2 = center + direction * radius * 1.52
	var tunnel_half_width := radius * 0.42
	var tunnel_shape := PackedVector2Array([
		tunnel_back - perpendicular * tunnel_half_width,
		tunnel_front - perpendicular * tunnel_half_width,
		tunnel_front + perpendicular * tunnel_half_width,
		tunnel_back + perpendicular * tunnel_half_width,
	])
	canvas.draw_colored_polygon(tunnel_shape, GATE_BLACK)
	for rail_sign in [-1.0, 1.0]:
		canvas.draw_line(
			tunnel_back + perpendicular * radius * 0.34 * rail_sign,
			tunnel_front + perpendicular * radius * 0.34 * rail_sign,
			METAL_LIGHT,
			maxf(1.4, radius * 0.05),
			true
		)
	for rib_index in range(3):
		var progress := (float(rib_index) + 1.0) / 4.0
		var rib_center := tunnel_back.lerp(tunnel_front, progress)
		var rib_color := Color(0.08, 0.11, 0.12, 0.92)
		if deployment_active and rib_index == int(floor(deployment_progress * 9.0)) % 3:
			rib_color = accent
		canvas.draw_line(
			rib_center - perpendicular * radius * 0.34,
			rib_center + perpendicular * radius * 0.34,
			rib_color,
			maxf(1.2, radius * 0.045),
			true
		)

	# Two armored leaves retract sideways to expose the conveyor during production.
	var door_back: Vector2 = center + direction * radius * 0.93
	var door_front: Vector2 = center + direction * radius * 1.51
	var door_half_width := radius * 0.405
	for door_sign in [-1.0, 1.0]:
		var outer_offset: Vector2 = perpendicular * door_half_width * door_sign
		var inner_offset: Vector2 = (
			perpendicular
			* door_half_width
			* 0.78
			* gate_open_amount
			* door_sign
		)
		var door_shape := PackedVector2Array([
			door_back + inner_offset,
			door_front + inner_offset,
			door_front + outer_offset,
			door_back + outer_offset,
		])
		canvas.draw_colored_polygon(door_shape, GATE_INNER)
		canvas.draw_polyline(_closed(door_shape), METAL_LIGHT, maxf(1.2, radius * 0.042), true)

	var shell_frame_center: Vector2 = center + direction * radius * 0.88
	canvas.draw_line(
		shell_frame_center - perpendicular * radius * 0.59,
		shell_frame_center + perpendicular * radius * 0.59,
		OUTER_BLACK,
		maxf(5.2, radius * 0.17),
		true
	)
	canvas.draw_line(
		shell_frame_center - perpendicular * radius * 0.56,
		shell_frame_center + perpendicular * radius * 0.56,
		METAL_LIGHT,
		maxf(2.0, radius * 0.068),
		true
	)
	for lamp_sign in [-1.0, 1.0]:
		var lamp_color := accent
		lamp_color.a = 1.0 if deployment_active else 0.55
		canvas.draw_circle(
			shell_frame_center + perpendicular * radius * 0.48 * lamp_sign,
			radius * (0.07 if deployment_active else 0.055),
			lamp_color
		)
	canvas.draw_line(
		port_front - perpendicular * port_half_width,
		port_front + perpendicular * port_half_width,
		HAZARD_DARK,
		maxf(3.8, radius * 0.13),
		true
	)
	for stripe_index in range(7):
		var stripe_offset := perpendicular * radius * lerpf(-0.42, 0.42, float(stripe_index) / 6.0)
		canvas.draw_line(
			port_front + stripe_offset - direction * radius * 0.05 - perpendicular * radius * 0.035,
			port_front + stripe_offset + direction * radius * 0.05 + perpendicular * radius * 0.035,
			accent,
			maxf(1.9, radius * 0.065),
			true
		)

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not points.is_empty():
		result.append(points[0])
	return result

func _port_angle() -> float:
	if ability != null and ability.has_method("port_angle"):
		return float(ability.call("port_angle"))
	return 0.0

func _deployment_animation_active() -> bool:
	return (
		ability != null
		and ability.has_method("deployment_animation_active")
		and bool(ability.call("deployment_animation_active"))
	)

func _deployment_animation_progress() -> float:
	if ability != null and ability.has_method("deployment_animation_progress"):
		return float(ability.call("deployment_animation_progress"))
	return 1.0

func _deployment_gate_open_amount() -> float:
	if ability != null and ability.has_method("deployment_gate_open_amount"):
		return float(ability.call("deployment_gate_open_amount"))
	return 0.0
