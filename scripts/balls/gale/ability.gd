extends BallAbility

const Lane := preload("res://scripts/balls/gale/wind_lane_entity.gd")
const Blade := preload("res://scripts/balls/gale/wind_blade_entity.gd")
var _growth := 1.0
var _last_position := Vector2.ZERO
var _contacts := {}

func automatic_activation_enabled() -> bool:
	return false

func on_battle_started(_battle, fighter, _opponent, _side: int) -> void:
	_growth = 1.0
	_last_position = fighter.pos
	_contacts.clear()

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return _growth

func before_motion(_battle, fighter, _opponent, _side: int, _delta: float) -> void:
	for id in _contacts.keys():
		var target = _contacts[id].get_ref()
		if target == null:
			_contacts.erase(id)
			continue
		var gap: float = fighter.radius + target.radius + settingf("separation_margin")
		if (target is BallEntity and (target.removed or target.is_captured())) or fighter.pos.distance_squared_to(target.pos) > gap * gap:
			_contacts.erase(id)

func on_step(battle, fighter, _opponent, _side: int, _delta: float) -> void:
	var candidates: Array = []
	candidates.append_array(battle.active_fighters())
	for entity: BallEntity in battle.entities():
		if entity.participates_in_fighter_collision() or entity.participates_in_entity_collision():
			candidates.append(entity)
	for target in candidates:
		if target == fighter: continue
		var gap: float = fighter.radius + target.radius
		if fighter.pos.distance_squared_to(target.pos) <= gap * gap:
			_contact(battle, fighter, target)
	var offset: Vector2 = fighter.pos - _last_position
	var spacing := settingf("trail_spacing")
	var count := floori(offset.length() / spacing)
	if count <= 0: return
	var direction := offset.normalized()
	var config := _lane_config()
	var lanes: Array[BallEntity] = []
	for lane: BallEntity in battle.entities(fighter.team_id, "gale_lane"):
		if lane.owner_fighter_uid == fighter.fighter_uid: lanes.append(lane)
	for _index in range(count):
		if lanes.size() >= settingi("max_lanes"):
			lanes.pop_front().removed = true
		var end := _last_position + direction * spacing
		var lane := Lane.new(fighter.team_id, _last_position, end, config)
		lane.owner_fighter_uid = fighter.fighter_uid
		if not lanes.is_empty(): lane.set_coordinator(lanes[0])
		battle.add_entity(lane)
		lanes.append(lane)
		_last_position = end

func after_contact(battle, fighter, target, _damage: float) -> void:
	_contact(battle, fighter, target)

func after_entity_contact(battle, fighter, target: BallEntity, _damage: float) -> void:
	_contact(battle, fighter, target)

func _contact(battle, fighter, target) -> void:
	var id: int = target.get_instance_id()
	if _contacts.has(id): return
	_contacts[id] = weakref(target)
	_gain_speed(battle, fighter)

func _gain_speed(battle, fighter) -> void:
	_growth = minf(settingf("maximum_growth"), _growth * (1.0 + settingf("collision_growth")))
	battle.record_stat("gale_accelerations")
	battle.spawn_particles(fighter.pos, fighter.accent, 4, 85.0)

func after_wall_hit(battle, fighter, _opponent, side: int, _position: Vector2) -> bool:
	_gain_speed(battle, fighter)
	var direction: Vector2 = fighter.velocity.normalized()
	if direction.length_squared() < 0.001: return false
	var config := {}
	for key in ["blade_speed", "blade_radius", "blade_duration", "blade_base_damage", "speed_difference_damage", "blade_damage_cap"]:
		config[key] = setting(key)
	var blade := Blade.new(side, fighter.pos + direction * fighter.radius, direction, fighter.velocity.length(), config)
	blade.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(blade)
	battle.emit_combat_event("wind_cast", 0.55)
	battle.record_stat("gale_blades_fired")
	return true

func _lane_config() -> Dictionary:
	var config := {}
	for key in ["lane_half_width", "lane_duration", "friendly_multiplier", "hostile_multiplier", "effect_linger"]:
		config[key] = setting(key)
	return config
