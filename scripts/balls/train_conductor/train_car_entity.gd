extends BallEntity

func combat_category() -> Dictionary:
	return {"id": "train_engine" if _is_engine else "train_car", "name": "火车头" if _is_engine else "车厢"}

const EPSILON := 0.0001
const ENGINE_IRON := Color("1b2021")
const ENGINE_RED := Color("c73727")
const CARRIAGE_WOOD := Color("b85d32")
const ROOF_DARK := Color("35251f")
const WINDOW_BLUE := Color("9ee9ff")

var _route := PackedVector2Array()
var _cumulative_lengths := PackedFloat32Array()
var _route_length := 0.0
var _travel_distance := 0.0
var _speed := 360.0
var _damage := 12.0
var _contact_interval := 0.45
var _absorption_radius := 14.0
var _body_color := Color("173b56")
var _accent_color := Color("f0b84a")
var _heading := Vector2.RIGHT
var _is_engine := false
var _has_entered_route := false
var _age := 0.0
var _battle_elapsed := 0.0
var _convoy_contact_state: Dictionary = {}

func _init(
	spawn_owner_side: int,
	route_points: PackedVector2Array,
	start_distance: float,
	engine_unit: bool,
	body_color: Color,
	accent_color: Color,
	config: Dictionary
) -> void:
	owner_side = spawn_owner_side
	_route = route_points.duplicate()
	_travel_distance = start_distance
	_is_engine = engine_unit
	_body_color = body_color
	_accent_color = accent_color
	_speed = maxf(1.0, float(config["speed"]))
	radius = maxf(1.0, float(config["radius"]))
	_damage = maxf(0.0, float(config["damage"]))
	_contact_interval = maxf(0.01, float(config["contact_interval"]))
	_absorption_radius = maxf(1.0, float(config["absorption_radius"]))
	_convoy_contact_state = config["convoy_contact_state"] as Dictionary
	remaining = -1.0
	tags = PackedStringArray(["train_convoy", "train_engine" if _is_engine else "train_car"])
	draw_layer = 0
	_build_route_cache()
	_update_route_position()

func step(battle, delta: float) -> void:
	_age += delta
	_battle_elapsed = battle.elapsed
	_travel_distance += _speed * delta
	_has_entered_route = _has_entered_route or _travel_distance >= 0.0
	_update_route_position()
	if _travel_distance > _route_length + radius * 2.4:
		removed = true
		return
	if _has_entered_route:
		_resolve_entity_contacts(battle)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if not _has_entered_route or removed:
		return
	var center := screen_position(context)
	var scale_factor := context.scale_factor
	var forward := _heading
	if forward.length_squared() <= EPSILON:
		forward = Vector2.RIGHT
	var side := forward.orthogonal()
	var body_color := ownership_visual_color(_body_color)
	var accent := ownership_visual_color(_accent_color)
	var alpha := 0.58 if is_captured() else 1.0
	body_color.a *= alpha
	accent.a *= alpha
	if _is_engine:
		_draw_engine(canvas, center, forward, side, scale_factor, body_color, accent, alpha)
	else:
		_draw_carriage(canvas, center, forward, side, scale_factor, body_color, accent, alpha)

func team_marker_world_height() -> float:
	return radius * 1.9 if _has_entered_route else 0.0

func participates_in_fighter_collision() -> bool:
	return _has_entered_route and not removed and not is_captured()

func fighter_collision_inverse_mass() -> float:
	return 0.001

func can_resolve_fighter_contact(fighter_side: int) -> bool:
	return (
		participates_in_fighter_collision()
		and fighter_side >= 0
		and fighter_side != owner_side
		and _battle_elapsed + EPSILON >= float(_fighter_next_hits().get(fighter_side, 0.0))
	)

func begin_fighter_contact(fighter_side: int) -> void:
	_fighter_next_hits()[fighter_side] = _battle_elapsed + _contact_interval

func participates_in_entity_collision() -> bool:
	return participates_in_fighter_collision()

func entity_collision_inverse_mass() -> float:
	return 0.001

func entity_contact_damage() -> float:
	return _damage

func entity_contact_color() -> Color:
	return ownership_visual_color(_accent_color)

func can_resolve_entity_contact(other: BallEntity) -> bool:
	return (
		participates_in_entity_collision()
		and other != null
		and other.owner_side >= 0
		and other.owner_side != owner_side
		and _battle_elapsed + EPSILON >= float(_entity_next_hits().get(other.get_instance_id(), 0.0))
	)

func begin_entity_contact(other: BallEntity) -> void:
	if other != null:
		_entity_next_hits()[other.get_instance_id()] = _battle_elapsed + _contact_interval

func can_receive_attack(_source_side: int) -> bool:
	return false

func is_absorbable() -> bool:
	return true

func can_be_captured() -> bool:
	return _has_entered_route and super.can_be_captured()

func can_transfer_ownership() -> bool:
	return _has_entered_route and super.can_transfer_ownership()

func absorption_radius() -> float:
	return _absorption_radius

func absorption_visual_color() -> Color:
	return ownership_visual_color(_body_color)

func on_ownership_transferred(
	_previous_owner_side: int,
	_new_owner_side: int,
	_new_owner_anchor
) -> void:
	# A single controlled carriage leaves its former convoy's shared hit ledger.
	_convoy_contact_state = {
		"fighter_next_hit": {},
		"entity_next_hit": {},
	}

func is_engine() -> bool:
	return _is_engine

func travel_distance() -> float:
	return _travel_distance

func route_length() -> float:
	return _route_length

func heading() -> Vector2:
	return _heading

func _build_route_cache() -> void:
	_cumulative_lengths.clear()
	_cumulative_lengths.append(0.0)
	_route_length = 0.0
	for index in range(1, _route.size()):
		_route_length += _route[index - 1].distance_to(_route[index])
		_cumulative_lengths.append(_route_length)
	if _route.size() >= 2:
		_heading = (_route[1] - _route[0]).normalized()

func _update_route_position() -> void:
	if _route.is_empty():
		removed = true
		return
	if _route.size() == 1:
		pos = _route[0]
		return
	if _travel_distance <= 0.0:
		_heading = (_route[1] - _route[0]).normalized()
		pos = _route[0] + _heading * _travel_distance
		velocity = _heading * _speed
		return
	if _travel_distance >= _route_length:
		_heading = (_route[_route.size() - 1] - _route[_route.size() - 2]).normalized()
		pos = _route[_route.size() - 1] + _heading * (_travel_distance - _route_length)
		velocity = _heading * _speed
		return
	for index in range(1, _route.size()):
		if _travel_distance > _cumulative_lengths[index]:
			continue
		var segment_start_length := _cumulative_lengths[index - 1]
		var segment_length := maxf(EPSILON, _cumulative_lengths[index] - segment_start_length)
		var progress := (_travel_distance - segment_start_length) / segment_length
		_heading = (_route[index] - _route[index - 1]).normalized()
		pos = _route[index - 1].lerp(_route[index], progress)
		velocity = _heading * _speed
		return

func _resolve_entity_contacts(battle) -> void:
	for other: BallEntity in battle.entities():
		if (
			other == self
			or other.removed
			or other.is_captured()
			or other.owner_side == owner_side
			or not other.participates_in_entity_collision()
		):
			continue
		if other.has_tag("train_convoy") and get_instance_id() > other.get_instance_id():
			continue
		_resolve_entity_collision(battle, other)

func _resolve_entity_collision(battle, other: BallEntity) -> void:
	var offset: Vector2 = other.pos - pos
	var minimum_distance := radius + other.radius
	var distance := offset.length()
	if distance >= minimum_distance:
		return
	var normal := offset / distance if distance > EPSILON else _heading.orthogonal()
	if normal.length_squared() <= EPSILON:
		normal = Vector2.RIGHT
	var overlap := minimum_distance - maxf(distance, EPSILON)
	var own_inverse_mass := maxf(0.0, entity_collision_inverse_mass())
	var other_inverse_mass := maxf(0.0, other.entity_collision_inverse_mass())
	var total_inverse_mass := own_inverse_mass + other_inverse_mass
	if total_inverse_mass > 0.0:
		pos -= normal * overlap * own_inverse_mass / total_inverse_mass
		other.pos += normal * overlap * other_inverse_mass / total_inverse_mass
	var relative_speed: float = (other.velocity - velocity).dot(normal)
	if relative_speed < 0.0 and total_inverse_mass > 0.0:
		var impulse := -2.0 * relative_speed / total_inverse_mass
		other.velocity += normal * impulse * other_inverse_mass
	if not can_resolve_entity_contact(other) or not other.can_resolve_entity_contact(self):
		return
	begin_entity_contact(other)
	other.begin_entity_contact(self)
	var applied_to_other: float = battle.damage_entity(
		other,
		_damage,
		entity_contact_color(),
		owner_side, true, self
	)
	if applied_to_other <= 0.0:
		return
	battle.record_stat("train_entity_contacts")
	battle.spawn_ring(pos + normal * radius, entity_contact_color(), 4.0, 38.0, 0.22)
	battle.spawn_particles(pos + normal * radius, entity_contact_color(), 6, 112.0)
	battle.emit_combat_event("body_impact", 0.62)

func _fighter_next_hits() -> Dictionary:
	return _convoy_contact_state["fighter_next_hit"] as Dictionary

func _entity_next_hits() -> Dictionary:
	return _convoy_contact_state["entity_next_hit"] as Dictionary

func _draw_engine(
	canvas: CanvasItem,
	center: Vector2,
	forward: Vector2,
	side: Vector2,
	scale_factor: float,
	_unused_body_color: Color,
	accent: Color,
	alpha: float
) -> void:
	var draw_radius := radius * scale_factor
	var iron := ownership_visual_color(ENGINE_IRON)
	var red := ownership_visual_color(ENGINE_RED)
	var brass := ownership_visual_color(Color("f2b83f"))
	iron.a *= alpha
	red.a *= alpha
	brass.a *= alpha
	# A broad shadow and cowcatcher make the engine read as a locomotive before
	# viewers have time to inspect its smaller boiler details.
	canvas.draw_colored_polygon(
		_box_points(center + side * draw_radius * 0.16, forward, side, draw_radius * 1.62, draw_radius * 0.94),
		Color(0.0, 0.0, 0.0, 0.34 * alpha)
	)
	var cowcatcher_tip := center + forward * draw_radius * 2.02
	var cowcatcher_base := center + forward * draw_radius * 1.32
	canvas.draw_colored_polygon(PackedVector2Array([
		cowcatcher_tip,
		cowcatcher_base + side * draw_radius * 0.86,
		cowcatcher_base - side * draw_radius * 0.86,
	]), Color(0.06, 0.075, 0.075, 0.98 * alpha))
	for rail_index in [-2, -1, 0, 1, 2]:
		var lateral := float(rail_index) * draw_radius * 0.34
		canvas.draw_line(
			cowcatcher_tip,
			cowcatcher_base + side * lateral,
			brass,
			maxf(1.0, draw_radius * 0.055),
			true
		)
	canvas.draw_colored_polygon(
		_box_points(center, forward, side, draw_radius * 1.55, draw_radius * 0.86),
		brass
	)
	canvas.draw_colored_polygon(
		_box_points(center, forward, side, draw_radius * 1.47, draw_radius * 0.77),
		red
	)
	canvas.draw_colored_polygon(
		_box_points(center - forward * draw_radius * 0.78, forward, side, draw_radius * 0.55, draw_radius * 0.78),
		brass
	)
	canvas.draw_colored_polygon(
		_box_points(center - forward * draw_radius * 0.78, forward, side, draw_radius * 0.47, draw_radius * 0.66),
		Color(red.r * 0.76, red.g * 0.76, red.b * 0.76, 0.98 * alpha)
	)
	var boiler_center := center + forward * draw_radius * 0.38
	canvas.draw_colored_polygon(
		_box_points(boiler_center, forward, side, draw_radius * 0.88, draw_radius * 0.57),
		iron
	)
	var boiler_face := center + forward * draw_radius * 1.28
	canvas.draw_circle(boiler_face, draw_radius * 0.58, Color(0.07, 0.075, 0.075, 0.99 * alpha))
	canvas.draw_circle(boiler_face, draw_radius * 0.58, brass, false, maxf(1.4, draw_radius * 0.105), true)
	for band_offset in [-0.28, 0.24, 0.70]:
		var band_center: Vector2 = center + forward * draw_radius * band_offset
		canvas.draw_line(
			band_center - side * draw_radius * 0.57,
			band_center + side * draw_radius * 0.57,
			brass,
			maxf(1.0, draw_radius * 0.075),
			true
		)
	canvas.draw_line(
		center - forward * draw_radius * 1.18 + side * draw_radius * 0.70,
		center - forward * draw_radius * 0.38 + side * draw_radius * 0.70,
		accent,
		maxf(1.1, draw_radius * 0.075),
		true
	)
	var stack_center := center + forward * draw_radius * 0.72 - side * draw_radius * 0.02
	canvas.draw_circle(stack_center, draw_radius * 0.28, Color(0.025, 0.03, 0.03, 0.98 * alpha))
	canvas.draw_circle(stack_center, draw_radius * 0.28, brass, false, maxf(1.0, draw_radius * 0.075), true)
	var headlight_center := boiler_face + forward * draw_radius * 0.16
	canvas.draw_circle(headlight_center, draw_radius * 0.34, Color(brass.r, brass.g, brass.b, 0.18 * alpha))
	canvas.draw_circle(headlight_center, draw_radius * 0.18, Color(1.0, 0.86, 0.33, 0.98 * alpha))
	_draw_wheels(canvas, center, forward, side, draw_radius, brass, alpha)
	_draw_coupler(canvas, center - forward * draw_radius * 1.55, -forward, draw_radius, brass, alpha)
	var smoke_phase := fposmod(_age * 1.8, 1.0)
	for puff_index in range(3):
		var puff_progress := fposmod(smoke_phase + float(puff_index) / 3.0, 1.0)
		var puff_center := stack_center - forward * draw_radius * (0.12 + puff_progress * 1.12) - side * draw_radius * sin(_age * 3.0 + float(puff_index)) * 0.18
		canvas.draw_circle(puff_center, draw_radius * (0.14 + puff_progress * 0.22), Color(0.78, 0.82, 0.81, (1.0 - puff_progress) * 0.48 * alpha))

func _draw_carriage(
	canvas: CanvasItem,
	center: Vector2,
	forward: Vector2,
	side: Vector2,
	scale_factor: float,
	_unused_body_color: Color,
	accent: Color,
	alpha: float
) -> void:
	var draw_radius := radius * scale_factor
	var wood := ownership_visual_color(CARRIAGE_WOOD)
	var roof := ownership_visual_color(ROOF_DARK)
	var trim := ownership_visual_color(Color("e3aa3d"))
	wood.a *= alpha
	roof.a *= alpha
	trim.a *= alpha
	canvas.draw_colored_polygon(
		_box_points(center + side * draw_radius * 0.16, forward, side, draw_radius * 1.34, draw_radius * 0.92),
		Color(0.0, 0.0, 0.0, 0.32 * alpha)
	)
	canvas.draw_colored_polygon(
		_box_points(center, forward, side, draw_radius * 1.31, draw_radius * 0.86),
		trim
	)
	canvas.draw_colored_polygon(
		_box_points(center, forward, side, draw_radius * 1.23, draw_radius * 0.77),
		wood
	)
	canvas.draw_colored_polygon(
		_box_points(center, forward, side, draw_radius * 1.10, draw_radius * 0.57),
		roof
	)
	for window_index in [-1, 1]:
		var window_center := center + forward * draw_radius * float(window_index) * 0.55
		canvas.draw_colored_polygon(
			_box_points(window_center, forward, side, draw_radius * 0.22, draw_radius * 0.32),
			Color(0.07, 0.08, 0.075, 0.98 * alpha)
		)
		canvas.draw_colored_polygon(
			_box_points(window_center, forward, side, draw_radius * 0.15, draw_radius * 0.24),
			Color(WINDOW_BLUE.r, WINDOW_BLUE.g, WINDOW_BLUE.b, 0.72 * alpha)
		)
	canvas.draw_line(center - side * draw_radius * 0.78, center + side * draw_radius * 0.78, trim, maxf(1.2, draw_radius * 0.09), true)
	canvas.draw_line(center - forward * draw_radius * 1.06, center + forward * draw_radius * 1.06, Color(trim.r, trim.g, trim.b, 0.72 * alpha), maxf(1.0, draw_radius * 0.055), true)
	canvas.draw_line(
		center - forward * draw_radius * 1.13 - side * draw_radius * 0.69,
		center + forward * draw_radius * 1.13 - side * draw_radius * 0.69,
		accent,
		maxf(1.0, draw_radius * 0.065),
		true
	)
	_draw_wheels(canvas, center, forward, side, draw_radius, trim, alpha)
	_draw_coupler(canvas, center + forward * draw_radius * 1.30, forward, draw_radius, trim, alpha)
	_draw_coupler(canvas, center - forward * draw_radius * 1.30, -forward, draw_radius, trim, alpha)

func _draw_wheels(
	canvas: CanvasItem,
	center: Vector2,
	forward: Vector2,
	side: Vector2,
	draw_radius: float,
	_unused_accent: Color,
	alpha: float
) -> void:
	for longitudinal in [-0.65, 0.65]:
		for lateral in [-0.78, 0.78]:
			var wheel_center: Vector2 = center + forward * draw_radius * float(longitudinal) + side * draw_radius * float(lateral)
			canvas.draw_circle(wheel_center, draw_radius * 0.25, Color(0.018, 0.024, 0.025, 0.99 * alpha))
			canvas.draw_circle(wheel_center, draw_radius * 0.13, Color(0.31, 0.36, 0.37, 0.92 * alpha))
			var spoke := forward.rotated(_age * _speed / maxf(radius, 1.0)) * draw_radius * 0.11
			canvas.draw_line(wheel_center - spoke, wheel_center + spoke, Color(0.04, 0.05, 0.05, 0.9 * alpha), maxf(0.8, draw_radius * 0.045), true)

func _draw_coupler(
	canvas: CanvasItem,
	anchor: Vector2,
	direction: Vector2,
	draw_radius: float,
	accent: Color,
	alpha: float
) -> void:
	var finish := anchor + direction * draw_radius * 0.34
	canvas.draw_line(anchor, finish, Color(0.035, 0.045, 0.045, 0.98 * alpha), maxf(2.0, draw_radius * 0.12), true)
	canvas.draw_circle(finish, draw_radius * 0.11, Color(accent.r, accent.g, accent.b, 0.9 * alpha))

func _box_points(
	center: Vector2,
	forward: Vector2,
	side: Vector2,
	half_length: float,
	half_width: float
) -> PackedVector2Array:
	return PackedVector2Array([
		center + forward * half_length + side * half_width,
		center + forward * half_length - side * half_width,
		center - forward * half_length - side * half_width,
		center - forward * half_length + side * half_width,
	])
