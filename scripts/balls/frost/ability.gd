extends BallAbility

const IceTrailEntity := preload("res://scripts/balls/frost/ice_trail_entity.gd")
const HardFreezeStatus := preload("res://scripts/balls/frost/hard_freeze_status.gd")
const IceSlowStatusEffectScript := preload("res://scripts/balls/core/ice_slow_status_effect.gd")
const ICE_TRAIL_TAG := "frost_ice_trail"
const ICE_COLOR := Color("73e9ff")

var _last_trail_position := Vector2.ZERO
var _has_trail_origin := false
var _trail_contact_seconds := {}

func automatic_activation_enabled() -> bool:
	return false

func on_battle_started(battle, fighter, _opponent, _side: int) -> void:
	_last_trail_position = fighter.pos
	_has_trail_origin = true
	_trail_contact_seconds.clear()
	_spawn_ice_zone(battle, fighter.pos, fighter, fighter.velocity)

func on_step(battle, fighter, _opponent, side: int, _delta: float) -> void:
	_extend_trail(battle, fighter)
	_freeze_overlapping_physical_entities(battle, fighter, side)

func after_entities_step(battle, fighter, _opponent, side: int, delta: float) -> void:
	_update_trail_contacts(battle, fighter, side, delta)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 0.0

func after_contact(battle, fighter, opponent, _damage_dealt: float) -> void:
	_apply_frostbite(battle, fighter, opponent)

func after_entity_contact(
	battle,
	fighter,
	entity: BallEntity,
	_damage_dealt: float
) -> void:
	_apply_frostbite(battle, fighter, entity)

func _extend_trail(battle, fighter) -> void:
	var current_position: Vector2 = fighter.pos
	if not _has_trail_origin:
		_last_trail_position = current_position
		_has_trail_origin = true
		_spawn_ice_zone(battle, current_position, fighter, Vector2.RIGHT)
		return
	var spacing := maxf(0.001, settingf("trail_spacing"))
	var segment := current_position - _last_trail_position
	var segment_length := segment.length()
	if segment_length < spacing:
		return
	var direction := segment / segment_length
	var spawn_count := floori(segment_length / spacing)
	for _index in range(spawn_count):
		_last_trail_position += direction * spacing
		_spawn_ice_zone(battle, _last_trail_position, fighter, direction)

func _spawn_ice_zone(
	battle,
	position: Vector2,
	fighter,
	travel_direction: Vector2
) -> void:
	var zones := _owned_ice_zones(battle, fighter)
	if zones.size() >= settingi("max_ice_zones"):
		zones[0].removed = true
	var zone := IceTrailEntity.new(fighter.team_id, position, {
		"duration": settingf("ice_zone_duration"),
		"radius": settingf("ice_zone_radius"),
		"absorption_radius_cap": settingf("ice_zone_absorption_radius_cap"),
		"absorption_radius_ratio": settingf("ice_zone_absorption_radius_ratio"),
		"travel_direction": travel_direction,
	})
	zone.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(zone)

func _owned_ice_zones(battle, fighter) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for zone: BallEntity in battle.entities(fighter.team_id, ICE_TRAIL_TAG):
		if zone.owner_fighter_uid == fighter.fighter_uid:
			result.append(zone)
	return result

func _update_trail_contacts(battle, fighter, side: int, delta: float) -> void:
	var zones := _owned_ice_zones(battle, fighter)
	var touched_targets := {}
	for target in battle.hostile_fighters(side):
		for zone: BallEntity in zones:
			if _overlaps(zone.pos, zone.radius, target.pos, target.radius):
				touched_targets[target.get_instance_id()] = target
				break
	for zone: BallEntity in zones:
		for entity: BallEntity in battle.damageable_entities_in_circle(side, zone.pos, zone.radius):
			touched_targets[entity.get_instance_id()] = entity
	var current_contacts := {}
	var freeze_delay := settingf("trail_freeze_delay")
	for target_id in touched_targets:
		var target = touched_targets[target_id]
		# First observation starts at zero; overlapping patches never multiply time.
		var contact_time := 0.0
		if _trail_contact_seconds.has(target_id):
			contact_time = minf(freeze_delay, float(_trail_contact_seconds[target_id]) + maxf(0.0, delta))
		current_contacts[target_id] = contact_time
		_apply_slow(battle, fighter, target)
		if contact_time + 0.000001 >= freeze_delay:
			_apply_frostbite(battle, fighter, target)
	# Missing targets include departed, dead, captured and no-longer-hostile units.
	_trail_contact_seconds = current_contacts

func _freeze_overlapping_physical_entities(battle, fighter, side: int) -> void:
	for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, fighter.radius):
		if not entity.participates_in_fighter_collision() \
				and not entity.participates_in_entity_collision():
			continue
		_apply_frostbite(battle, fighter, entity)

func _apply_frostbite(battle, fighter, target) -> bool:
	if target == null:
		return false
	if target is BallEntity:
		var target_entity := target as BallEntity
		if target_entity.removed or target_entity.is_captured() \
				or not target_entity.can_receive_attack(fighter.team_id):
			return false
	elif target.hp <= 0.0 or target.team_id == fighter.team_id:
		return false
	var was_frozen: bool = battle.has_status(target, HardFreezeStatus.KEY)
	battle.apply_status(target, HardFreezeStatus.new(
		settingf("freeze_duration"),
		fighter.team_id,
		settingf("freeze_damage"),
		settingf("freeze_damage_interval"),
		target.velocity,
		settingf("slow_multiplier"),
		ICE_COLOR
	))
	_apply_slow(battle, fighter, target)
	if was_frozen:
		battle.record_stat("frost_freeze_refreshes")
		return true
	battle.spawn_ring(target.pos, ICE_COLOR, target.radius * 0.3, target.radius * 1.9, 0.32)
	battle.spawn_particles(target.pos, Color("dffcff"), 10, 92.0)
	battle.emit_combat_event("projectile_hit", 0.46)
	battle.record_stat("frost_freezes_applied")
	return true

func _apply_slow(battle, fighter, target) -> void:
	battle.apply_status(target, IceSlowStatusEffectScript.new(
		settingf("slow_duration"),
		fighter.team_id,
		settingf("slow_multiplier")
	))

func _overlaps(
	first_position: Vector2,
	first_radius: float,
	second_position: Vector2,
	second_radius: float
) -> bool:
	var distance := first_radius + second_radius
	return first_position.distance_squared_to(second_position) <= distance * distance
