extends BallAbility

const RemoteDrainEntity := preload("res://scripts/balls/vampire/remote_drain_entity.gd")
const LatchTetherEntity := preload("res://scripts/balls/vampire/latch_tether_entity.gd")
const LatchInvulnerabilityEffect := preload("res://scripts/balls/vampire/latch_invulnerability_effect.gd")
const LatchDragEffect := preload("res://scripts/balls/vampire/latch_drag_effect.gd")
const LatchReleaseEffect := preload("res://scripts/balls/vampire/latch_release_effect.gd")

var _facing_direction := Vector2.RIGHT
var _latch_remaining := 0.0
var _latch_tick_remaining := 0.0
var _latched_opponent_velocity := Vector2.ZERO
var _latched_entity_velocity := Vector2.ZERO
var _latched_entity_ref: WeakRef
var _latch_tether: BallEntity

func on_battle_started(_battle, fighter, opponent, _side: int) -> void:
	_latch_remaining = 0.0
	_latch_tick_remaining = 0.0
	_latched_opponent_velocity = Vector2.ZERO
	_latched_entity_velocity = Vector2.ZERO
	_latched_entity_ref = null
	_latch_tether = null
	_update_facing(fighter, opponent)
	# The first ranged drain waits a full interval instead of the generic opening stagger.
	fighter.ability_timer = fighter.cooldown

func before_motion(battle, fighter, opponent, side: int, delta: float) -> void:
	if _latch_remaining <= 0.0:
		_update_facing(fighter, opponent)
		return
	battle.apply_status(fighter, LatchInvulnerabilityEffect.new(_latch_remaining + delta, side))
	if _latched_entity_ref != null:
		var entity_target: BallEntity = _latched_entity()
		if not _is_entity_latch_target_valid(entity_target, side):
			_end_entity_latch(battle, fighter, entity_target, false)
			_update_facing(fighter, opponent)
			return
		_update_facing_to_position(fighter, entity_target.pos)
		_maintain_entity_latch(battle, fighter, entity_target)
		return
	_update_facing(fighter, opponent)
	battle.apply_status(opponent, LatchDragEffect.new(_latch_remaining + delta, side))
	_maintain_latch(battle, fighter, opponent)

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	if _latch_remaining <= 0.0:
		_update_facing(fighter, opponent)
		return
	if _latched_entity_ref != null:
		_step_entity_latch(battle, fighter, opponent, side, delta)
		return
	_update_facing(fighter, opponent)
	if fighter.hp <= 0.0 or opponent == null or opponent.hp <= 0.0:
		_end_latch(battle, fighter, opponent, false)
		return
	_maintain_latch(battle, fighter, opponent)
	var active_delta := minf(delta, _latch_remaining)
	_latch_remaining = maxf(0.0, _latch_remaining - delta)
	_latch_tick_remaining -= active_delta
	var interval := maxf(0.001, settingf("latch_drain_interval"))
	while _latch_tick_remaining <= 0.000001 and _latch_remaining > 0.0:
		_perform_latch_drain(battle, fighter, opponent)
		_latch_tick_remaining += interval
		if opponent.hp <= 0.0:
			_end_latch(battle, fighter, opponent, false)
			return
	if _latch_remaining <= 0.0:
		_end_latch(battle, fighter, opponent, true)

func activate(battle, fighter, opponent, side: int) -> void:
	battle.add_entity(RemoteDrainEntity.new(
		side,
		settingi("remote_strand_count"),
		settingf("remote_travel_duration"),
		settingf("remote_strand_stagger"),
		settingf("remote_suction_duration"),
		settingf("remote_drain_damage"),
		settingf("remote_heal_ratio"),
		fighter.accent
	))
	battle.spawn_ring(opponent.pos, fighter.accent, opponent.radius * 0.55, opponent.radius * 1.25, 0.42)
	battle.spawn_particles(opponent.pos, fighter.accent, settingi("remote_strand_count") * 2, 72.0)
	battle.record_stat("vampire_remote_casts")

func contact_damage(_battle, _fighter, _opponent) -> float:
	# Contact starts a timed latch. The collision itself has no immediate damage.
	return 0.0

func after_contact(battle, fighter, opponent, _damage_dealt: float) -> void:
	if _latch_remaining > 0.0 or fighter.hp <= 0.0 or opponent.hp <= 0.0:
		return
	_latch_remaining = settingf("latch_duration")
	if _latch_remaining <= 0.0:
		return
	_latch_tick_remaining = maxf(0.001, settingf("latch_drain_interval"))
	_latched_opponent_velocity = opponent.velocity
	var side: int = battle.side_for_fighter(fighter)
	battle.apply_status(fighter, LatchInvulnerabilityEffect.new(_latch_remaining, side))
	battle.apply_status(opponent, LatchDragEffect.new(_latch_remaining, side))
	_latch_tether = LatchTetherEntity.new(side, _latch_remaining, fighter.accent)
	battle.add_entity(_latch_tether)
	_update_facing(fighter, opponent)
	_maintain_latch(battle, fighter, opponent)
	battle.spawn_ring(opponent.pos, fighter.accent, 8.0, opponent.radius * 1.45, 0.32)
	battle.spawn_particles(opponent.pos, fighter.accent, 9, 92.0)
	battle.record_stat("vampire_latches")

func after_entity_contact(
	battle,
	fighter,
	entity: BallEntity,
	_damage_dealt: float
) -> void:
	var side: int = battle.side_for_fighter(fighter)
	if (
		_latch_remaining > 0.0
		or fighter.hp <= 0.0
		or entity == null
		or not entity.can_receive_attack(side)
	):
		return
	_latch_remaining = settingf("latch_duration")
	if _latch_remaining <= 0.0:
		return
	_latch_tick_remaining = maxf(0.001, settingf("latch_drain_interval"))
	_latched_entity_velocity = entity.velocity
	_latched_entity_ref = weakref(entity)
	battle.apply_status(fighter, LatchInvulnerabilityEffect.new(_latch_remaining, side))
	_latch_tether = LatchTetherEntity.new(side, _latch_remaining, fighter.accent, entity)
	battle.add_entity(_latch_tether)
	_update_facing_to_position(fighter, entity.pos)
	_maintain_entity_latch(battle, fighter, entity)
	battle.spawn_ring(entity.pos, fighter.accent, 8.0, entity.radius * 1.45, 0.32)
	battle.spawn_particles(entity.pos, fighter.accent, 9, 92.0)
	battle.record_stat("vampire_latches")
	battle.record_stat("vampire_entity_latches")

func facing_direction() -> Vector2:
	return _facing_direction

func latch_remaining() -> float:
	return _latch_remaining

func is_latching() -> bool:
	return _latch_remaining > 0.0

func is_latching_entity() -> bool:
	return _latch_remaining > 0.0 and _latched_entity_ref != null

func _perform_latch_drain(battle, fighter, opponent) -> void:
	var applied: float = battle.damage(
		opponent,
		settingf("latch_drain_damage"),
		fighter.accent,
		fighter
	)
	if applied <= 0.0:
		return
	battle.heal(fighter, applied * settingf("latch_heal_ratio"), true)
	var mouth_position: Vector2 = fighter.pos + _facing_direction * fighter.radius * 1.2
	battle.spawn_ring(mouth_position, fighter.accent, 3.0, 42.0, 0.24)
	battle.spawn_particles(mouth_position, fighter.accent, 7, 68.0)
	battle.emit_combat_event("blood", 0.58)
	battle.record_stat("vampire_latch_drains")

func _perform_entity_latch_drain(
	battle,
	fighter,
	entity: BallEntity,
	side: int
) -> float:
	var applied: float = battle.damage_entity(
		entity,
		settingf("latch_drain_damage"),
		fighter.accent,
		side
	)
	if applied <= 0.0:
		return 0.0
	battle.heal(fighter, applied * settingf("latch_heal_ratio"), true)
	var mouth_position: Vector2 = fighter.pos + _facing_direction * fighter.radius * 1.2
	battle.spawn_ring(mouth_position, fighter.accent, 3.0, 42.0, 0.24)
	battle.spawn_particles(mouth_position, fighter.accent, 7, 68.0)
	battle.emit_combat_event("blood", 0.58)
	battle.record_stat("vampire_latch_drains")
	battle.record_stat("vampire_entity_latch_drains")
	return applied

func _maintain_latch(battle, fighter, opponent) -> void:
	var distance: float = fighter.radius + opponent.radius + settingf("latch_gap")
	var target_position: Vector2 = fighter.pos + _facing_direction * distance
	var arena_size: Vector2 = battle.arena_size()
	target_position.x = clampf(target_position.x, opponent.radius, arena_size.x - opponent.radius)
	target_position.y = clampf(target_position.y, opponent.radius, arena_size.y - opponent.radius)
	opponent.pos = target_position
	opponent.velocity = fighter.velocity

func _maintain_entity_latch(battle, fighter, entity: BallEntity) -> void:
	var distance: float = fighter.radius + entity.radius + settingf("latch_gap")
	var target_position: Vector2 = fighter.pos + _facing_direction * distance
	var arena_size: Vector2 = battle.arena_size()
	target_position.x = clampf(target_position.x, entity.radius, arena_size.x - entity.radius)
	target_position.y = clampf(target_position.y, entity.radius, arena_size.y - entity.radius)
	entity.pos = target_position
	entity.velocity = (
		fighter.velocity
		if entity.fighter_collision_inverse_mass() > 0.0
		else Vector2.ZERO
	)

func _step_entity_latch(
	battle,
	fighter,
	opponent,
	side: int,
	delta: float
) -> void:
	var entity: BallEntity = _latched_entity()
	if fighter.hp <= 0.0 or not _is_entity_latch_target_valid(entity, side):
		_end_entity_latch(battle, fighter, entity, false)
		_update_facing(fighter, opponent)
		return
	_update_facing_to_position(fighter, entity.pos)
	_maintain_entity_latch(battle, fighter, entity)
	var active_delta := minf(delta, _latch_remaining)
	_latch_remaining = maxf(0.0, _latch_remaining - delta)
	_latch_tick_remaining -= active_delta
	var interval := maxf(0.001, settingf("latch_drain_interval"))
	while _latch_tick_remaining <= 0.000001 and _latch_remaining > 0.0:
		_perform_entity_latch_drain(battle, fighter, entity, side)
		_latch_tick_remaining += interval
		if entity.removed:
			_end_entity_latch(battle, fighter, entity, false)
			return
	if _latch_remaining <= 0.0:
		_end_entity_latch(battle, fighter, entity, true)

func _end_latch(battle, fighter, opponent, release_both: bool) -> void:
	battle.remove_status(fighter, LatchInvulnerabilityEffect.STATUS_KEY)
	if opponent != null:
		battle.remove_status(opponent, LatchDragEffect.STATUS_KEY)
	if release_both and fighter != null and opponent != null:
		var release_direction: Vector2 = opponent.pos - fighter.pos
		if release_direction.length_squared() <= 0.0001:
			release_direction = _facing_direction
		release_direction = release_direction.normalized()
		var release_speed := settingf("latch_release_speed")
		fighter.velocity = -release_direction * release_speed
		opponent.velocity = release_direction * release_speed
		var release_duration := settingf("latch_release_duration")
		if release_duration > 0.0:
			var side: int = battle.side_for_fighter(fighter)
			battle.apply_status(fighter, LatchReleaseEffect.new(release_duration, side))
			battle.apply_status(opponent, LatchReleaseEffect.new(release_duration, side))
		var release_center: Vector2 = (fighter.pos + opponent.pos) * 0.5
		battle.spawn_ring(release_center, fighter.accent, 8.0, 82.0, 0.28)
		battle.spawn_particles(release_center, fighter.accent, 12, release_speed * 0.45)
		battle.emit_combat_event("body_impact", 0.68)
	elif opponent != null:
		opponent.velocity = _latched_opponent_velocity
	if _latch_tether != null:
		_latch_tether.removed = true
	_latch_tether = null
	_latch_remaining = 0.0
	_latch_tick_remaining = 0.0
	_latched_opponent_velocity = Vector2.ZERO
	_latched_entity_velocity = Vector2.ZERO
	_latched_entity_ref = null

func _end_entity_latch(
	battle,
	fighter,
	entity: BallEntity,
	release_both: bool
) -> void:
	if fighter != null:
		battle.remove_status(fighter, LatchInvulnerabilityEffect.STATUS_KEY)
	if fighter != null and entity != null and not entity.removed:
		if release_both:
			var release_direction: Vector2 = entity.pos - fighter.pos
			if release_direction.length_squared() <= 0.0001:
				release_direction = _facing_direction
			release_direction = release_direction.normalized()
			var release_speed := settingf("latch_release_speed")
			fighter.velocity = -release_direction * release_speed
			entity.velocity = (
				release_direction * release_speed
				if entity.fighter_collision_inverse_mass() > 0.0
				else _latched_entity_velocity
			)
			var release_duration := settingf("latch_release_duration")
			if release_duration > 0.0:
				var side: int = battle.side_for_fighter(fighter)
				battle.apply_status(fighter, LatchReleaseEffect.new(release_duration, side))
			var release_center: Vector2 = (fighter.pos + entity.pos) * 0.5
			battle.spawn_ring(release_center, fighter.accent, 8.0, 82.0, 0.28)
			battle.spawn_particles(release_center, fighter.accent, 12, release_speed * 0.45)
			battle.emit_combat_event("body_impact", 0.68)
		else:
			entity.velocity = _latched_entity_velocity
	if _latch_tether != null:
		_latch_tether.removed = true
	_latch_tether = null
	_latch_remaining = 0.0
	_latch_tick_remaining = 0.0
	_latched_opponent_velocity = Vector2.ZERO
	_latched_entity_velocity = Vector2.ZERO
	_latched_entity_ref = null

func _latched_entity() -> BallEntity:
	if _latched_entity_ref == null:
		return null
	return _latched_entity_ref.get_ref() as BallEntity

func _is_entity_latch_target_valid(entity: BallEntity, side: int) -> bool:
	return entity != null and not entity.removed and entity.can_receive_attack(side)

func _update_facing(fighter, opponent) -> void:
	if opponent == null:
		return
	_update_facing_to_position(fighter, opponent.pos)

func _update_facing_to_position(fighter, target_position: Vector2) -> void:
	var direction: Vector2 = target_position - fighter.pos
	if direction.length_squared() > 0.0001:
		_facing_direction = direction.normalized()
