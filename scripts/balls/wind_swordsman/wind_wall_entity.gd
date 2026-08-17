extends BallEntity

const MIN_ARC_SEGMENTS := 12
const MAX_ARC_SEGMENTS := 96
const PULSE_DURATION := 0.28

var _direction := Vector2.RIGHT
var _duration := 1.0
var _curve_radius := 74.0
var _arc_span := deg_to_rad(120.0)
var _half_thickness := 6.0
var _color := Color("8ff5ff")
var _absorption_pulses: Array[Dictionary] = []

func _init(
	spawn_owner_side: int,
	arc_midpoint: Vector2,
	spawn_direction: Vector2,
	config: Dictionary,
	color: Color
) -> void:
	owner_side = spawn_owner_side
	pos = arc_midpoint
	_direction = spawn_direction.normalized()
	_duration = float(config["duration"])
	remaining = _duration
	_curve_radius = float(config["curve_radius"])
	_arc_span = float(config["arc_span"])
	_half_thickness = float(config["thickness"]) * 0.5
	radius = _half_thickness
	_color = color
	tags = PackedStringArray(["wind_wall"])
	draw_layer = -6

func step(battle, delta: float) -> void:
	_update_pulses(delta)
	intercept_projectiles(battle, delta)

func intercept_projectiles(battle, prediction_delta: float) -> int:
	var absorbed := 0
	for projectile: BallEntity in battle.entities(-1, "projectile"):
		if not projectile.is_hostile_to(owner_side):
			continue
		var start := projectile.pos
		var finish := start + projectile.velocity * maxf(0.0, prediction_delta)
		var hit_fraction := _interception_fraction(start, finish, projectile.radius)
		if hit_fraction < 0.0:
			continue
		var hit_position := start.lerp(finish, hit_fraction)
		var projectile_color := projectile.absorption_visual_color()
		projectile.pos = hit_position
		if not projectile.absorb(battle, owner_side, hit_position):
			projectile.removed = true
		_absorption_pulses.append({
			"pos": hit_position,
			"color": projectile_color,
			"remaining": PULSE_DURATION,
		})
		battle.spawn_particles(hit_position, projectile_color, 7, 120.0)
		battle.spawn_ring(hit_position, _color, 3.0, 34.0, 0.22)
		battle.emit_combat_event("wind_absorb", 0.68)
		battle.record_stat("projectiles_blocked")
		absorbed += 1
	return absorbed

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var lifetime_alpha := clampf(remaining / minf(_duration, 0.34), 0.0, 1.0)
	var capture_alpha := 0.58 if is_captured() else 1.0
	var alpha := lifetime_alpha * capture_alpha
	var display_color := ownership_visual_color(_color)
	var center := screen_position(context, _curve_center())
	var direction_angle := _direction.angle()
	var start_angle := direction_angle - _arc_span * 0.5
	for layer in range(-2, 3):
		var layer_offset := float(layer) * _half_thickness * 0.28
		var layer_radius := (_curve_radius + layer_offset) * scale_factor
		var layer_alpha := alpha * (0.72 - absf(float(layer)) * 0.12)
		canvas.draw_arc(
			center,
			layer_radius,
			start_angle,
			start_angle + _arc_span,
			48,
			Color(display_color.r, display_color.g, display_color.b, layer_alpha),
			maxf(1.0, (3.4 - absf(float(layer)) * 0.65) * scale_factor),
			true
		)
	for wisp in range(5):
		var travel := fmod(context.elapsed * (0.42 + float(wisp) * 0.055) + float(wisp) * 0.21, 1.0)
		var wisp_angle := start_angle + _arc_span * travel
		var wisp_position := center + Vector2.from_angle(wisp_angle) * _curve_radius * scale_factor
		var tangent := Vector2.from_angle(wisp_angle + PI * 0.5)
		canvas.draw_line(
			wisp_position - tangent * 10.0 * scale_factor,
			wisp_position + tangent * 14.0 * scale_factor,
			Color(0.92, 1.0, 1.0, alpha * 0.56),
			maxf(1.0, 1.7 * scale_factor),
			true
		)
	for pulse in _absorption_pulses:
		var pulse_progress := 1.0 - float(pulse["remaining"]) / PULSE_DURATION
		var pulse_color: Color = pulse["color"]
		var pulse_position := screen_position(context, pulse["pos"])
		var pulse_radius := (5.0 + pulse_progress * 22.0) * scale_factor
		canvas.draw_arc(
			pulse_position,
			pulse_radius,
			context.elapsed * 7.0,
			context.elapsed * 7.0 + PI * 1.55,
			20,
			Color(pulse_color.r, pulse_color.g, pulse_color.b, (1.0 - pulse_progress) * 0.82),
			maxf(1.0, 2.4 * scale_factor),
			true
		)

func is_absorbable() -> bool:
	return true

func absorption_radius() -> float:
	return _half_thickness

func absorption_visual_color() -> Color:
	return ownership_visual_color(_color)

func _curve_center() -> Vector2:
	return pos - _direction * _curve_radius

func _interception_fraction(start: Vector2, finish: Vector2, projectile_radius: float) -> float:
	var center := _curve_center()
	var start_angle := _direction.angle() - _arc_span * 0.5
	var segment_length_target := maxf(4.0, _half_thickness * 1.25)
	var segment_count := clampi(
		ceili(_curve_radius * _arc_span / segment_length_target),
		MIN_ARC_SEGMENTS,
		MAX_ARC_SEGMENTS
	)
	var combined_radius := _half_thickness + maxf(0.0, projectile_radius)
	var earliest_fraction := 2.0
	for index in range(segment_count):
		var first_angle := start_angle + _arc_span * float(index) / float(segment_count)
		var second_angle := start_angle + _arc_span * float(index + 1) / float(segment_count)
		var first := center + Vector2.from_angle(first_angle) * _curve_radius
		var second := center + Vector2.from_angle(second_angle) * _curve_radius
		var proximity := _segment_proximity(start, finish, first, second)
		if float(proximity["distance_squared"]) > combined_radius * combined_radius:
			continue
		earliest_fraction = minf(earliest_fraction, float(proximity["fraction"]))
	return earliest_fraction if earliest_fraction <= 1.0 else -1.0

func _segment_proximity(
	first_start: Vector2,
	first_end: Vector2,
	second_start: Vector2,
	second_end: Vector2
) -> Dictionary:
	var first_direction := first_end - first_start
	var second_direction := second_end - second_start
	var offset := first_start - second_start
	var first_length_squared := first_direction.length_squared()
	var second_length_squared := second_direction.length_squared()
	var first_fraction := 0.0
	var second_fraction := 0.0
	if first_length_squared <= 0.0001 and second_length_squared <= 0.0001:
		return {"fraction": 0.0, "distance_squared": first_start.distance_squared_to(second_start)}
	if first_length_squared <= 0.0001:
		second_fraction = clampf(second_direction.dot(offset) / second_length_squared, 0.0, 1.0)
	elif second_length_squared <= 0.0001:
		first_fraction = clampf(-first_direction.dot(offset) / first_length_squared, 0.0, 1.0)
	else:
		var cross_dot := first_direction.dot(second_direction)
		var first_offset_dot := first_direction.dot(offset)
		var second_offset_dot := second_direction.dot(offset)
		var denominator := first_length_squared * second_length_squared - cross_dot * cross_dot
		if absf(denominator) > 0.0001:
			first_fraction = clampf(
				(cross_dot * second_offset_dot - first_offset_dot * second_length_squared) / denominator,
				0.0,
				1.0
			)
		second_fraction = (cross_dot * first_fraction + second_offset_dot) / second_length_squared
		if second_fraction < 0.0:
			second_fraction = 0.0
			first_fraction = clampf(-first_offset_dot / first_length_squared, 0.0, 1.0)
		elif second_fraction > 1.0:
			second_fraction = 1.0
			first_fraction = clampf((cross_dot - first_offset_dot) / first_length_squared, 0.0, 1.0)
	var first_point := first_start + first_direction * first_fraction
	var second_point := second_start + second_direction * second_fraction
	return {
		"fraction": first_fraction,
		"distance_squared": first_point.distance_squared_to(second_point),
	}

func _update_pulses(delta: float) -> void:
	for index in range(_absorption_pulses.size() - 1, -1, -1):
		_absorption_pulses[index]["remaining"] = maxf(
			0.0,
			float(_absorption_pulses[index]["remaining"]) - delta
		)
		if float(_absorption_pulses[index]["remaining"]) <= 0.0:
			_absorption_pulses.remove_at(index)
