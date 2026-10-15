extends BallAbility

const TankEntityScript := preload("res://scripts/balls/heavy_industry/tank_entity.gd")

var _port_angle := 0.0
var _spawned_tanks: Array[WeakRef] = []
var _deployment_animation_duration := 0.0
var _deployment_animation_remaining := 0.0
var _battle_context
var _owner_side := -1

func on_battle_started(battle, fighter, _opponent, side: int) -> void:
	_battle_context = battle
	_owner_side = side
	_port_angle = 0.0 if side == 0 else PI
	_deployment_animation_duration = settingf("deployment_animation_duration")
	_deployment_animation_remaining = 0.0
	fighter.ability_timer = fighter.cooldown

func automatic_activation_enabled() -> bool:
	return (
		_battle_context != null
		and _owner_side >= 0
		and _battle_context.count_entities(_owner_side, "heavy_tank") < settingi("max_tanks")
	)

func before_motion(_battle, _fighter, _opponent, side: int, delta: float) -> void:
	var rotation_delta := delta
	if _deployment_animation_remaining > 0.0:
		var animation_delta := minf(rotation_delta, _deployment_animation_remaining)
		_deployment_animation_remaining = maxf(
			0.0,
			_deployment_animation_remaining - animation_delta
		)
		rotation_delta -= animation_delta
	if rotation_delta <= 0.0:
		return
	var direction_sign := 1.0 if side == 0 else -1.0
	_port_angle = fmod(
		_port_angle + settingf("port_rotation_speed") * direction_sign * rotation_delta,
		TAU
	)

func port_angle() -> float:
	return _port_angle

func active_tank_count() -> int:
	return _active_spawned_tanks().size()

func deployment_animation_active() -> bool:
	return _deployment_animation_remaining > 0.0

func deployment_animation_progress() -> float:
	if _deployment_animation_duration <= 0.0:
		return 1.0
	return clampf(
		1.0 - _deployment_animation_remaining / _deployment_animation_duration,
		0.0,
		1.0
	)

func deployment_gate_open_amount() -> float:
	if not deployment_animation_active():
		return 0.0
	var progress := deployment_animation_progress()
	if progress < 0.25:
		return _smoothstep01(progress / 0.25)
	if progress <= 0.72:
		return 1.0
	return 1.0 - _smoothstep01((progress - 0.72) / 0.28)

func activate(battle, fighter, _opponent, side: int) -> void:
	if battle.count_entities(side, "heavy_tank") >= settingi("max_tanks"):
		return
	_deployment_animation_duration = settingf("deployment_animation_duration")
	_deployment_animation_remaining = _deployment_animation_duration
	var spawn_direction := Vector2.from_angle(_port_angle)
	var tank_radius := settingf("tank_radius")
	var spawn_position: Vector2 = fighter.pos + spawn_direction * (
		fighter.radius + tank_radius + settingf("tank_spawn_gap")
	)
	var arena_size: Vector2 = battle.arena_size()
	spawn_position.x = clampf(spawn_position.x, tank_radius, arena_size.x - tank_radius)
	spawn_position.y = clampf(spawn_position.y, tank_radius, arena_size.y - tank_radius)
	var tank: BallEntity = TankEntityScript.new(
		side,
		spawn_position,
		spawn_direction,
		fighter.color,
		fighter.accent,
		{
			"max_hp": settingf("tank_max_hp"),
			"radius": tank_radius,
			"speed": settingf("tank_speed"),
			"contact_damage": settingf("tank_contact_damage"),
			"contact_interval": settingf("tank_contact_interval"),
			"turret_rotation_speed": settingf("turret_rotation_speed"),
			"fire_interval": settingf("tank_fire_interval"),
			"shell_damage": settingf("shell_damage"),
			"shell_speed": settingf("shell_speed"),
			"shell_radius": settingf("shell_radius"),
			"shell_lifetime": settingf("shell_lifetime"),
			"shell_spawn_gap": settingf("shell_spawn_gap"),
			"deployment_duration": settingf("deployment_animation_duration"),
		}
	)
	battle.add_entity(tank)
	_spawned_tanks.append(weakref(tank))
	battle.record_stat("heavy_tanks_deployed")
	battle.spawn_ring(spawn_position, fighter.accent, tank_radius * 0.5, tank_radius * 2.4, 0.38)
	battle.spawn_particles(spawn_position, fighter.accent, 9, 112.0)

func after_entities_step(battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	var tanks := _active_spawned_tanks()
	var candidates: Array[BallEntity] = battle.entities()
	for tank: BallEntity in tanks:
		if tank.removed or tank.is_captured():
			continue
		for candidate: BallEntity in candidates:
			if (
				candidate == tank
				or candidate.removed
				or candidate.is_captured()
				or not candidate.participates_in_entity_collision()
			):
				continue
			# A pair of tanks is resolved by the lower instance ID exactly once, even
			# when both sides use this same module and own separate ability instances.
			if (
				candidate.has_tag("heavy_tank")
				and tank.get_instance_id() > candidate.get_instance_id()
			):
				continue
			tank.call("resolve_entity_collision", battle, candidate)

func _active_spawned_tanks() -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for index in range(_spawned_tanks.size() - 1, -1, -1):
		var tank: BallEntity = _spawned_tanks[index].get_ref()
		if tank == null or tank.removed:
			_spawned_tanks.remove_at(index)
			continue
		result.append(tank)
	return result

func _smoothstep01(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
