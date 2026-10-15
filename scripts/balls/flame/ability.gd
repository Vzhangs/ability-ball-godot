extends BallAbility

const FireZoneEntity := preload("res://scripts/balls/flame/fire_zone_entity.gd")
const CombustionEntity := preload("res://scripts/balls/flame/combustion_entity.gd")
const BurnStatusEffectScript := preload("res://scripts/balls/core/burn_status_effect.gd")
const FIRE_ZONE_TAG := "flame_zone"
const BURN_SOURCE_KEY := "flame_trail"

var _last_trail_position := Vector2.ZERO
var _has_trail_origin := false
var _trail_damage_timer := 0.0

func automatic_activation_enabled() -> bool:
	return false

func on_battle_started(battle, fighter, _opponent, side: int) -> void:
	_last_trail_position = fighter.pos
	_has_trail_origin = true
	_spawn_fire_zone(battle, fighter.pos, side, fighter.velocity)

func before_motion(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_trail_damage_timer = maxf(0.0, _trail_damage_timer - delta)

func on_step(battle, fighter, _opponent, side: int, _delta: float) -> void:
	_extend_trail(battle, fighter.pos, side)
	_damage_targets_on_trail(battle, fighter, side)

func _extend_trail(battle, current_position: Vector2, side: int) -> void:
	if not _has_trail_origin:
		_last_trail_position = current_position
		_has_trail_origin = true
		_spawn_fire_zone(battle, current_position, side, Vector2.RIGHT)
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
		_spawn_fire_zone(battle, _last_trail_position, side, direction)

func _spawn_fire_zone(
	battle,
	position: Vector2,
	side: int,
	travel_direction: Vector2
) -> void:
	var zones: Array[BallEntity] = battle.entities(side, FIRE_ZONE_TAG)
	if zones.size() >= settingi("max_fire_zones"):
		zones[0].removed = true
	battle.add_entity(FireZoneEntity.new(side, position, {
		"duration": settingf("fire_zone_duration"),
		"radius": settingf("fire_zone_radius"),
		"absorption_radius_cap": settingf("fire_zone_absorption_radius_cap"),
		"absorption_radius_ratio": settingf("fire_zone_absorption_radius_ratio"),
		"travel_direction": travel_direction,
	}))

func contact_damage(_battle, _fighter, _opponent) -> float:
	return settingf("combustion_damage")

func after_contact(battle, fighter, opponent, _damage_dealt: float) -> void:
	_trigger_combustion(battle, fighter, opponent)

func after_entity_contact(
	battle,
	fighter,
	entity: BallEntity,
	_damage_dealt: float
) -> void:
	_trigger_combustion(battle, fighter, entity)

func _damage_targets_on_trail(battle, fighter, side: int) -> void:
	if _trail_damage_timer > 0.0:
		return
	var zones: Array[BallEntity] = battle.entities(side, FIRE_ZONE_TAG)
	if zones.is_empty():
		return
	# The damage interval is also the overlap-query cadence. Empty fire stays cheap
	# even when a battle contains many clones, plants, tanks, or other attachments.
	_trail_damage_timer = settingf("trail_damage_interval")
	var touched_fighters := []
	var touched_entities := {}
	for target in battle.hostile_fighters(side):
		for zone: BallEntity in zones:
			if zone.pos.distance_squared_to(target.pos) <= pow(zone.radius + target.radius, 2.0):
				touched_fighters.append(target)
				break
	for zone: BallEntity in zones:
		for entity: BallEntity in battle.damageable_entities_in_circle(side, zone.pos, zone.radius):
			touched_entities[entity.get_instance_id()] = entity
	if touched_fighters.is_empty() and touched_entities.is_empty():
		return

	var hit_count := 0
	for target in touched_fighters:
		var applied: float = battle.damage(target, settingf("trail_damage"), fighter.accent, fighter)
		if target.hp > 0.0:
			battle.apply_status(target, BurnStatusEffectScript.new(
				settingf("burn_debuff_duration"),
				side,
				settingf("burn_debuff_damage"),
				settingf("burn_debuff_tick_interval"),
				BURN_SOURCE_KEY,
				Color("ff5b21")
			))
			battle.record_stat("flame_burns_applied")
		if applied > 0.0:
			hit_count += 1
	for entity: BallEntity in touched_entities.values():
		if battle.damage_entity(entity, settingf("trail_damage"), fighter.accent, side) > 0.0:
			hit_count += 1
	if hit_count > 0:
		battle.record_stat("flame_trail_hits", hit_count)

func _trigger_combustion(battle, fighter, primary_target) -> void:
	if primary_target == null:
		return
	var side: int = fighter.team_id
	var center: Vector2 = fighter.pos.lerp(primary_target.pos, 0.5)
	var blast_radius := settingf("combustion_radius")
	var blast_damage := settingf("combustion_damage")
	var affected_count := 0
	for target in battle.hostile_fighters(side):
		if target.pos.distance_squared_to(center) > pow(blast_radius + target.radius, 2.0):
			continue
		if target != primary_target:
			battle.damage(target, blast_damage, fighter.accent, fighter)
		if target.hp > 0.0:
			_apply_burn(battle, target, side)
			affected_count += 1
	for entity: BallEntity in battle.damageable_entities_in_circle(side, center, blast_radius):
		if entity != primary_target:
			battle.damage_entity(entity, blast_damage, fighter.accent, side)
		if not entity.removed:
			_apply_burn(battle, entity, side)
			affected_count += 1

	battle.add_entity(CombustionEntity.new(
		side,
		center,
		blast_radius,
		settingf("combustion_effect_duration")
	))
	battle.spawn_particles(center, Color("ff8a24"), 22, 210.0)
	battle.shake_camera(4.6)
	battle.emit_combat_event("projectile_hit", 0.82)
	battle.record_stat("flame_combustions")
	if affected_count > 0:
		battle.record_stat("flame_combustion_targets", affected_count)

func _apply_burn(battle, target, side: int) -> void:
	battle.apply_status(target, BurnStatusEffectScript.new(
		settingf("burn_debuff_duration"),
		side,
		settingf("burn_debuff_damage"),
		settingf("burn_debuff_tick_interval"),
		BURN_SOURCE_KEY,
		Color("ff5b21")
	))
	battle.record_stat("flame_burns_applied")
