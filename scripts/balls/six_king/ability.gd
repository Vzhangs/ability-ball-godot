extends BallAbility

const AnchorEntity := preload("res://scripts/balls/six_king/anchor_entity.gd")

func activate(battle, fighter, opponent, side: int) -> void:
	var edge_points := [
		Vector2(70.0, 6.0), Vector2(320.0, 6.0), Vector2(570.0, 6.0),
		Vector2(634.0, 160.0), Vector2(634.0, 480.0), Vector2(320.0, 634.0),
	]
	var tether_targets := {}
	for index in range(edge_points.size()):
		var point: Vector2 = edge_points[(index + side * 2) % edge_points.size()]
		battle.add_entity(AnchorEntity.new(side, point, 1.15))
		battle.add_beam(point, fighter.pos, fighter.accent, 0.75, 2.5)
		for entity: BallEntity in battle.damageable_entities_on_segment(side, point, fighter.pos, 1.25):
			tether_targets[entity.get_instance_id()] = entity
	battle.spawn_ring(fighter.pos, Color("ffe052"), 20.0, 176.0, 0.8)
	battle.damage(opponent, 11.4, fighter.accent, fighter)
	for entity: BallEntity in tether_targets.values():
		battle.damage_entity(entity, 11.4, fighter.accent, side)
