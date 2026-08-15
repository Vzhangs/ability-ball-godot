extends BallAbility

func activate(battle, fighter, opponent, _side: int) -> void:
	var direction: Vector2 = (opponent.pos - fighter.pos).normalized()
	var endpoint: Vector2 = battle.ray_to_arena_edge(fighter.pos, direction)
	battle.add_beam(fighter.pos, endpoint, fighter.accent, 0.62, 10.0)
	battle.add_beam(fighter.pos, endpoint, Color.WHITE, 0.34, 3.0)
	battle.damage(opponent, 16.0 + battle.phase * 2.3, fighter.accent, fighter)
	battle.shake_camera(5.0)
