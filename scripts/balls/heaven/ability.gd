extends BallAbility

const InvulnerabilityEffect := preload("res://scripts/balls/heaven/invulnerability_effect.gd")

func activate(battle, fighter, opponent, side: int) -> void:
	battle.apply_status(fighter, InvulnerabilityEffect.new(0.85, side, fighter.accent))
	var offset: Vector2 = opponent.pos - fighter.pos
	var direction := offset.normalized()
	fighter.velocity = direction * 540.0
	battle.add_beam(fighter.pos, opponent.pos, fighter.accent, 0.35, 8.0)
	battle.spawn_ring(fighter.pos, Color("fff1a1"), fighter.radius, 130.0, 0.5)
	if offset.length() < 270.0:
		battle.damage(opponent, 14.0, fighter.accent, fighter)
	var strike_end: Vector2 = fighter.pos + direction * minf(offset.length(), 270.0)
	for entity: BallEntity in battle.damageable_entities_on_segment(side, fighter.pos, strike_end, 4.0):
		battle.damage_entity(entity, 14.0, fighter.accent, side)
