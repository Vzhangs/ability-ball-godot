extends BallAbility

func activate(battle, fighter, opponent, side: int) -> void:
	var direction: Vector2 = (opponent.pos - fighter.pos).normalized()
	var endpoint: Vector2 = battle.ray_to_arena_edge(fighter.pos, direction)
	battle.add_beam(fighter.pos, endpoint, fighter.accent, 0.62, 10.0)
	battle.add_beam(fighter.pos, endpoint, Color.WHITE, 0.34, 3.0)
	battle.damage(opponent, 20.6, fighter.accent, fighter)
	for entity: BallEntity in battle.damageable_entities_on_segment(side, fighter.pos, endpoint, 5.0):
		battle.damage_entity(entity, 20.6, fighter.accent, side)
	battle.shake_camera(5.0)
