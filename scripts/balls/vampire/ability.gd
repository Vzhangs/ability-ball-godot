extends BallAbility

func activate(battle, fighter, opponent, _side: int) -> void:
	battle.spawn_ring(fighter.pos, Color("df1538"), fighter.radius, 145.0, 0.7)
	battle.spawn_particles(fighter.pos, Color("ff3454"), 20, 205.0)
	if fighter.pos.distance_to(opponent.pos) < 155.0:
		battle.damage(opponent, 10.0 + battle.phase * 2.0, fighter.accent, fighter)
		battle.heal(fighter, 8.0 + battle.phase * 2.0)

func after_contact(battle, fighter, _opponent, damage_dealt: float) -> void:
	battle.heal(fighter, damage_dealt * 0.34)
