extends BallAbility

func speed_multiplier(battle, _fighter, _opponent, _side: int) -> float:
	var shared_multiplier: float = 1.0 + float(battle.phase - 1) * 0.08
	return (shared_multiplier + minf(0.72, battle.elapsed * 0.012)) / shared_multiplier

func contact_damage(_battle, fighter, _opponent, base_damage: float) -> float:
	return base_damage + clampf((fighter.velocity.length() - 220.0) * 0.035, 0.0, 10.0)

func activate(battle, fighter, opponent, _side: int) -> void:
	fighter.velocity = (opponent.pos - fighter.pos).normalized().rotated(battle.random_range(-0.08, 0.08)) * (560.0 + battle.phase * 35.0)
	battle.spawn_ring(fighter.pos, fighter.accent, 10.0, 180.0, 0.45)
	battle.spawn_ring(fighter.pos, Color.WHITE, 20.0, 118.0, 0.32)
	battle.spawn_particles(fighter.pos, fighter.accent, 18, 230.0)
	if fighter.pos.distance_to(opponent.pos) < 300.0:
		battle.damage(opponent, 6.0 + battle.phase * 1.5, fighter.accent, fighter)
