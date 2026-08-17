extends BallAbility

const PsychicPulseEntity := preload("res://scripts/balls/yuri/psychic_pulse_entity.gd")
const PsychicLinkEntity := preload("res://scripts/balls/yuri/psychic_link_entity.gd")
const PsychicEyeOverlayEntity := preload("res://scripts/balls/yuri/psychic_eye_overlay_entity.gd")

var _owner_side := -1
var _controlled_entities: Array[WeakRef] = []

func on_battle_started(_battle, _fighter, _opponent, side: int) -> void:
	_owner_side = side

func controlled_count() -> int:
	var count := 0
	for entity_ref: WeakRef in _controlled_entities:
		var entity = entity_ref.get_ref()
		if entity != null and not entity.removed and entity.owner_side == _owner_side:
			count += 1
	return count

func activate(battle, fighter, _opponent, side: int) -> void:
	_owner_side = side
	_prune_destroyed_or_reowned_entities(side)
	var remaining_capacity := maxi(0, settingi("max_controlled_total") - _controlled_entities.size())
	var control_limit := mini(settingi("max_control_per_cast"), remaining_capacity)
	var targets := _nearest_control_targets(battle, fighter, side, control_limit)
	var controlled := 0
	for target: BallEntity in targets:
		var previous_side := target.owner_side
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
		var former_owner = battle.fighter_for_side(previous_side)
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
