extends BallAbility

func contact_damage(_battle, _fighter, _opponent, base_damage: float) -> float:
	return base_damage + 2.5

func cooldown_duration(_battle, fighter) -> float:
	return fighter.cooldown

func activate(battle, fighter, opponent, _side: int) -> void:
	var hammer_head: Vector2 = fighter.pos + Vector2.from_angle(fighter.aux_angle) * 118.0
	battle.spawn_ring(hammer_head, fighter.accent, 8.0, 62.0, 0.3)
	if hammer_head.distance_to(opponent.pos) < opponent.radius + 48.0 or fighter.pos.distance_to(opponent.pos) < 158.0:
		battle.damage(opponent, 11.0 + battle.phase * 1.6, fighter.accent, fighter)
		battle.record_stat("heavy_hits")
		battle.shake_camera(7.0)
		battle.spawn_particles(hammer_head, fighter.accent, 14, 190.0)
