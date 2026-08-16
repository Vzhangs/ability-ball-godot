extends BallAbility

const InvulnerabilityEffect := preload("res://scripts/balls/heaven/invulnerability_effect.gd")

func activate(battle, fighter, opponent, side: int) -> void:
	var duration := settingf("invulnerability_duration")
	var strike_range := settingf("strike_range")
	var strike_damage := settingf("strike_damage")
	battle.apply_status(fighter, InvulnerabilityEffect.new(duration, side, fighter.accent))
	var offset: Vector2 = opponent.pos - fighter.pos
	var direction := offset.normalized()
	fighter.velocity = direction * settingf("dash_speed")
	battle.add_beam(fighter.pos, opponent.pos, fighter.accent, 0.35, 8.0)
	battle.spawn_ring(fighter.pos, Color("fff1a1"), fighter.radius, 130.0, 0.5)
	if offset.length() < strike_range:
		battle.damage(opponent, strike_damage, fighter.accent, fighter)
	var strike_end: Vector2 = fighter.pos + direction * minf(offset.length(), strike_range)
	for entity: BallEntity in battle.damageable_entities_on_segment(side, fighter.pos, strike_end, settingf("strike_width")):
		battle.damage_entity(entity, strike_damage, fighter.accent, side)
