extends BallAbility

const AnchorEntity := preload("res://scripts/balls/six_king/anchor_entity.gd")

func activate(battle, fighter, opponent, side: int) -> void:
	var arena_size: Vector2 = battle.arena_size()
	var edge_margin := settingf("anchor_edge_margin")
	var edge_inset := settingf("anchor_edge_inset")
	var side_inset := arena_size.y * settingf("anchor_side_inset_ratio")
	var edge_points := [
		Vector2(edge_inset, edge_margin),
		Vector2(arena_size.x * 0.5, edge_margin),
		Vector2(arena_size.x - edge_inset, edge_margin),
		Vector2(arena_size.x - edge_margin, side_inset),
		Vector2(arena_size.x - edge_margin, arena_size.y - side_inset),
		Vector2(arena_size.x * 0.5, arena_size.y - edge_margin),
	]
	var tether_targets := {}
	for index in range(settingi("anchor_count")):
		var point: Vector2 = edge_points[(index + side * 2) % edge_points.size()]
		battle.add_entity(AnchorEntity.new(side, point, settingf("anchor_duration")))
		battle.add_beam(point, fighter.pos, fighter.accent, 0.75, 2.5)
		for entity: BallEntity in battle.damageable_entities_on_segment(side, point, fighter.pos, settingf("anchor_hit_width")):
			tether_targets[entity.get_instance_id()] = entity
	battle.spawn_ring(fighter.pos, Color("ffe052"), 20.0, 176.0, 0.8)
	var damage := settingf("judgment_damage")
	battle.damage(opponent, damage, fighter.accent, fighter)
	for entity: BallEntity in tether_targets.values():
		battle.damage_entity(entity, damage, fighter.accent, side)
