extends BallAbility

func speed_multiplier(battle, _fighter, _opponent, _side: int) -> float:
	return 1.0 + minf(settingf("speed_bonus_cap"), battle.elapsed * settingf("speed_bonus_per_second"))

func contact_damage(_battle, fighter, _opponent) -> float:
	var bonus: float = (fighter.velocity.length() - settingf("impact_speed_threshold")) * settingf("impact_damage_per_speed")
	return settingf("body_impact_damage") + clampf(bonus, 0.0, settingf("impact_bonus_damage_cap"))

func activate(battle, fighter, opponent, side: int) -> void:
	var blast_radius := settingf("sonic_blast_radius")
	var blast_damage := settingf("sonic_blast_damage")
	var spread := settingf("dash_spread")
	fighter.velocity = (opponent.pos - fighter.pos).normalized().rotated(battle.random_range(-spread, spread)) * settingf("dash_speed")
	battle.spawn_ring(fighter.pos, fighter.accent, 10.0, 180.0, 0.45)
	battle.spawn_ring(fighter.pos, Color.WHITE, 20.0, 118.0, 0.32)
	battle.spawn_particles(fighter.pos, fighter.accent, 18, 230.0)
	if fighter.pos.distance_to(opponent.pos) < blast_radius:
		battle.damage(opponent, blast_damage, fighter.accent, fighter)
	for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, blast_radius):
		battle.damage_entity(entity, blast_damage, fighter.accent, side)
