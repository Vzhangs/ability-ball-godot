extends BallAbility

const CloneEntity := preload("res://scripts/balls/replicator/clone_entity.gd")

var _orbit_angle := 0.0
var _spawned_cannons: Array[WeakRef] = []

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

func on_step(_battle, _fighter, _opponent, side: int, _delta: float) -> void:
	_sync_formation(side)

func activate(battle, fighter, opponent, side: int) -> void:
	var cannon_count: int = _owned_spawned_cannons(side).size()
	if cannon_count < max_cannons():
		var cannon: BallEntity = CloneEntity.new(side, fighter, self)
		battle.add_entity(cannon)
		_spawned_cannons.append(weakref(cannon))
		battle.record_stat("clones_spawned")
	_sync_formation(side)
	_fire_projectile(battle, fighter, opponent, side, fighter.pos)
	var firing_cannons: Array[BallEntity] = _active_spawned_cannons()
	for cannon: BallEntity in firing_cannons:
		var cannon_fighter = battle.owner_for_entity(cannon)
		var cannon_opponent = battle.opponent_for_entity(cannon)
		if cannon_fighter == null or cannon_opponent == null:
			continue
		_fire_projectile(
			battle,
			cannon_fighter,
			cannon_opponent,
			cannon.owner_side,
			cannon.pos,
			cannon
		)
	var volley_ratio := minf(1.0, float(firing_cannons.size()) / float(max_cannons()))
	var volley_strength := 0.5 + 0.32 * volley_ratio
	battle.emit_combat_event("volley", volley_strength)
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 100.0, 0.45)

func _sync_formation(side: int) -> Array[BallEntity]:
	var cannons: Array[BallEntity] = _owned_spawned_cannons(side)
	for index in range(cannons.size()):
		cannons[index].call("set_formation_slot", index, cannons.size())
	return cannons

func _owned_spawned_cannons(side: int) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for cannon: BallEntity in _active_spawned_cannons():
		if cannon.owner_side == side:
			result.append(cannon)
	return result

func _active_spawned_cannons() -> Array[BallEntity]:
	for index in range(_spawned_cannons.size() - 1, -1, -1):
		var cannon: BallEntity = _spawned_cannons[index].get_ref()
		if cannon == null or cannon.removed:
			_spawned_cannons.remove_at(index)
	var result: Array[BallEntity] = []
	for cannon_ref: WeakRef in _spawned_cannons:
		var cannon: BallEntity = cannon_ref.get_ref()
		if cannon != null:
			result.append(cannon)
	return result

func _fire_projectile(battle, fighter, opponent, side: int, origin: Vector2, source_cannon: BallEntity = null) -> void:
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
		"copy",
		source_cannon
	)
