extends BallAbility

var _blood_burst_timer := 0.0
var _dash_timer := 0.0

func automatic_activation_enabled() -> bool:
	return false

func on_battle_started(_battle, _fighter, _opponent, _side: int) -> void:
	_blood_burst_timer = settingf("showcase_burst_initial_delay")
	_dash_timer = settingf("showcase_dash_initial_delay")

func before_motion(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_blood_burst_timer -= delta
	_dash_timer -= delta

func on_step(battle, fighter, opponent, side: int, _delta: float) -> void:
	if _dash_timer <= 0.0:
		_dash_timer = settingf("showcase_dash_interval")
		var direction: Vector2 = (opponent.pos - fighter.pos).normalized()
		var spread := settingf("showcase_dash_spread")
		fighter.velocity = direction.rotated(battle.random_range(-spread, spread)) * settingf("showcase_dash_speed")
		battle.spawn_ring(fighter.pos, Color("d71933"), 18.0, 92.0, 0.35)
		battle.spawn_particles(fighter.pos, Color("ff304e"), 14, 180.0)

	if _blood_burst_timer <= 0.0:
		_blood_burst_timer = settingf("showcase_burst_interval")
		battle.record_stat("blood_bursts")
		battle.emit_combat_event("blood", 0.7)
		battle.spawn_ring(fighter.pos, Color("b90028"), fighter.radius, 138.0, 0.7)
		battle.spawn_particles(fighter.pos, Color("d40f38"), 24, 225.0)
		var hit_something := false
		var burst_radius := settingf("showcase_burst_radius")
		var burst_damage := settingf("showcase_burst_damage")
		if fighter.pos.distance_to(opponent.pos) <= burst_radius:
			battle.damage(opponent, burst_damage, Color("ff4054"), fighter)
			hit_something = true
		for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, burst_radius):
			battle.damage_entity(entity, burst_damage, Color("ff4054"), side)
			hit_something = true
		if hit_something:
			battle.heal(fighter, settingf("showcase_burst_heal"))

func contact_damage(_battle, _fighter, _opponent) -> float:
	return settingf("showcase_impact_damage")

func after_contact(battle, fighter, _opponent, damage_dealt: float) -> void:
	if damage_dealt > 0.0:
		battle.heal(fighter, settingf("showcase_impact_heal"))
