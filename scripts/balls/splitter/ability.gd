extends BallAbility

func activate(battle, fighter, _opponent, _side: int) -> void:
	var amount: int = 2 if battle.phase == 1 else 3
	var previous: int = fighter.clone_count
	fighter.clone_count = mini(8, fighter.clone_count + amount)
	battle.record_clone_spawn(fighter.clone_count - previous)
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 112.0, 0.55)
	battle.spawn_particles(fighter.pos, fighter.color, 8 + fighter.clone_count, 150.0)
	battle.spawn_text("×%d" % (fighter.clone_count + 1), fighter.pos + Vector2(0.0, -45.0), fighter.accent, 0.9)

func contact_damage(_battle, fighter, _opponent, base_damage: float) -> float:
	return base_damage + fighter.clone_count * 0.75

func after_damage_dealt(battle, fighter, _opponent, amount: float) -> void:
	if amount <= 0.0 or battle.random_float() >= 0.22:
		return
	var previous: int = fighter.clone_count
	fighter.clone_count = mini(8, fighter.clone_count + 1)
	battle.record_clone_spawn(fighter.clone_count - previous)
