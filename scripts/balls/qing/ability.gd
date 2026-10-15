extends BallAbility

const Drone := preload("res://scripts/balls/qing/athena_entity.gd")
var _deployment_available := true

func on_battle_started(_battle, fighter, _opponent, _side: int) -> void:
	fighter.ability_timer = fighter.cooldown
	_deployment_available = true

func automatic_activation_enabled() -> bool:
	return _deployment_available

func on_step(battle, fighter, _opponent, side: int, _delta: float) -> void:
	var count := 0
	for drone: BallEntity in battle.entities(side, "qing_athena"):
		if drone.owner_fighter_uid == fighter.fighter_uid:
			count += 1
	_deployment_available = count < settingi("max_drones")

func activate(battle, fighter, _opponent, side: int) -> void:
	on_step(battle, fighter, _opponent, side, 0.0)
	if not _deployment_available: return
	var direction := Vector2.from_angle(battle.random_range(0.0, TAU))
	var r := settingf("drone_radius")
	var position: Vector2 = fighter.pos + direction * (fighter.radius + r + settingf("spawn_gap"))
	var size: Vector2 = battle.arena_size()
	position = position.clamp(Vector2.ONE * r, size - Vector2.ONE * r)
	var config := {}
	for key in ["drone_hp", "drone_radius", "drone_speed", "contact_interval", "arc_damage", "arc_interval", "arc_half_width", "paralysis_duration", "arc_charge_time", "deploy_duration"]:
		config[key] = setting(key)
	var drone := Drone.new(side, position, direction * settingf("drone_speed"), config)
	drone.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(drone)
	battle.spawn_ring(position, fighter.accent, r * 0.3, r * 2.0, settingf("deploy_duration"))
	battle.emit_combat_event("split", 0.5)
	battle.record_stat("qing_deployments")
