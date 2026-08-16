extends BallAbility

const CloneEntity := preload("res://scripts/balls/replicator/clone_entity.gd")

var _orbit_angle := 0.0

func before_motion(_battle, _fighter, _opponent, side: int, delta: float) -> void:
	_orbit_angle = fmod(_orbit_angle + delta * settingf("orbit_speed") * (-1.0 if side == 0 else 1.0), TAU)

func orbit_angle() -> float:
	return _orbit_angle

func max_cannons() -> int:
	return settingi("max_cannons")

func inner_ring_capacity() -> int:
	return mini(settingi("inner_ring_capacity"), max_cannons())

func inner_orbit_radius() -> float:
	return settingf("inner_orbit_radius")

func outer_orbit_radius() -> float:
	return settingf("outer_orbit_radius")

func cannon_radius_scale() -> float:
	return settingf("cannon_radius_scale")

func on_step(battle, _fighter, _opponent, side: int, _delta: float) -> void:
	_sync_formation(battle, side)

func activate(battle, fighter, opponent, side: int) -> void:
	var cannon_count: int = battle.count_entities(side, "clone")
	if cannon_count < max_cannons():
		battle.add_entity(CloneEntity.new(side, fighter, self))
		battle.record_stat("clones_spawned")
	var cannons: Array[BallEntity] = _sync_formation(battle, side)
	_fire_projectile(battle, fighter, opponent, side, fighter.pos)
	for cannon: BallEntity in cannons:
		_fire_projectile(battle, fighter, opponent, side, cannon.pos)
	var volley_strength := 0.5 + 0.32 * float(cannons.size()) / float(max_cannons())
	battle.emit_combat_event("volley", volley_strength)
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 100.0, 0.45)

func _sync_formation(battle, side: int) -> Array[BallEntity]:
	var cannons: Array[BallEntity] = battle.entities(side, "clone")
	for index in range(cannons.size()):
		cannons[index].call("set_formation_slot", index, cannons.size())
	return cannons

func _fire_projectile(battle, fighter, opponent, side: int, origin: Vector2) -> void:
	var spread := settingf("projectile_spread")
	var direction: Vector2 = (opponent.pos - origin).normalized().rotated(battle.random_range(-spread, spread))
	battle.add_projectile(
		side,
		origin,
		direction * settingf("projectile_speed"),
		settingf("projectile_radius"),
		settingf("projectile_damage"),
		fighter.accent,
		settingf("projectile_lifetime"),
		"copy"
	)
