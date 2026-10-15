extends BallAbility

const BladeEntity := preload("res://scripts/balls/blade_dancer/blade_entity.gd")
const DashAfterimageEntity := preload("res://scripts/balls/blade_dancer/dash_afterimage_entity.gd")
const MOVEMENT_PRIORITY := BallStatusEffect.MOVEMENT_CONTROL_PRIORITY_ABILITY

var _spawned_blades: Array[WeakRef] = []
var _dash_active := false
var _dash_target_uid := -1
var _dash_remaining := 0.0
var _dash_hit_registered := false
var _afterimage_elapsed := 0.0
var _movement_suppressed := false
var _spin_pending := false
var _spin_delay_remaining := 0.0

func on_battle_started(battle, fighter, opponent, side: int) -> void:
	_spawned_blades.clear()
	_dash_active = false
	_dash_target_uid = -1
	_dash_remaining = 0.0
	_dash_hit_registered = false
	_afterimage_elapsed = 0.0
	_movement_suppressed = false
	_spin_pending = false
	_spin_delay_remaining = 0.0
	_spawn_blade_fan(battle, fighter, opponent, side)
	fighter.ability_timer = fighter.cooldown

func automatic_activation_enabled() -> bool:
	return not _dash_active and not _spin_pending

func before_motion(battle, fighter, _opponent, _side: int, _delta: float) -> void:
	_movement_suppressed = (
		_dash_active
		and battle.movement_control_priority(fighter) > MOVEMENT_PRIORITY
	)
	if not _dash_active or _movement_suppressed:
		return
	var target = battle.fighter_for_uid(_dash_target_uid)
	if target == null or target.hp <= 0.0:
		_end_dash()
		return
	var direction: Vector2 = target.pos - fighter.pos
	if direction.length_squared() <= 0.0001:
		direction = fighter.velocity
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	fighter.velocity = direction.normalized() * settingf("dash_speed")

func speed_multiplier(_battle, fighter, _opponent, _side: int) -> float:
	if not _dash_active or _movement_suppressed:
		return 1.0
	return settingf("dash_speed") / maxf(1.0, float(fighter.base_speed))

func on_step(battle, fighter, _opponent, side: int, delta: float) -> void:
	_advance_pending_spin(battle, fighter, side, delta)
	if not _dash_active or _movement_suppressed:
		return
	var target = battle.fighter_for_uid(_dash_target_uid)
	if target == null or target.hp <= 0.0:
		_end_dash()
		return
	_dash_remaining = maxf(0.0, _dash_remaining - delta)
	_afterimage_elapsed += delta
	var interval := maxf(0.005, settingf("dash_afterimage_interval"))
	while _afterimage_elapsed + 0.000001 >= interval:
		_afterimage_elapsed -= interval
		_spawn_afterimage(battle, fighter, side)
	if _dash_remaining <= 0.0:
		_end_dash()

func activate(battle, fighter, opponent, side: int) -> void:
	if opponent == null or opponent.hp <= 0.0:
		return
	_dash_active = true
	_dash_target_uid = opponent.fighter_uid
	_dash_remaining = settingf("dash_max_duration")
	_dash_hit_registered = false
	_afterimage_elapsed = settingf("dash_afterimage_interval")
	_movement_suppressed = false
	_spin_pending = true
	_spin_delay_remaining = maxf(0.0, settingf("blade_spin_delay"))
	if _spin_delay_remaining <= 0.0:
		_start_blade_spin(battle, fighter, side)
	_spawn_afterimage(battle, fighter, side)
	battle.spawn_ring(
		fighter.pos,
		fighter.accent,
		fighter.radius * 0.7,
		fighter.radius * 2.5,
		0.24
	)
	battle.spawn_particles(fighter.pos, fighter.accent, 10, 155.0)
	battle.record_stat("blade_dancer_dashes")

func contact_damage(_battle, _fighter, opponent) -> float:
	if (
		not _dash_active
		or _movement_suppressed
		or _dash_hit_registered
		or opponent == null
		or opponent is BallEntity
		or int(opponent.fighter_uid) != _dash_target_uid
	):
		return 0.0
	return settingf("dash_damage")

func after_contact(battle, fighter, opponent, damage_dealt: float) -> void:
	if (
		not _dash_active
		or opponent == null
		or int(opponent.fighter_uid) != _dash_target_uid
	):
		return
	_dash_hit_registered = true
	_end_dash()
	battle.spawn_ring(opponent.pos, fighter.accent, 6.0, 52.0, 0.2)
	battle.spawn_particles(opponent.pos, fighter.accent, 8, 132.0)
	battle.emit_combat_event("ram_impact", 0.56 if damage_dealt > 0.0 else 0.38)
	battle.shake_camera(3.2)
	battle.record_stat("blade_dancer_dash_hits")

func dash_active() -> bool:
	return _dash_active

func dash_target_uid() -> int:
	return _dash_target_uid

func spin_pending() -> bool:
	return _spin_pending

func spin_delay_remaining() -> float:
	return _spin_delay_remaining

func active_blade_count() -> int:
	return _active_blades().size()

func owned_blade_count(fighter) -> int:
	return _owned_blades(fighter).size()

func _advance_pending_spin(battle, fighter, side: int, delta: float) -> void:
	if not _spin_pending or _movement_suppressed:
		return
	_spin_delay_remaining = maxf(0.0, _spin_delay_remaining - delta)
	if _spin_delay_remaining <= 0.0:
		_start_blade_spin(battle, fighter, side)

func _start_blade_spin(battle, fighter, side: int) -> void:
	_spin_pending = false
	_spin_delay_remaining = 0.0
	var spin_direction := 1.0 if side % 2 == 0 else -1.0
	for blade: BallEntity in _owned_blades(fighter):
		blade.call(
			"start_spin",
			settingf("blade_spin_duration"),
			settingf("blade_spin_turns"),
			spin_direction
		)
	battle.record_stat("blade_dancer_blade_spins")

func _spawn_blade_fan(battle, fighter, opponent, side: int) -> void:
	var blade_count := maxi(1, settingi("blade_count"))
	var settings := {
		"fan_arc_degrees": settingf("fan_arc_degrees"),
		"blade_tilt_degrees": settingf("blade_tilt_degrees"),
		"blade_orbit_radius": settingf("blade_orbit_radius"),
		"blade_orbit_speed": deg_to_rad(settingf("blade_orbit_speed_degrees")),
		"blade_length": settingf("blade_length"),
		"blade_width": settingf("blade_width"),
		"blade_damage": settingf("blade_damage"),
	}
	var initial_direction: Vector2 = opponent.pos - fighter.pos
	if initial_direction.length_squared() <= 0.0001:
		initial_direction = fighter.velocity
	if initial_direction.length_squared() <= 0.0001:
		initial_direction = Vector2.RIGHT
	var initial_orbit_angle := initial_direction.angle() + PI
	for blade_index in range(blade_count):
		var blade: BallEntity = BladeEntity.new(
			side,
			fighter,
			blade_index,
			blade_count,
			settings,
			fighter.color.lightened(0.22),
			fighter.accent,
			initial_orbit_angle
		)
		battle.add_entity(blade)
		_spawned_blades.append(weakref(blade))
	battle.record_stat("blade_dancer_blades_spawned", blade_count)

func _spawn_afterimage(battle, fighter, side: int) -> void:
	var afterimage: BallEntity = DashAfterimageEntity.new(
		side,
		fighter.pos,
		fighter.radius,
		settingf("dash_afterimage_duration"),
		fighter.color,
		fighter.accent,
		fighter.velocity
	)
	afterimage.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(afterimage)

func _owned_blades(fighter) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for blade: BallEntity in _active_blades():
		if blade.owner_fighter_uid == fighter.fighter_uid:
			result.append(blade)
	return result

func _active_blades() -> Array[BallEntity]:
	for index in range(_spawned_blades.size() - 1, -1, -1):
		var blade: BallEntity = _spawned_blades[index].get_ref()
		if blade == null or blade.removed:
			_spawned_blades.remove_at(index)
	var result: Array[BallEntity] = []
	for blade_ref: WeakRef in _spawned_blades:
		var blade: BallEntity = blade_ref.get_ref()
		if blade != null:
			result.append(blade)
	return result

func _end_dash() -> void:
	_dash_active = false
	_dash_target_uid = -1
	_dash_remaining = 0.0
	_movement_suppressed = false
