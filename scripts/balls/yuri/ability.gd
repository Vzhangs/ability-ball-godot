extends BallAbility

const PsychicPulseEntity := preload("res://scripts/balls/yuri/psychic_pulse_entity.gd")
const PsychicLinkEntity := preload("res://scripts/balls/yuri/psychic_link_entity.gd")
const PsychicEyeOverlayEntity := preload("res://scripts/balls/yuri/psychic_eye_overlay_entity.gd")

var _owner_side := -1
var _controlled_entities: Array[WeakRef] = []
var _overload_tick_timer := 0.0
var _overload_flash_remaining := 0.0
var _current_overload_excess := 0

func on_battle_started(_battle, _fighter, _opponent, side: int) -> void:
	_owner_side = side
	_controlled_entities.clear()
	_overload_tick_timer = settingf("control_overload_tick_interval")
	_overload_flash_remaining = 0.0
	_current_overload_excess = 0

func controlled_count() -> int:
	var count := 0
	for entity_ref: WeakRef in _controlled_entities:
		var entity = entity_ref.get_ref()
		if entity != null and not entity.removed and entity.owner_side == _owner_side:
			count += 1
	return count

func overload_excess_count() -> int:
	return _current_overload_excess

func overload_flash_ratio() -> float:
	return clampf(
		_overload_flash_remaining / maxf(0.001, settingf("control_overload_effect_duration")),
		0.0,
		1.0
	)

func on_step(battle, fighter, _opponent, side: int, delta: float) -> void:
	_owner_side = side
	_overload_flash_remaining = maxf(0.0, _overload_flash_remaining - delta)
	_prune_destroyed_or_reowned_entities(side)
	var hard_limit := settingi("max_controlled_total")
	var soft_limit := mini(settingi("soft_controlled_total"), hard_limit)
	_current_overload_excess = maxi(0, _controlled_entities.size() - soft_limit)
	var tick_interval := settingf("control_overload_tick_interval")
	if _current_overload_excess <= 0:
		_overload_tick_timer = tick_interval
		return
	_overload_tick_timer -= delta
	while _overload_tick_timer <= 0.000001 and fighter.hp > 0.0:
		_overload_tick_timer += tick_interval
		_apply_control_overload_tick(battle, fighter)

func activate(battle, fighter, _opponent, side: int) -> void:
	_owner_side = side
	_prune_destroyed_or_reowned_entities(side)
	var remaining_capacity := maxi(0, settingi("max_controlled_total") - _controlled_entities.size())
	var control_limit := mini(settingi("max_control_per_cast"), remaining_capacity)
	var targets := _nearest_control_targets(battle, fighter, side, control_limit)
	var controlled := 0
	for target: BallEntity in targets:
		var former_owner = battle.owner_for_entity(target)
		if not target.transfer_ownership(side, fighter):
			continue
		target.set_ownership_visual_color(fighter.accent)
		var controlled_color := target.absorption_visual_color()
		target.velocity = -target.velocity * settingf("controlled_velocity_multiplier")
		_controlled_entities.append(weakref(target))
		battle.add_entity(PsychicLinkEntity.new(
			side,
			fighter,
			target,
			settingf("link_duration"),
			fighter.accent,
			controlled_color
		))
		if former_owner != null:
			battle.damage(
				former_owner,
				settingf("control_backlash_damage"),
				fighter.accent,
				fighter
			)
		battle.spawn_ring(target.pos, controlled_color, maxf(4.0, target.radius), 46.0, 0.32)
		battle.spawn_particles(target.pos, controlled_color, 7, 105.0)
		battle.record_stat("mind_controls")
		controlled += 1
	_current_overload_excess = maxi(
		0,
		_controlled_entities.size() - mini(
			settingi("soft_controlled_total"),
			settingi("max_controlled_total")
		)
	)
	if controlled <= 0:
		return
	var pulse_duration := settingf("pulse_duration")
	battle.add_entity(PsychicPulseEntity.new(
		side,
		fighter.pos,
		settingf("control_range"),
		pulse_duration,
		fighter.accent
	))
	battle.add_entity(PsychicEyeOverlayEntity.new(
		side,
		fighter,
		pulse_duration,
		fighter.accent
	))
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 132.0, pulse_duration)
	battle.emit_combat_event("psychic_pulse", 0.92)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 0.0

func _apply_control_overload_tick(battle, fighter) -> void:
	var tick_interval := settingf("control_overload_tick_interval")
	var damage := float(_current_overload_excess) \
		* settingf("control_overload_damage_per_excess_per_second") \
		* tick_interval
	var applied: float = battle.damage(fighter, damage, Color("ff78ea"), null)
	if applied <= 0.0:
		return
	_overload_flash_remaining = settingf("control_overload_effect_duration")
	var particle_count := 4 + mini(_current_overload_excess, 5)
	battle.spawn_particles(
		fighter.pos,
		Color("ff78ea"),
		particle_count,
		72.0 + float(_current_overload_excess) * 9.0
	)
	battle.record_stat("mind_control_overload_ticks")
	battle.record_stat("mind_control_overload_excess", _current_overload_excess)

func _nearest_control_targets(battle, fighter, side: int, limit: int) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	if limit <= 0:
		return result
	var entities: Array[BallEntity] = battle.entities()
	while result.size() < limit:
		var nearest: BallEntity = null
		var nearest_distance_squared := INF
		for entity: BallEntity in entities:
			if entity in result or not entity.is_hostile_to(side) or not entity.can_transfer_ownership():
				continue
			var range_limit := settingf("control_range") + entity.radius
			var distance_squared: float = fighter.pos.distance_squared_to(entity.pos)
			if distance_squared > range_limit * range_limit or distance_squared >= nearest_distance_squared:
				continue
			nearest = entity
			nearest_distance_squared = distance_squared
		if nearest == null:
			break
		result.append(nearest)
	return result

## Control has no distance check and never expires. This list only drops entities that no
## longer exist or whose ownership was explicitly changed again by another mechanic.
func _prune_destroyed_or_reowned_entities(side: int) -> void:
	for index in range(_controlled_entities.size() - 1, -1, -1):
		var entity = _controlled_entities[index].get_ref()
		if entity == null or entity.removed or entity.owner_side != side:
			_controlled_entities.remove_at(index)
