extends BallAbility

var _orbit_angle := 0.0

func before_motion(battle, _fighter, _opponent, side: int, delta: float) -> void:
	_orbit_angle = fmod(_orbit_angle + delta * 2.56 * (-1.0 if side == 0 else 1.0), TAU)

func orbit_angle() -> float:
	return _orbit_angle

func cooldown_duration(_battle, fighter) -> float:
	return fighter.cooldown

func activate(battle, fighter, opponent, side: int) -> void:
	var hammer_head: Vector2 = fighter.pos + Vector2.from_angle(_orbit_angle) * 118.0
	battle.spawn_ring(hammer_head, fighter.accent, 8.0, 62.0, 0.3)
	var hit_something := false
	if hammer_head.distance_to(opponent.pos) < opponent.radius + 48.0 or fighter.pos.distance_to(opponent.pos) < 158.0:
		battle.damage(opponent, 14.2, fighter.accent, fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities(side):
		if hammer_head.distance_to(entity.pos) < entity.radius + 48.0 or fighter.pos.distance_to(entity.pos) < entity.radius + 158.0:
			battle.damage_entity(entity, 14.2, fighter.accent, side)
			hit_something = true
	if hit_something:
		battle.record_stat("heavy_hits")
		battle.shake_camera(7.0)
		battle.spawn_particles(hammer_head, fighter.accent, 14, 190.0)
