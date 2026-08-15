extends BallAbility

func activate(battle, fighter, opponent, _side: int) -> void:
	fighter.invulnerable = 0.85
	fighter.shield_flash = 1.0
	fighter.velocity = (opponent.pos - fighter.pos).normalized() * 540.0
	battle.add_beam(fighter.pos, opponent.pos, fighter.accent, 0.35, 8.0)
	battle.spawn_ring(fighter.pos, Color("fff1a1"), fighter.radius, 130.0, 0.5)
	if fighter.pos.distance_to(opponent.pos) < 270.0:
		battle.damage(opponent, 11.0 + battle.phase * 1.5, fighter.accent, fighter)
