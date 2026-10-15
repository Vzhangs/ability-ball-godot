extends BallAbility

const TechniqueOrbEntity := preload("res://scripts/balls/gojo/technique_orb_entity.gd")
const UnlimitedVoidEntity := preload("res://scripts/balls/gojo/unlimited_void_entity.gd")
const NamedCastVfx := preload("res://scripts/balls/core/named_cast_entity.gd")
const BLUE := "blue"
const RED := "red"
const PURPLE := "purple"
const EPSILON := 0.0001

var _last_cast_kind := ""
var _cast_flash_remaining := 0.0
var _unlimited_void_used := false
var _domain_flash_remaining := 0.0

func on_battle_started(_battle, fighter, _opponent, _side: int) -> void:
	_last_cast_kind = ""
	_cast_flash_remaining = 0.0
	_unlimited_void_used = false
	_domain_flash_remaining = 0.0
	fighter.ability_timer = settingf("opening_delay")

func on_step(battle, fighter, _opponent, side: int, delta: float) -> void:
	_cast_flash_remaining = maxf(0.0, _cast_flash_remaining - delta)
	_domain_flash_remaining = maxf(0.0, _domain_flash_remaining - delta)
	if _should_trigger_unlimited_void(battle, fighter):
		_trigger_unlimited_void(battle, fighter, side)

func after_entities_step(battle, fighter, _opponent, side: int, _delta: float) -> void:
	_fuse_touching_pairs(battle, fighter, side)

func activate(battle, fighter, opponent, side: int) -> void:
	if opponent == null or opponent.hp <= 0.0:
		return
	var kind := BLUE if battle.random_float() < settingf("blue_cast_probability") else RED
	_spawn_technique_orb(battle, fighter, opponent, side, kind)
	_last_cast_kind = kind
	_cast_flash_remaining = settingf("cast_flash_duration")

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 0.0

func last_cast_kind() -> String:
	return _last_cast_kind

func cast_flash_ratio() -> float:
	return clampf(_cast_flash_remaining / maxf(settingf("cast_flash_duration"), EPSILON), 0.0, 1.0)

func domain_flash_ratio() -> float:
	return clampf(_domain_flash_remaining / maxf(settingf("domain_duration"), EPSILON), 0.0, 1.0)

func unlimited_void_used() -> bool:
	return _unlimited_void_used

func _spawn_technique_orb(battle, fighter, opponent, side: int, kind: String) -> BallEntity:
	_trim_owned_orbs(battle, fighter.fighter_uid, kind, _maximum_for_kind(kind))
	var direction: Vector2 = opponent.pos - fighter.pos
	if direction.length_squared() <= EPSILON:
		direction = fighter.velocity
	if direction.length_squared() <= EPSILON:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var orb_radius := _radius_for_kind(kind)
	var spawn_position: Vector2 = fighter.pos + direction * (
		fighter.radius + orb_radius + settingf("spawn_gap")
	)
	var orb: BallEntity = TechniqueOrbEntity.new(side, spawn_position, {
		"kind": kind,
		"velocity": direction * _speed_for_kind(kind),
		"radius": orb_radius,
		"damage": _damage_for_kind(kind),
		"duration": _lifetime_for_kind(kind),
		"effect_radius": settingf("%s_force_radius" % kind),
		"force_acceleration": settingf("%s_force_acceleration" % kind),
		"force_maximum_speed": settingf("%s_force_maximum_speed" % kind),
		"impact_impulse": settingf("red_impact_impulse") if kind == RED else 0.0,
		"hit_interval": settingf("orb_hit_interval"),
	})
	orb.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(orb)
	var color := _color_for_kind(kind)
	battle.spawn_ring(spawn_position, color, orb_radius * 0.45, orb_radius * 4.2, 0.28)
	battle.spawn_particles(spawn_position, color, 9, 132.0)
	battle.emit_combat_event("psychic_pulse", 0.46 if kind == BLUE else 0.62)
	_announce_cast(
		battle, fighter, side,
		"术式顺转「苍」" if kind == BLUE else "术式反转「赫」",
		"gojo_blue_voice" if kind == BLUE else "gojo_red_voice",
		color, settingf("cast_name_duration")
	)
	battle.record_stat("gojo_%s_orbs_spawned" % kind)
	return orb

func _fuse_touching_pairs(battle, fighter, side: int) -> void:
	var blue_orbs := _owned_orbs(battle, fighter.fighter_uid, BLUE)
	var red_orbs := _owned_orbs(battle, fighter.fighter_uid, RED)
	for blue: BallEntity in blue_orbs:
		if blue.removed:
			continue
		for red: BallEntity in red_orbs:
			if red.removed:
				continue
			var fusion_distance := blue.radius + red.radius
			if blue.pos.distance_squared_to(red.pos) > fusion_distance * fusion_distance:
				continue
			_fuse_pair(battle, fighter, side, blue, red)
			break

func _fuse_pair(battle, fighter, side: int, blue: BallEntity, red: BallEntity) -> void:
	blue.removed = true
	red.removed = true
	_trim_owned_orbs(battle, fighter.fighter_uid, PURPLE, settingi("maximum_purple_orbs"))
	var fusion_position := (blue.pos + red.pos) * 0.5
	var direction: Vector2 = blue.velocity + red.velocity
	if direction.length_squared() <= EPSILON:
		direction = Vector2.from_angle(battle.random_range(0.0, TAU))
	direction = direction.normalized().rotated(deg_to_rad(battle.random_range(
		-settingf("purple_direction_jitter_degrees"), settingf("purple_direction_jitter_degrees")
	)))
	var purple: BallEntity = TechniqueOrbEntity.new(side, fusion_position, {
		"kind": PURPLE,
		"velocity": direction * settingf("purple_speed"),
		"radius": settingf("purple_radius"),
		"damage": settingf("purple_damage"),
		"duration": settingf("purple_lifetime"),
		"purple_erase_radius": settingf("purple_erase_radius"),
		"purple_explosion_radius": settingf("purple_explosion_radius"),
		"purple_explosion_duration": settingf("purple_explosion_duration"),
	})
	purple.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(purple)
	battle.spawn_ring(fusion_position, Color("ff4bb9"), 3.0, settingf("purple_radius") * 7.2, 0.46)
	battle.spawn_ring(fusion_position, Color("65c8ff"), settingf("purple_radius") * 2.7, 4.0, 0.34)
	battle.spawn_particles(fusion_position, Color("e060ff"), 28, 236.0)
	battle.emit_combat_event("split", 0.92)
	_announce_cast(
		battle, fighter, side, "虚式「茈」", "gojo_purple_voice",
		Color("d7a2ff"), settingf("purple_name_duration")
	)
	battle.shake_camera(4.8)
	battle.record_stat("gojo_purple_fusions")

func _should_trigger_unlimited_void(battle, fighter) -> bool:
	if _unlimited_void_used or battle.elapsed < settingf("domain_minimum_elapsed"):
		return false
	var trigger_range := settingf("domain_trigger_range")
	for hostile in battle.hostile_fighters(fighter.team_id):
		if hostile.pos.distance_to(fighter.pos) <= trigger_range + hostile.radius:
			return true
	return false

func _trigger_unlimited_void(battle, fighter, side: int) -> void:
	_unlimited_void_used = true
	_domain_flash_remaining = settingf("domain_duration")
	var domain: BallEntity = UnlimitedVoidEntity.new(side, fighter, {
		"radius": settingf("domain_radius"),
		"duration": settingf("domain_duration"),
		"damage_per_tick": settingf("domain_damage_per_tick"),
		"tick_interval": settingf("domain_tick_interval"),
	})
	battle.add_entity(domain)
	fighter.ability_timer = maxf(fighter.ability_timer, settingf("domain_duration"))
	_announce_cast(
		battle, fighter, side, "领域展开「无量空处」", "gojo_domain_voice",
		Color("d9f5ff"), settingf("domain_name_duration")
	)
	battle.spawn_ring(fighter.pos, Color("8062ff"), fighter.radius, settingf("domain_radius"), 0.72)
	battle.spawn_particles(fighter.pos, Color("dcecff"), 28, 188.0)
	battle.emit_combat_event("judgment", 1.0)
	battle.shake_camera(7.0)
	battle.record_stat("gojo_unlimited_void_uses")

func _announce_cast(
	battle,
	fighter,
	side: int,
	title: String,
	voice_event: String,
	color: Color,
	duration: float
) -> void:
	var label: BallEntity = NamedCastVfx.new(
		side, fighter, title, duration, color, fighter.accent
	)
	battle.add_entity(label)
	battle.emit_combat_event(voice_event, 1.0)

func _owned_orbs(battle, fighter_uid: int, kind: String) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for orb: BallEntity in battle.entities(-1, "gojo_orb_%s" % kind):
		if orb.owner_fighter_uid == fighter_uid:
			result.append(orb)
	return result

func _trim_owned_orbs(battle, fighter_uid: int, kind: String, maximum_count: int) -> void:
	var owned := _owned_orbs(battle, fighter_uid, kind)
	while owned.size() >= maxi(1, maximum_count):
		owned.pop_front().removed = true

func _maximum_for_kind(kind: String) -> int:
	return settingi("maximum_blue_orbs") if kind == BLUE else settingi("maximum_red_orbs")

func _damage_for_kind(kind: String) -> float:
	return settingf("blue_damage") if kind == BLUE else settingf("red_damage")

func _speed_for_kind(kind: String) -> float:
	return settingf("blue_speed") if kind == BLUE else settingf("red_speed")

func _radius_for_kind(kind: String) -> float:
	return settingf("blue_radius") if kind == BLUE else settingf("red_radius")

func _lifetime_for_kind(kind: String) -> float:
	return settingf("blue_lifetime") if kind == BLUE else settingf("red_lifetime")

func _color_for_kind(kind: String) -> Color:
	return Color("45dfff") if kind == BLUE else Color("ff4059")
