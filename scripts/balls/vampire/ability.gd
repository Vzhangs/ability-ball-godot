extends BallAbility

func activate(battle, fighter, opponent, side: int) -> void:
	battle.spawn_ring(fighter.pos, Color("df1538"), fighter.radius, 145.0, 0.7)
	battle.spawn_particles(fighter.pos, Color("ff3454"), 20, 205.0)
	var hit_something := false
	if fighter.pos.distance_to(opponent.pos) < 155.0:
		battle.damage(opponent, 14.0, fighter.accent, fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, 155.0):
		battle.damage_entity(entity, 14.0, fighter.accent, side)
		hit_something = true
	if hit_something:
		battle.heal(fighter, 12.0)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 11.25

func after_contact(battle, fighter, _opponent, damage_dealt: float) -> void:
	battle.heal(fighter, damage_dealt * 0.34)
