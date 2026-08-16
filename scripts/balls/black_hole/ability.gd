extends BallAbility

const VortexTetherEffect := preload("res://scripts/balls/black_hole/vortex_tether_effect.gd")
const VortexFieldEntity := preload("res://scripts/balls/black_hole/vortex_field_entity.gd")
const AbsorptionEffectEntity := preload("res://scripts/balls/black_hole/absorption_effect_entity.gd")

const ACTIVE_DURATION := 2.35
const VORTEX_RADIUS := 190.0
const MAX_ORBIT_ENTRY_RADIUS := 285.0
const CAPTURE_RADIUS := 410.0
const CONSUME_RADIUS := 72.0
const MAX_TETHER_SPEED := 465.0
const CAPTURE_MIN_AGE := 0.22

var _active_remaining := 0.0
var _orbit_entry_radius := 150.0
var _captured_entities: Array[Dictionary] = []

func before_motion(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_active_remaining = maxf(0.0, _active_remaining - delta)

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return 0.62 if _active_remaining > 0.0 else 1.0

func is_active() -> bool:
	return _active_remaining > 0.0

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	if _active_remaining > 0.0:
		_steer_opponent_on_orbit(battle, fighter, opponent, side, delta)
		_capture_hostile_entities(battle, fighter, side)
	_update_captured_entities(battle, fighter, side, delta)

func _steer_opponent_on_orbit(battle, fighter, opponent, side: int, delta: float) -> void:
	var offset: Vector2 = opponent.pos - fighter.pos
	var distance: float = maxf(1.0, offset.length())
	var outward := offset / distance
	var orbit_sign := 1.0 if side == 0 else -1.0
	var tangent := Vector2(-outward.y, outward.x) * orbit_sign
	var orbit_progress := clampf(1.0 - _active_remaining / ACTIVE_DURATION, 0.0, 1.0)
	var eased_progress := orbit_progress * orbit_progress * (3.0 - 2.0 * orbit_progress)
	var final_orbit_radius: float = float(fighter.radius) + float(opponent.radius) + 42.0
	var desired_radius := lerpf(_orbit_entry_radius, final_orbit_radius, eased_progress)
	var radial_error := distance - desired_radius
	var desired_inward_speed := clampf(radial_error * 2.9, -72.0, 205.0)
	var desired_tangent_speed: float = 256.0 + clampf(radial_error * 0.12, -18.0, 28.0)
	var desired_velocity: Vector2 = tangent * desired_tangent_speed - outward * desired_inward_speed
	var steering_response := lerpf(1.55, 4.4, eased_progress)
	var steering_weight := 1.0 - exp(-steering_response * delta)
	opponent.velocity = opponent.velocity.lerp(desired_velocity, steering_weight)
	var centripetal_acceleration: float = desired_tangent_speed * desired_tangent_speed / maxf(distance, 72.0)
	opponent.velocity += -outward * centripetal_acceleration * delta * 0.18
	opponent.velocity = opponent.velocity.limit_length(MAX_TETHER_SPEED + 56.0)

func activate(battle, fighter, opponent, side: int) -> void:
	_active_remaining = ACTIVE_DURATION
	_orbit_entry_radius = clampf(fighter.pos.distance_to(opponent.pos), fighter.radius + opponent.radius + 42.0, MAX_ORBIT_ENTRY_RADIUS)
	battle.apply_status(opponent, VortexTetherEffect.new(ACTIVE_DURATION, side, fighter.accent))
	battle.add_entity(VortexFieldEntity.new(
		side,
		fighter,
		opponent,
		ACTIVE_DURATION,
		CAPTURE_RADIUS,
		VORTEX_RADIUS,
		fighter.accent
	))
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 260.0, 0.72)
	battle.spawn_particles(fighter.pos, fighter.accent, 10, 125.0)
	battle.shake_camera(4.5)

func _capture_hostile_entities(battle, fighter, side: int) -> int:
	var captured := 0
	for entity: BallEntity in battle.entities():
		if not entity.is_hostile_to(side) or not entity.can_be_captured():
			continue
		var entity_position := entity.attraction_position()
		var entity_radius := entity.absorption_radius()
		var distance := entity_position.distance_to(fighter.pos)
		if distance > CAPTURE_RADIUS + entity_radius:
			continue
		if not entity.disable_for_capture():
			continue
		_captured_entities.append({
			"entity": weakref(entity),
			"radius": distance,
			"angle": (entity_position - fighter.pos).angle(),
			"age": 0.0,
		})
		battle.spawn_ring(entity_position, fighter.accent, maxf(4.0, entity_radius), 38.0, 0.24)
		battle.add_beam(entity_position, fighter.pos, fighter.accent, 0.16, 1.6)
		captured += 1
	if captured > 0:
		battle.record_stat("objects_captured", captured)
	return captured

func _update_captured_entities(battle, fighter, side: int, delta: float) -> void:
	var swirl_sign := 1.0 if side == 0 else -1.0
	for index in range(_captured_entities.size() - 1, -1, -1):
		var state: Dictionary = _captured_entities[index]
		var entity_ref: WeakRef = state["entity"]
		var entity = entity_ref.get_ref()
		if entity == null or entity.removed:
			_captured_entities.remove_at(index)
			continue
		var age := float(state["age"]) + delta
		var orbit_radius := float(state["radius"])
		var capture_progress := 1.0 - clampf(orbit_radius / CAPTURE_RADIUS, 0.0, 1.0)
		var shrink_speed := lerpf(82.0, 138.0, capture_progress)
		orbit_radius = maxf(0.0, orbit_radius - shrink_speed * delta)
		var angular_speed := lerpf(1.35, 4.8, capture_progress)
		var angle := float(state["angle"]) + swirl_sign * angular_speed * delta
		var outward := Vector2.from_angle(angle)
		var tangent := Vector2(-outward.y, outward.x) * swirl_sign
		entity.pos = fighter.pos + outward * orbit_radius
		entity.velocity = tangent * angular_speed * orbit_radius - outward * shrink_speed
		state["age"] = age
		state["radius"] = orbit_radius
		state["angle"] = angle
		_captured_entities[index] = state
		var entity_radius: float = entity.absorption_radius()
		if age < CAPTURE_MIN_AGE or orbit_radius > CONSUME_RADIUS + entity_radius:
			continue
		if _absorb_entity(battle, fighter, side, entity, swirl_sign, 0.3):
			battle.record_stat("objects_absorbed")
			_captured_entities.remove_at(index)

func _absorb_entity(battle, fighter, side: int, entity: BallEntity, swirl_sign: float, duration: float) -> bool:
	var entity_position := entity.attraction_position()
	var entity_radius := entity.absorption_radius()
	var entity_color := entity.absorption_visual_color()
	if not entity.absorb(battle, side, fighter.pos):
		return false
	battle.add_entity(AbsorptionEffectEntity.new(
		side,
		fighter,
		entity_position,
		maxf(entity_radius, entity.radius),
		duration,
		entity_color,
		swirl_sign
	))
	return true
