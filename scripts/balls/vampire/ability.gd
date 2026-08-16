extends BallAbility

func activate(battle, fighter, opponent, side: int) -> void:
	var burst_radius := settingf("burst_radius")
	var burst_damage := settingf("burst_damage")
	battle.spawn_ring(fighter.pos, Color("df1538"), fighter.radius, 145.0, 0.7)
	battle.spawn_particles(fighter.pos, Color("ff3454"), 20, 205.0)
	var hit_something := false
	if fighter.pos.distance_to(opponent.pos) < burst_radius:
		battle.damage(opponent, burst_damage, fighter.accent, fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, burst_radius):
		battle.damage_entity(entity, burst_damage, fighter.accent, side)
		hit_something = true
	if hit_something:
		battle.heal(fighter, settingf("burst_heal"))

func contact_damage(_battle, _fighter, _opponent) -> float:
	return settingf("body_impact_damage")

func after_contact(battle, fighter, _opponent, damage_dealt: float) -> void:
	battle.heal(fighter, damage_dealt * settingf("impact_lifesteal_ratio"))
