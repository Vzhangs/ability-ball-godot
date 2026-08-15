extends BallAbility

func activate(battle, fighter, opponent, side: int) -> void:
	var edge_points := [
		Vector2(70.0, 6.0), Vector2(320.0, 6.0), Vector2(570.0, 6.0),
		Vector2(634.0, 160.0), Vector2(634.0, 480.0), Vector2(320.0, 634.0),
	]
	for index in range(edge_points.size()):
		var point: Vector2 = edge_points[(index + side * 2) % edge_points.size()]
		battle.add_anchor(side, point, 1.15)
		battle.add_beam(point, fighter.pos, fighter.accent, 0.75, 2.5)
	battle.spawn_ring(fighter.pos, Color("ffe052"), 20.0, 176.0, 0.8)
	battle.damage(opponent, 7.0 + battle.phase * 2.2, fighter.accent, fighter)
