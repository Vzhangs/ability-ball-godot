extends BallAbility

var _blood_burst_timer := 5.4
var _dash_timer := 2.6

func automatic_activation_enabled() -> bool:
	return false

func before_motion(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_blood_burst_timer -= delta
	_dash_timer -= delta

func on_step(battle, fighter, opponent, side: int, _delta: float) -> void:
	if _dash_timer <= 0.0:
		_dash_timer = 3.6
		var direction: Vector2 = (opponent.pos - fighter.pos).normalized()
		fighter.velocity = direction.rotated(battle.random_range(-0.16, 0.16)) * 446.0
		battle.spawn_ring(fighter.pos, Color("d71933"), 18.0, 92.0, 0.35)
		battle.spawn_particles(fighter.pos, Color("ff304e"), 14, 180.0)

	if _blood_burst_timer <= 0.0:
		_blood_burst_timer = 5.5
		battle.record_stat("blood_bursts")
		battle.emit_combat_event("blood", 0.7)
		battle.spawn_ring(fighter.pos, Color("b90028"), fighter.radius, 138.0, 0.7)
		battle.spawn_particles(fighter.pos, Color("d40f38"), 24, 225.0)
		var hit_something := false
		if fighter.pos.distance_to(opponent.pos) <= 142.0:
			battle.damage(opponent, 2.0, Color("ff4054"), fighter)
			hit_something = true
		for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, 142.0):
			battle.damage_entity(entity, 2.0, Color("ff4054"), side)
			hit_something = true
		if hit_something:
			battle.heal(fighter, 9.0)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 5.0

func after_contact(battle, fighter, _opponent, damage_dealt: float) -> void:
	if damage_dealt > 0.0:
		battle.heal(fighter, 3.0)
