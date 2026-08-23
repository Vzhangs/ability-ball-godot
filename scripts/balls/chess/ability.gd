extends BallAbility

const CannonballEntity := preload("res://scripts/balls/chess/cannonball_entity.gd")
const CannonMuzzleEntity := preload("res://scripts/balls/chess/cannon_muzzle_entity.gd")
const GuardEntity := preload("res://scripts/balls/chess/guard_entity.gd")
const CastIconEntity := preload("res://scripts/balls/chess/cast_icon_entity.gd")
const ElephantStatus := preload("res://scripts/balls/chess/elephant_status.gd")
const MarshalRegenerationStatus := preload("res://scripts/balls/chess/marshal_regeneration_status.gd")
const RookCarryStatus := preload("res://scripts/balls/chess/rook_carry_status.gd")

const EPSILON := 0.0001
const MOVEMENT_PRIORITY := BallStatusEffect.MOVEMENT_CONTROL_PRIORITY_ABILITY
const SKILL_KEYS := ["rook", "cannon", "elephant", "marshal", "guard"]
const WEIGHT_KEYS := [
	"rook_weight",
	"cannon_weight",
	"elephant_weight",
	"marshal_weight",
	"guard_weight",
]
const SKILL_SYMBOLS := {
	"rook": "車",
	"cannon": "炮",
	"elephant": "象",
	"marshal": "帅",
	"guard": "士",
}

var _last_skill := ""

var _rook_active := false
var _rook_phase := ""
var _rook_windup_remaining := 0.0
var _rook_target_snapshot := Vector2.ZERO
var _rook_direction := Vector2.RIGHT
var _rook_remaining_distance := 0.0
var _rook_elapsed := 0.0
var _rook_previous_position := Vector2.ZERO
var _rook_crushed_entity_ids := {}
var _rook_carried_target = null
var _rook_carry_status: BallStatusEffect = null

var _cannon_shots_remaining := 0
var _cannon_shot_timer := 0.0

var _guard_orbit_angle := 0.0

var _elephant_active := false
var _elephant_phase := ""
var _elephant_position := Vector2.ZERO
var _elephant_direction := Vector2.ZERO
var _elephant_vertices: Array[Vector2] = []
var _elephant_target_index := 0
var _elephant_laps_completed := 0

func on_battle_started(_battle, fighter, _opponent, _side: int) -> void:
	_last_skill = ""
	_rook_active = false
	_rook_phase = ""
	_rook_windup_remaining = 0.0
	_rook_remaining_distance = 0.0
	_rook_elapsed = 0.0
	_rook_previous_position = fighter.pos
	_rook_crushed_entity_ids.clear()
	_rook_carried_target = null
	_rook_carry_status = null
	_cannon_shots_remaining = 0
	_cannon_shot_timer = 0.0
	_guard_orbit_angle = 0.0
	_elephant_active = false
	_elephant_phase = ""
	_elephant_position = fighter.pos
	_elephant_direction = Vector2.ZERO
	_elephant_vertices.clear()
	_elephant_target_index = 0
	_elephant_laps_completed = 0
	# The first chess order waits the full configurable interval.
	fighter.ability_timer = fighter.cooldown

func automatic_activation_enabled() -> bool:
	# A short custom interval may expire mid-dash or mid-diamond. Finish the prescribed
	# movement first, then let the already-expired timer trigger the next order immediately.
	return not _rook_active and not _elephant_active and _cannon_shots_remaining <= 0

func before_motion(battle, fighter, _opponent, side: int, delta: float) -> void:
	var orbit_direction := 1.0 if side == 0 else -1.0
	_guard_orbit_angle = fmod(
		_guard_orbit_angle + delta * settingf("guard_orbit_speed") * orbit_direction,
		TAU
	)
	if _elephant_active:
		fighter.velocity = _elephant_direction * _elephant_current_speed()
		return
	if not _rook_active:
		return
	if battle.movement_control_priority(fighter) > MOVEMENT_PRIORITY:
		_end_rook(battle, fighter, false)
		return
	_rook_previous_position = fighter.pos
	if _rook_phase == "windup":
		fighter.velocity = Vector2.ZERO
		return
	fighter.velocity = _rook_direction * settingf("rook_dash_speed")

func speed_multiplier(battle, fighter, _opponent, _side: int) -> float:
	var base_speed := maxf(1.0, float(fighter.base_speed))
	if _elephant_active:
		return _elephant_current_speed() / base_speed
	if _rook_active:
		if _rook_phase == "windup":
			return 1.0 if battle.movement_control_priority(fighter) > MOVEMENT_PRIORITY else 0.0
		return settingf("rook_dash_speed") / base_speed
	return 1.0

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	_advance_cannon_volley(battle, fighter, opponent, side, delta)
	if _rook_active:
		if _rook_phase == "windup":
			_update_rook_aim(fighter, opponent)
			_rook_windup_remaining = maxf(0.0, _rook_windup_remaining - delta)
			if _rook_windup_remaining <= EPSILON:
				_begin_rook_dash(battle, fighter)
		elif _rook_phase == "dash":
			_rook_elapsed += delta
			_rook_remaining_distance -= settingf("rook_dash_speed") * delta
		elif _rook_phase == "carry" and (
			_rook_carried_target == null
			or _rook_carried_target.hp <= 0.0
			or _rook_carry_status == null
			or _rook_carry_status.is_expired()
		):
			_end_rook(battle, fighter, true)
	if _elephant_active:
		_advance_elephant(battle, fighter, delta)
	_sync_guards(battle, fighter, side)

func after_entities_step(battle, fighter, opponent, side: int, _delta: float) -> void:
	if _rook_active and _rook_phase == "dash":
		_resolve_rook_lane(battle, fighter, opponent, side)
		if _rook_active and _rook_phase == "dash" and (
			_rook_remaining_distance <= 0.0
			or _rook_elapsed >= settingf("rook_max_duration")
		):
			_end_rook(battle, fighter, true)
	elif _rook_active and _rook_phase == "carry":
		_sync_rook_carry(battle, fighter)
	if _elephant_active:
		# Collision, wall and foreign entity responses may not bend the prescribed diamond path.
		fighter.pos = _elephant_position
		fighter.velocity = _elephant_direction * _elephant_current_speed()
	_sync_guards(battle, fighter, side)

func activate(battle, fighter, opponent, side: int) -> void:
	if fighter.hp <= 0.0 or opponent == null or opponent.hp <= 0.0:
		return
	_finish_active_movement(battle, fighter)
	_cancel_cannon_volley()
	_last_skill = _roll_skill(battle)
	_spawn_cast_icon(battle, fighter, side, SKILL_SYMBOLS[_last_skill])
	match _last_skill:
		"rook":
			_activate_rook(battle, fighter, opponent)
		"cannon":
			_activate_cannon(battle, fighter, opponent, side)
		"elephant":
			_activate_elephant(battle, fighter, side)
		"marshal":
			_activate_marshal(battle, fighter, side)
		"guard":
			_activate_guard(battle, fighter, side)
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.82, fighter.radius * 2.65, 0.42)
	battle.spawn_particles(fighter.pos, fighter.accent, 10, 118.0)

func contact_damage(_battle, _fighter, target) -> float:
	if _rook_active and _rook_phase == "dash":
		return settingf("rook_entity_damage") if target is BallEntity else settingf("rook_damage")
	if _elephant_active:
		return settingf("elephant_damage")
	return 0.0

func after_contact(battle, fighter, opponent, damage_dealt: float) -> void:
	if _rook_active and _rook_phase == "dash" and damage_dealt > 0.0:
		battle.record_stat("chess_rook_hits")
		battle.emit_combat_event("ram_impact", 0.78)
		_start_rook_carry(battle, fighter, opponent, battle.side_for_fighter(fighter))
	elif _elephant_active and damage_dealt > 0.0:
		battle.record_stat("chess_elephant_hits")
		battle.emit_combat_event("ram_impact", 0.56)

func after_entity_contact(
	battle,
	_fighter,
	_entity: BallEntity,
	damage_dealt: float
) -> void:
	if _rook_active and _rook_phase == "dash" and damage_dealt > 0.0:
		_rook_crushed_entity_ids[_entity.get_instance_id()] = true
		battle.record_stat("chess_rook_entity_hits")
		battle.emit_combat_event("ram_impact", 0.7)
	elif _elephant_active and damage_dealt > 0.0:
		battle.record_stat("chess_elephant_entity_hits")
		battle.emit_combat_event("ram_impact", 0.5)

func last_skill() -> String:
	return _last_skill

func active_movement_skill() -> String:
	if _elephant_active:
		return "elephant"
	if _rook_active:
		return "rook"
	return ""

func rook_active() -> bool:
	return _rook_active

func rook_phase() -> String:
	return _rook_phase

func rook_windup_remaining() -> float:
	return _rook_windup_remaining

func rook_target_snapshot() -> Vector2:
	return _rook_target_snapshot

func rook_direction() -> Vector2:
	return _rook_direction

func rook_lane_width_multiplier() -> float:
	return settingf("rook_lane_width_multiplier")

func rook_front_length() -> float:
	return settingf("rook_front_length")

func elephant_active() -> bool:
	return _elephant_active

func elephant_phase() -> String:
	return _elephant_phase

func elephant_laps_completed() -> int:
	return _elephant_laps_completed

func elephant_path_position() -> Vector2:
	return _elephant_position

func cannon_shots_remaining() -> int:
	return _cannon_shots_remaining

func guard_orbit_angle() -> float:
	return _guard_orbit_angle

func _activate_rook(battle, fighter, opponent) -> void:
	_update_rook_aim(fighter, opponent)
	_rook_elapsed = 0.0
	_rook_previous_position = fighter.pos
	_rook_crushed_entity_ids.clear()
	_rook_carried_target = null
	_rook_carry_status = null
	_rook_active = true
	_rook_windup_remaining = settingf("rook_windup_duration")
	_rook_phase = "windup" if _rook_windup_remaining > EPSILON else "dash"
	if _rook_phase == "windup":
		if battle.movement_control_priority(fighter) <= MOVEMENT_PRIORITY:
			fighter.velocity = Vector2.ZERO
	else:
		_begin_rook_dash(battle, fighter)
	battle.record_stat("chess_rook_casts")

func _begin_rook_dash(battle, fighter) -> void:
	if not _rook_active:
		return
	if battle.movement_control_priority(fighter) > MOVEMENT_PRIORITY:
		_end_rook(battle, fighter, false)
		return
	var offset: Vector2 = _rook_target_snapshot - fighter.pos
	if offset.length_squared() > EPSILON:
		_rook_direction = offset.normalized()
		_rook_remaining_distance = offset.length()
	_rook_phase = "dash"
	_rook_windup_remaining = 0.0
	_rook_elapsed = 0.0
	fighter.velocity = _rook_direction * settingf("rook_dash_speed")
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.72, fighter.radius * 1.9, 0.22)
	battle.spawn_particles(fighter.pos, fighter.accent, 8, 146.0)
	battle.record_stat("chess_rook_launches")

func _update_rook_aim(fighter, opponent) -> void:
	if opponent != null and opponent.hp > 0.0:
		_rook_target_snapshot = opponent.pos
	var offset: Vector2 = _rook_target_snapshot - fighter.pos
	if offset.length_squared() > EPSILON:
		_rook_direction = offset.normalized()
	else:
		_rook_direction = fighter.velocity.normalized()
	if _rook_direction.length_squared() <= EPSILON:
		_rook_direction = Vector2.RIGHT
	_rook_remaining_distance = offset.length()

func _resolve_rook_lane(battle, fighter, opponent, side: int) -> void:
	var start: Vector2 = _rook_previous_position
	var finish: Vector2 = fighter.pos + _rook_direction * settingf("rook_front_length")
	var half_width: float = fighter.radius * settingf("rook_lane_width_multiplier")
	if (
		opponent != null
		and opponent.hp > 0.0
		and _distance_to_segment(opponent.pos, start, finish) <= opponent.radius + half_width
	):
		var main_damage: float = battle.damage(
			opponent,
			settingf("rook_damage"),
			fighter.accent,
			fighter
		)
		if main_damage > 0.0:
			battle.record_stat("chess_rook_hits")
			battle.emit_combat_event("ram_impact", 0.82)
			_start_rook_carry(battle, fighter, opponent, side)
			return
	for entity: BallEntity in battle.damageable_entities_on_segment(side, start, finish, half_width):
		var entity_id := entity.get_instance_id()
		if _rook_crushed_entity_ids.has(entity_id):
			continue
		var applied: float = battle.damage_entity(
			entity,
			settingf("rook_entity_damage"),
			fighter.accent,
			side
		)
		if applied <= 0.0:
			continue
		_rook_crushed_entity_ids[entity_id] = true
		battle.spawn_ring(entity.pos, fighter.accent, maxf(3.0, entity.radius * 0.45), entity.radius * 2.6, 0.24)
		battle.spawn_particles(entity.pos, fighter.accent, 7, 132.0)
		battle.emit_combat_event("ram_impact", 0.58)
		battle.record_stat("chess_rook_entity_hits")

func _start_rook_carry(battle, fighter, opponent, side: int) -> void:
	if not _rook_active or _rook_phase != "dash" or opponent == null or opponent.hp <= 0.0:
		return
	if battle.movement_control_priority(opponent) >= BallStatusEffect.MOVEMENT_CONTROL_PRIORITY_FORCED:
		_end_rook(battle, fighter, true)
		return
	_rook_phase = "carry"
	_rook_carried_target = opponent
	_rook_carry_status = battle.apply_status(opponent, RookCarryStatus.new(
		settingf("rook_carry_duration"),
		side,
		_rook_direction,
		settingf("rook_dash_speed"),
		settingf("rook_wall_damage"),
		fighter.accent
	))
	fighter.velocity = _rook_direction * settingf("rook_dash_speed")
	opponent.velocity = fighter.velocity
	battle.spawn_ring(opponent.pos, fighter.accent, opponent.radius * 0.7, opponent.radius * 1.9, 0.26)
	battle.spawn_particles(opponent.pos, fighter.accent, 10, 165.0)
	battle.record_stat("chess_rook_carries")
	_sync_rook_carry(battle, fighter)

func _sync_rook_carry(battle, fighter) -> void:
	if (
		_rook_carried_target == null
		or _rook_carry_status == null
		or _rook_carry_status.is_expired()
		or not battle.has_status(_rook_carried_target, RookCarryStatus.STATUS_KEY)
	):
		_end_rook(battle, fighter, true)
		return
	var target = _rook_carried_target
	# Keep a sub-pixel visual gap so the shared body-collision pass does not emit
	# repeated impacts while the ability-owned carry state already controls both balls.
	var contact_distance: float = fighter.radius + target.radius + 0.5
	var desired_position: Vector2 = fighter.pos + _rook_direction * contact_distance
	var arena: Vector2 = battle.arena_size()
	var clamped_position := Vector2(
		clampf(desired_position.x, target.radius, arena.x - target.radius),
		clampf(desired_position.y, target.radius, arena.y - target.radius)
	)
	target.pos = clamped_position
	target.velocity = _rook_direction * settingf("rook_dash_speed")
	if not clamped_position.is_equal_approx(desired_position):
		fighter.pos = clamped_position - _rook_direction * contact_distance
		fighter.pos.x = clampf(fighter.pos.x, fighter.radius, arena.x - fighter.radius)
		fighter.pos.y = clampf(fighter.pos.y, fighter.radius, arena.y - fighter.radius)
		_rook_carry_status.call("resolve_wall_impact", battle, target)
		_end_rook(battle, fighter, true)

func after_wall_hit(
	battle,
	fighter,
	_opponent,
	_side: int,
	_contact_position: Vector2
) -> bool:
	if not _rook_active:
		return false
	if _rook_phase == "carry" and _rook_carried_target != null and _rook_carry_status != null:
		_rook_carry_status.call("resolve_wall_impact", battle, _rook_carried_target)
	else:
		battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.5, fighter.radius * 2.4, 0.3)
		battle.spawn_particles(fighter.pos, fighter.accent, 12, 178.0)
		battle.emit_combat_event("ram_impact", 0.72)
		battle.record_stat("chess_rook_miss_wall_hits")
	_end_rook(battle, fighter, true)
	return true

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= EPSILON:
		return point.distance_to(start)
	var offset := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * offset)

func _activate_cannon(battle, fighter, opponent, side: int) -> void:
	_cannon_shots_remaining = maxi(1, settingi("cannon_shot_count"))
	_cannon_shot_timer = 0.0
	_fire_cannon_shot(battle, fighter, opponent, side)
	_cannon_shots_remaining -= 1
	if _cannon_shots_remaining > 0:
		_cannon_shot_timer = settingf("cannon_shot_interval")
	battle.record_stat("chess_cannon_casts")

func _fire_cannon_shot(battle, fighter, opponent, side: int) -> void:
	var direction: Vector2 = (opponent.pos - fighter.pos).normalized()
	if direction.length_squared() <= EPSILON:
		direction = fighter.velocity.normalized()
	if direction.length_squared() <= EPSILON:
		direction = Vector2.RIGHT if side == 0 else Vector2.LEFT
	var projectile_radius := settingf("cannon_projectile_radius")
	var spawn_position: Vector2 = fighter.pos + direction * (fighter.radius + projectile_radius + 3.0)
	battle.add_entity(CannonballEntity.new(
		side,
		spawn_position,
		direction * settingf("cannon_projectile_speed"),
		projectile_radius,
		settingf("cannon_damage"),
		settingf("cannon_explosion_radius"),
		settingf("cannon_projectile_lifetime"),
		settingf("cannon_blast_duration"),
		fighter.color,
		fighter.accent
	))
	battle.add_entity(CannonMuzzleEntity.new(
		side,
		spawn_position,
		direction,
		projectile_radius,
		settingf("cannon_muzzle_flash_duration"),
		fighter.color,
		fighter.accent
	))
	battle.spawn_ring(spawn_position, Color.WHITE, projectile_radius * 0.45, projectile_radius * 3.4, 0.18)
	battle.spawn_particles(spawn_position, fighter.accent, 14, 178.0)
	battle.emit_combat_event("volley", 0.82)
	battle.record_stat("chess_cannon_shots")

func _advance_cannon_volley(battle, fighter, opponent, side: int, delta: float) -> void:
	if _cannon_shots_remaining <= 0:
		return
	if fighter.hp <= 0.0 or opponent == null or opponent.hp <= 0.0:
		_cancel_cannon_volley()
		return
	_cannon_shot_timer -= delta
	while _cannon_shots_remaining > 0 and _cannon_shot_timer <= EPSILON:
		_fire_cannon_shot(battle, fighter, opponent, side)
		_cannon_shots_remaining -= 1
		if _cannon_shots_remaining > 0:
			_cannon_shot_timer += maxf(EPSILON, settingf("cannon_shot_interval"))

func _cancel_cannon_volley() -> void:
	_cannon_shots_remaining = 0
	_cannon_shot_timer = 0.0

func _activate_elephant(battle, fighter, side: int) -> void:
	var arena_size: Vector2 = battle.arena_size()
	var safe_margin := maxf(fighter.radius + 2.0, settingf("elephant_path_margin"))
	safe_margin = minf(safe_margin, minf(arena_size.x, arena_size.y) * 0.45)
	var center := arena_size * 0.5
	var bottom := Vector2(center.x, arena_size.y - safe_margin)
	var left := Vector2(safe_margin, center.y)
	var top := Vector2(center.x, safe_margin)
	var right := Vector2(arena_size.x - safe_margin, center.y)
	_elephant_vertices.clear()
	_elephant_vertices.append(bottom)
	_elephant_vertices.append(left)
	_elephant_vertices.append(top)
	_elephant_vertices.append(right)
	_elephant_vertices.append(bottom)
	_elephant_active = true
	_elephant_phase = "approach"
	_elephant_position = fighter.pos
	_elephant_target_index = 0
	_elephant_laps_completed = 0
	_elephant_direction = (bottom - _elephant_position).normalized()
	var approach_duration: float = fighter.pos.distance_to(bottom) / maxf(EPSILON, settingf("elephant_start_speed"))
	var lap_distance := 0.0
	for index in range(1, _elephant_vertices.size()):
		lap_distance += _elephant_vertices[index - 1].distance_to(_elephant_vertices[index])
	var path_duration := (
		lap_distance * float(settingi("elephant_laps"))
		/ maxf(EPSILON, settingf("elephant_path_speed"))
	)
	battle.apply_status(fighter, ElephantStatus.new(approach_duration + path_duration + 0.4, side))
	battle.record_stat("chess_elephant_casts")

func _activate_marshal(battle, fighter, side: int) -> void:
	var healed: float = battle.heal(fighter, settingf("marshal_instant_heal"))
	battle.apply_status(fighter, MarshalRegenerationStatus.new(
		settingf("marshal_regen_duration"),
		side,
		settingf("marshal_regen_per_tick"),
		settingf("marshal_regen_interval"),
		fighter.accent
	))
	if healed > 0.0:
		battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.7, fighter.radius * 1.8, 0.34)
	battle.emit_combat_event("judgment", 0.52)
	battle.record_stat("chess_marshal_casts")

func _activate_guard(battle, fighter, side: int) -> void:
	var config := {
		"max_hp": settingf("guard_max_hp"),
		"radius": settingf("guard_radius"),
		"contact_damage": settingf("guard_contact_damage"),
		"contact_interval": settingf("guard_contact_interval"),
		"orbit_radius": settingf("guard_orbit_radius"),
		"orbit_speed": settingf("guard_orbit_speed"),
	}
	for _index in range(settingi("guard_summon_count")):
		battle.add_entity(GuardEntity.new(side, fighter, fighter.color, fighter.accent, config))
	_sync_guards(battle, fighter, side)
	battle.emit_combat_event("split", 0.56)
	battle.record_stat("chess_guard_casts")

func _advance_elephant(battle, fighter, delta: float) -> void:
	var movement_left := _elephant_current_speed() * delta
	while movement_left > EPSILON and _elephant_active:
		var target := _elephant_vertices[_elephant_target_index]
		var offset: Vector2 = target - _elephant_position
		var distance := offset.length()
		if distance > movement_left + EPSILON:
			_elephant_direction = offset / distance
			_elephant_position += _elephant_direction * movement_left
			movement_left = 0.0
			break
		_elephant_position = target
		movement_left = maxf(0.0, movement_left - distance)
		if _elephant_phase == "approach":
			_elephant_phase = "diamond"
			_elephant_target_index = 1
		else:
			_elephant_target_index += 1
			if _elephant_target_index >= _elephant_vertices.size():
				_elephant_laps_completed += 1
				if _elephant_laps_completed >= settingi("elephant_laps"):
					_end_elephant(battle, fighter)
					break
				_elephant_target_index = 1
		if _elephant_active:
			var next_offset: Vector2 = _elephant_vertices[_elephant_target_index] - _elephant_position
			_elephant_direction = next_offset.normalized()
	if _elephant_active:
		fighter.pos = _elephant_position
		fighter.velocity = _elephant_direction * _elephant_current_speed()

func _end_rook(battle, fighter, write_velocity: bool) -> void:
	if not _rook_active:
		return
	if _rook_carried_target != null:
		battle.remove_status(_rook_carried_target, RookCarryStatus.STATUS_KEY)
	_rook_active = false
	_rook_phase = ""
	_rook_windup_remaining = 0.0
	_rook_remaining_distance = 0.0
	_rook_elapsed = 0.0
	_rook_crushed_entity_ids.clear()
	_rook_carried_target = null
	_rook_carry_status = null
	if not write_velocity:
		return
	var exit_direction: Vector2 = fighter.velocity.normalized()
	if exit_direction.length_squared() <= EPSILON:
		exit_direction = _rook_direction
	fighter.velocity = exit_direction * fighter.base_speed

func _end_elephant(battle, fighter) -> void:
	if not _elephant_active:
		return
	_elephant_active = false
	_elephant_phase = ""
	battle.remove_status(fighter, ElephantStatus.STATUS_KEY)
	fighter.pos = _elephant_position
	var exit_direction := _elephant_direction
	if exit_direction.length_squared() <= EPSILON:
		exit_direction = Vector2.UP
	fighter.velocity = exit_direction.normalized() * fighter.base_speed
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.8, fighter.radius * 2.2, 0.32)
	battle.record_stat("chess_elephant_completions")

func _finish_active_movement(battle, fighter) -> void:
	if _rook_active:
		_end_rook(battle, fighter, true)
	if _elephant_active:
		_end_elephant(battle, fighter)

func _elephant_current_speed() -> float:
	return settingf("elephant_start_speed") if _elephant_phase == "approach" else settingf("elephant_path_speed")

func _sync_guards(battle, fighter, side: int) -> void:
	var guards: Array[BallEntity] = []
	for guard: BallEntity in battle.entities(side, "chess_guard"):
		if guard.is_captured() or guard.call("orbit_owner") != fighter:
			continue
		guards.append(guard)
	for index in range(guards.size()):
		guards[index].call("set_orbit_slot", index, guards.size(), _guard_orbit_angle)
		guards[index].call("snap_to_orbit")

func _spawn_cast_icon(battle, fighter, side: int, symbol: String) -> void:
	battle.add_entity(CastIconEntity.new(
		side,
		fighter,
		symbol,
		settingf("cast_icon_duration"),
		fighter.color,
		fighter.accent
	))

func _roll_skill(battle) -> String:
	var weights: Array[float] = []
	var total_weight := 0.0
	for key: String in WEIGHT_KEYS:
		var weight := maxf(0.0, settingf(key))
		weights.append(weight)
		total_weight += weight
	if total_weight <= EPSILON:
		weights.fill(1.0)
		total_weight = float(weights.size())
	var roll: float = battle.random_range(0.0, total_weight)
	var cumulative := 0.0
	for index in range(weights.size()):
		cumulative += weights[index]
		if roll < cumulative:
			return SKILL_KEYS[index]
	return SKILL_KEYS.back()
