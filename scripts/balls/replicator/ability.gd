extends BallAbility

const CloneEntity := preload("res://scripts/balls/replicator/clone_entity.gd")

const MAX_CANNONS := CloneEntity.MAX_CANNONS

var _orbit_angle := 0.0

func before_motion(_battle, _fighter, _opponent, side: int, delta: float) -> void:
	_orbit_angle = fmod(_orbit_angle + delta * 2.56 * (-1.0 if side == 0 else 1.0), TAU)

func orbit_angle() -> float:
	return _orbit_angle

func on_step(battle, _fighter, _opponent, side: int, _delta: float) -> void:
	_sync_formation(battle, side)

func activate(battle, fighter, opponent, side: int) -> void:
	var cannon_count: int = battle.count_entities(side, "clone")
	if cannon_count < MAX_CANNONS:
		battle.add_entity(CloneEntity.new(side, fighter, self))
		battle.record_stat("clones_spawned")
	var cannons: Array[BallEntity] = _sync_formation(battle, side)
	_fire_projectile(battle, fighter, opponent, side, fighter.pos)
	for cannon: BallEntity in cannons:
		_fire_projectile(battle, fighter, opponent, side, cannon.pos)
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 100.0, 0.45)

func _sync_formation(battle, side: int) -> Array[BallEntity]:
	var cannons: Array[BallEntity] = battle.entities(side, "clone")
	for index in range(cannons.size()):
		cannons[index].call("set_formation_slot", index, cannons.size())
	return cannons

func _fire_projectile(battle, fighter, opponent, side: int, origin: Vector2) -> void:
	var direction: Vector2 = (opponent.pos - origin).normalized().rotated(battle.random_range(-0.1, 0.1))
	battle.add_projectile(side, origin, direction * 305.0, 5.0, 6.1, fighter.accent, 2.2, "copy")
