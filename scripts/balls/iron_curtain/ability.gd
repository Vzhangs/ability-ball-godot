extends BallAbility

const IronCurtainZoneEntity := preload("res://scripts/balls/iron_curtain/iron_curtain_zone_entity.gd")
const IronDragonProjectileEntity := preload("res://scripts/balls/iron_curtain/iron_dragon_projectile_entity.gd")
const CURTAIN_DISPLAY_NAME := "铁幕球"
const CURTAIN_BODY_COLOR := Color("851a21")
const CURTAIN_ACCENT_COLOR := Color("ff4938")
const DRAGON_ACCENT_COLOR := Color("ff3e32")
const CURTAIN_ACTIVATION_SOUND_EVENT := "iron_curtain_activation"
const DRAGON_FIRE_SOUND_EVENT := "iron_dragon_fire"
const TRANSFORM_SOUND_EVENT := "iron_curtain_transform"
const EPSILON := 0.0001

var _curtain_form := false
var _facing_direction := Vector2.RIGHT
var _transform_remaining := 0.0
var _transform_duration := 0.75
var _muzzle_flash_remaining := 0.0
var _muzzle_flash_duration := 0.32

func on_battle_started(_battle, fighter, opponent, _side: int) -> void:
	_curtain_form = false
	_transform_duration = settingf("transform_animation_duration")
	_transform_remaining = 0.0
	_muzzle_flash_duration = settingf("muzzle_flash_duration")
	_muzzle_flash_remaining = 0.0
	fighter.display_name = module.display_name
	fighter.color = module.color
	fighter.accent = module.accent
	_update_facing(fighter, opponent)

func on_step(battle, fighter, opponent, _side: int, delta: float) -> void:
	_update_facing(fighter, opponent)
	_advance_presentation(delta)
	if not _curtain_form and fighter.hp <= fighter.max_hp * settingf("transform_hp_percent") / 100.0:
		_transform_to_curtain(battle, fighter)

func on_world_stop_step(
	_battle,
	fighter,
	opponent,
	_side: int,
	delta: float
) -> void:
	_update_facing(fighter, opponent)
	_advance_presentation(delta)

func activate(battle, fighter, opponent, side: int) -> void:
	if _curtain_form:
		_deploy_protection_zone(battle, fighter, side)
	else:
		_fire_iron_dragon_projectile(battle, fighter, opponent, side)

func cooldown_duration(_battle, fighter) -> float:
	return fighter.cooldown if _curtain_form else settingf("dragon_fire_interval")

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 0.0

func is_curtain_form() -> bool:
	return _curtain_form

func facing_direction() -> Vector2:
	return _facing_direction

func transform_animation_progress() -> float:
	if _transform_remaining <= 0.0:
		return 1.0
	return clampf(1.0 - _transform_remaining / maxf(_transform_duration, EPSILON), 0.0, 1.0)

func transform_animation_active() -> bool:
	return _transform_remaining > 0.0

func muzzle_flash_progress() -> float:
	if _muzzle_flash_remaining <= 0.0:
		return 1.0
	return clampf(1.0 - _muzzle_flash_remaining / maxf(_muzzle_flash_duration, EPSILON), 0.0, 1.0)

func muzzle_flash_active() -> bool:
	return _muzzle_flash_remaining > 0.0

func _deploy_protection_zone(battle, fighter, side: int) -> void:
	_trim_owned_entities(
		battle,
		fighter.fighter_uid,
		"iron_curtain_field",
		settingi("maximum_active_fields")
	)
	battle.add_entity(IronCurtainZoneEntity.new(side, fighter.pos, {
		"mode": "protection",
		"duration": settingf("protection_zone_duration"),
		"radius": settingf("protection_zone_radius"),
		"damage_interval": settingf("hostile_damage_interval"),
		"damage": settingf("hostile_damage"),
		"invulnerability_duration": settingf("invulnerability_duration"),
		"absorption_radius": settingf("field_absorption_radius"),
	}))
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.8, settingf("protection_zone_radius"), 0.42)
	battle.spawn_particles(fighter.pos, fighter.accent, 14, 138.0)
	battle.emit_combat_event(CURTAIN_ACTIVATION_SOUND_EVENT, 0.7)
	battle.record_stat("iron_curtain_fields_deployed")

func _transform_to_curtain(battle, fighter) -> void:
	_curtain_form = true
	_transform_duration = settingf("transform_animation_duration")
	_transform_remaining = _transform_duration
	fighter.display_name = CURTAIN_DISPLAY_NAME
	fighter.color = CURTAIN_BODY_COLOR
	fighter.accent = CURTAIN_ACCENT_COLOR
	fighter.ability_timer = fighter.cooldown
	if battle.request_world_stop(settingf("transform_world_stop_duration"), fighter):
		battle.record_stat("iron_curtain_world_stops")
	battle.spawn_ring(
		fighter.pos,
		Color("ffefe3"),
		fighter.radius * 0.42,
		fighter.radius * 5.2,
		_transform_duration * 0.74
	)
	battle.spawn_ring(
		fighter.pos,
		Color("ff301f"),
		fighter.radius * 0.7,
		fighter.radius * 4.6,
		_transform_duration
	)
	battle.spawn_ring(
		fighter.pos,
		Color("7b090d"),
		fighter.radius * 2.9,
		fighter.radius * 0.9,
		_transform_duration * 0.82
	)
	battle.spawn_ring(
		fighter.pos,
		Color("250407"),
		fighter.radius * 3.6,
		fighter.radius * 1.08,
		_transform_duration
	)
	battle.spawn_particles(fighter.pos, CURTAIN_ACCENT_COLOR, 38, 248.0)
	battle.spawn_particles(fighter.pos, Color("ffe2c5"), 12, 178.0)
	battle.emit_combat_event(TRANSFORM_SOUND_EVENT, 1.0)
	battle.shake_camera(8.5)
	battle.record_stat("iron_curtain_transformations")

func _advance_presentation(delta: float) -> void:
	_transform_remaining = maxf(0.0, _transform_remaining - delta)
	_muzzle_flash_remaining = maxf(0.0, _muzzle_flash_remaining - delta)

func _fire_iron_dragon_projectile(battle, fighter, opponent, side: int) -> void:
	if opponent == null or opponent.hp <= 0.0:
		return
	_update_facing(fighter, opponent)
	_trim_owned_entities(
		battle,
		fighter.fighter_uid,
		"iron_dragon_projectile",
		settingi("maximum_active_projectiles")
	)
	var projectile_radius := settingf("projectile_radius")
	var spawn_position: Vector2 = (
		fighter.pos
		+ _facing_direction
		* (fighter.radius + projectile_radius + settingf("projectile_spawn_gap"))
	)
	var projectile: BallEntity = IronDragonProjectileEntity.new(side, spawn_position, {
		"velocity": _facing_direction * settingf("projectile_speed"),
		"radius": projectile_radius,
		"duration": settingf("projectile_lifetime"),
		"impact_damage": settingf("projectile_impact_damage"),
		"field_duration": settingf("hazard_zone_duration"),
		"field_radius": settingf("hazard_zone_radius"),
		"damage_interval": settingf("hazard_damage_interval"),
		"damage": settingf("hazard_damage"),
		"field_absorption_radius": settingf("field_absorption_radius"),
		"maximum_active_fields": settingi("maximum_active_fields"),
	})
	battle.add_entity(projectile)
	_muzzle_flash_duration = settingf("muzzle_flash_duration")
	_muzzle_flash_remaining = _muzzle_flash_duration
	battle.spawn_ring(spawn_position, Color("ffb089"), projectile_radius * 0.4, projectile_radius * 3.8, _muzzle_flash_duration)
	battle.spawn_particles(spawn_position, DRAGON_ACCENT_COLOR, 13, 205.0)
	battle.emit_combat_event(DRAGON_FIRE_SOUND_EVENT, 0.86)
	battle.shake_camera(3.8)
	battle.record_stat("iron_dragon_projectiles_fired")

func _update_facing(fighter, opponent) -> void:
	var direction := Vector2.ZERO
	if opponent != null and opponent.hp > 0.0:
		direction = opponent.pos - fighter.pos
	if direction.length_squared() <= EPSILON:
		direction = fighter.velocity
	if direction.length_squared() > EPSILON:
		_facing_direction = direction.normalized()

func _trim_owned_entities(
	battle,
	fighter_uid: int,
	tag: String,
	maximum_count: int
) -> void:
	var owned: Array[BallEntity] = []
	for entity: BallEntity in battle.entities(-1, tag):
		if entity.owner_fighter_uid == fighter_uid:
			owned.append(entity)
	while owned.size() >= maxi(1, maximum_count):
		owned.pop_front().removed = true
