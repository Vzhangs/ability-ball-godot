extends BallAbility

func speed_multiplier(battle, _fighter, _opponent, _side: int) -> float:
	return 1.0 + minf(0.72, battle.elapsed * 0.012)

func contact_damage(_battle, fighter, _opponent) -> float:
	return 12.25 + clampf((fighter.velocity.length() - 220.0) * 0.035, 0.0, 10.0)

func activate(battle, fighter, opponent, side: int) -> void:
	fighter.velocity = (opponent.pos - fighter.pos).normalized().rotated(battle.random_range(-0.08, 0.08)) * 630.0
	battle.spawn_ring(fighter.pos, fighter.accent, 10.0, 180.0, 0.45)
	battle.spawn_ring(fighter.pos, Color.WHITE, 20.0, 118.0, 0.32)
	battle.spawn_particles(fighter.pos, fighter.accent, 18, 230.0)
	if fighter.pos.distance_to(opponent.pos) < 300.0:
		battle.damage(opponent, 9.0, fighter.accent, fighter)
	for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, 300.0):
		battle.damage_entity(entity, 9.0, fighter.accent, side)
