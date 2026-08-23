extends BallAbility

const AimIndicatorScript := preload("res://scripts/balls/sniper/aim_indicator_entity.gd")
const SniperRoundScript := preload("res://scripts/balls/sniper/sniper_round_entity.gd")
const RETICLE_COLOR := Color("ff496d")
const RECOIL_DURATION := 0.16

var _aiming := false
var _aim_elapsed := 0.0
var _aim_duration := 1.0
var _gun_direction := Vector2.RIGHT
var _recoil_remaining := 0.0
var _shots_fired := 0

func on_battle_started(_battle, fighter, opponent, _side: int) -> void:
	_update_gun_direction(fighter, opponent)
	fighter.ability_timer = fighter.cooldown

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	_update_gun_direction(fighter, opponent)
	_recoil_remaining = maxf(0.0, _recoil_remaining - delta)
	if not _aiming:
		return
	_aim_elapsed = minf(_aim_duration, _aim_elapsed + delta)
	if _aim_elapsed + 0.00001 < _aim_duration:
		return
	_aiming = false
	_fire(battle, fighter, opponent, side)

func activate(battle, fighter, opponent, side: int) -> void:
	if _aiming:
		return
	_update_gun_direction(fighter, opponent)
	_aim_duration = settingf("aim_duration")
	_aim_elapsed = 0.0
	_aiming = true
	battle.add_entity(AimIndicatorScript.new(
		side,
		_aim_duration,
		fighter.accent,
		RETICLE_COLOR
	))
	battle.spawn_ring(opponent.pos, RETICLE_COLOR, opponent.radius * 1.9, opponent.radius * 1.35, 0.24)
	battle.record_stat("sniper_aims")

func cooldown_duration(_battle, fighter) -> float:
	return maxf(fighter.cooldown, settingf("aim_duration") + 0.05)

func is_aiming() -> bool:
	return _aiming

func aim_progress() -> float:
	if not _aiming or _aim_duration <= 0.0001:
		return 0.0
	return clampf(_aim_elapsed / _aim_duration, 0.0, 1.0)

func gun_direction() -> Vector2:
	return _gun_direction

func recoil_amount() -> float:
	return clampf(_recoil_remaining / RECOIL_DURATION, 0.0, 1.0)

func shots_fired() -> int:
	return _shots_fired

func _fire(battle, fighter, opponent, side: int) -> void:
	_update_gun_direction(fighter, opponent)
	var bullet_radius := settingf("bullet_radius")
	var muzzle_position: Vector2 = fighter.pos + _gun_direction * (
		fighter.radius * settingf("muzzle_distance_multiplier") + bullet_radius
	)
	var arena_size: Vector2 = battle.arena_size()
	muzzle_position.x = clampf(muzzle_position.x, bullet_radius, arena_size.x - bullet_radius)
	muzzle_position.y = clampf(muzzle_position.y, bullet_radius, arena_size.y - bullet_radius)
	var sniper_round: BallEntity = SniperRoundScript.new(
		side,
		muzzle_position,
		_gun_direction * settingf("bullet_speed"),
		bullet_radius,
		settingf("bullet_damage"),
		fighter.accent,
		settingf("bullet_lifetime"),
		settingi("scatter_count"),
		settingf("scatter_damage"),
		settingf("scatter_speed"),
		settingf("scatter_radius"),
		settingf("scatter_spread_degrees"),
		settingf("scatter_lifetime")
	)
	battle.add_entity(sniper_round)
	battle.record_stat("projectiles_spawned")
	battle.record_stat("sniper_rounds_fired")
	battle.spawn_particles(muzzle_position, fighter.accent, 8, 170.0)
	battle.spawn_ring(muzzle_position, Color.WHITE, 4.0, 42.0, 0.16)
	battle.emit_combat_event("sniper_fire", 1.0)
	battle.shake_camera(6.5)
	_recoil_remaining = RECOIL_DURATION
	_shots_fired += 1

func _update_gun_direction(fighter, opponent) -> void:
	var toward_target: Vector2 = opponent.pos - fighter.pos
	if toward_target.length_squared() > 0.0001:
		_gun_direction = toward_target.normalized()
