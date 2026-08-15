extends BallAbility

func activate(battle, fighter, opponent, side: int) -> void:
	var previous: int = fighter.clone_count
	fighter.clone_count = mini(6, fighter.clone_count + 1)
	battle.record_clone_spawn(fighter.clone_count - previous)
	for index in range(fighter.clone_count + 1):
		var angle: float = fighter.aux_angle + TAU * float(index) / float(fighter.clone_count + 1)
		var origin: Vector2 = fighter.pos + Vector2.from_angle(angle) * (48.0 + fighter.clone_count * 3.0)
		var direction: Vector2 = (opponent.pos - origin).normalized().rotated(battle.random_range(-0.1, 0.1))
		battle.add_projectile(side, origin, direction * 305.0, 5.0, 4.5 + battle.phase * 0.8, fighter.accent, 2.2, "copy")
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 100.0, 0.45)
