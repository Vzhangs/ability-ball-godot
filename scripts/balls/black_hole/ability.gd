extends BallAbility

func speed_multiplier(_battle, fighter, _opponent, _side: int) -> float:
	return 0.55 if fighter.ability_active > 0.0 else 1.0

func on_step(battle, fighter, opponent, _side: int, delta: float) -> void:
	if fighter.ability_active <= 0.0:
		return
	var pull: Vector2 = fighter.pos - opponent.pos
	var distance: float = maxf(42.0, pull.length())
	opponent.velocity += pull.normalized() * (52000.0 / distance) * delta
	if fighter.secondary_timer <= 0.0 and distance < 235.0:
		fighter.secondary_timer = 0.28
		battle.damage(opponent, 2.5 + battle.phase * 0.7, fighter.accent, fighter, false)

func activate(battle, fighter, _opponent, _side: int) -> void:
	fighter.ability_active = 1.65
	battle.add_gravity_well(fighter.pos, 1.65, 240.0, fighter.accent)
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 240.0, 1.65)
