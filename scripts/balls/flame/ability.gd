extends BallAbility

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	if int(battle.elapsed * 8.0) != int((battle.elapsed - delta) * 8.0):
		battle.add_fire_zone(side, fighter.pos, 2.5, 22.0 + battle.phase * 3.0)
	if fighter.secondary_timer > 0.0:
		return
	if battle.fire_zone_hits(side, opponent):
		fighter.secondary_timer = 0.34
		battle.damage(opponent, 2.2 + battle.phase * 0.6, fighter.accent, fighter, false)
		battle.record_stat("burn_hits")

func activate(battle, fighter, opponent, _side: int) -> void:
	battle.spawn_ring(fighter.pos, Color("ff7a24"), fighter.radius, 158.0, 0.72)
	battle.spawn_particles(fighter.pos, Color("ffbd35"), 24, 235.0)
	if fighter.pos.distance_to(opponent.pos) < 195.0:
		battle.damage(opponent, 10.0 + battle.phase * 1.7, fighter.accent, fighter)
		battle.record_stat("burn_hits")
