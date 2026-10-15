extends BallAbility

const AttackVfxEntity := preload("res://scripts/balls/kobe/attack_vfx_entity.gd")
const NamedCastVfx := preload("res://scripts/balls/core/named_cast_entity.gd")
const CYCLONE := "cyclone"
const ELBOW := "elbow"
const MOVEMENT_PRIORITY := BallStatusEffect.MOVEMENT_CONTROL_PRIORITY_ABILITY
const EPSILON := 0.0001

var _next_move := CYCLONE
var _last_move := ""
var _active_move := ""
var _move_remaining := 0.0
var _move_duration := 0.0
var _move_direction := Vector2.RIGHT
var _target_uid := -1
var _movement_suppressed := false
var _elbow_struck := false
var _hit_targets: Dictionary = {}
var _effect_timer := 0.0

func on_battle_started(_battle, fighter, _opponent, _side: int) -> void:
	_next_move = CYCLONE
	_last_move = ""
	_active_move = ""
	_move_remaining = 0.0
	_move_duration = 0.0
	_move_direction = Vector2.RIGHT
	_target_uid = -1
	_movement_suppressed = false
	_elbow_struck = false
	_hit_targets.clear()
	_effect_timer = 0.0
	fighter.ability_timer = settingf("opening_delay")

func automatic_activation_enabled() -> bool:
	return _active_move.is_empty()

func before_motion(battle, fighter, _opponent, _side: int, delta: float) -> void:
	_movement_suppressed = (
		not _active_move.is_empty()
		and battle.movement_control_priority(fighter) > MOVEMENT_PRIORITY
	)
	if _active_move.is_empty() or _movement_suppressed:
		return
	var target = battle.fighter_for_uid(_target_uid)
	if target != null and target.hp > 0.0:
		var desired: Vector2 = target.pos - fighter.pos
		if desired.length_squared() > EPSILON:
			if _active_move == CYCLONE:
				_move_direction = _turn_toward(
					_move_direction,
					desired.normalized(),
					deg_to_rad(settingf("cyclone_turn_rate_degrees")) * delta
				)
			elif not _elbow_struck:
				_move_direction = desired.normalized()
	var move_speed := settingf("cyclone_speed") if _active_move == CYCLONE \
		else settingf("elbow_lunge_speed")
	fighter.velocity = _move_direction * move_speed

func speed_multiplier(_battle, fighter, _opponent, _side: int) -> float:
	if _active_move.is_empty() or _movement_suppressed:
		return 1.0
	var move_speed := settingf("cyclone_speed") if _active_move == CYCLONE \
		else settingf("elbow_lunge_speed")
	return move_speed / maxf(1.0, float(fighter.base_speed))

func on_step(battle, fighter, _opponent, side: int, delta: float) -> void:
	if _active_move.is_empty() or _movement_suppressed:
		return
	_move_remaining = maxf(0.0, _move_remaining - delta)
	if _active_move == CYCLONE:
		_sweep_cyclone(battle, fighter, side)
		_effect_timer -= delta
		if _effect_timer <= 0.0:
			_effect_timer += 0.08
			battle.spawn_ring(
				fighter.pos, Color("ffd43d"), fighter.radius * 0.7,
				fighter.radius + settingf("cyclone_reach"), 0.18
			)
	elif not _elbow_struck and _move_remaining <= settingf("elbow_active_duration"):
		_strike_elbow(battle, fighter, side)
	if _move_remaining <= 0.0:
		_end_move()

func activate(battle, fighter, opponent, side: int) -> void:
	if opponent == null or opponent.hp <= 0.0:
		return
	_active_move = _next_move
	_last_move = _active_move
	_next_move = ELBOW if _active_move == CYCLONE else CYCLONE
	_target_uid = opponent.fighter_uid
	_move_direction = opponent.pos - fighter.pos
	if _move_direction.length_squared() <= EPSILON:
		_move_direction = fighter.velocity
	if _move_direction.length_squared() <= EPSILON:
		_move_direction = Vector2.RIGHT
	_move_direction = _move_direction.normalized()
	_move_duration = settingf("cyclone_duration") if _active_move == CYCLONE \
		else settingf("elbow_windup_duration") + settingf("elbow_active_duration")
	_move_remaining = _move_duration
	_elbow_struck = false
	_movement_suppressed = false
	_hit_targets.clear()
	_effect_timer = 0.0
	var title := "闪电旋风劈" if _active_move == CYCLONE else "肘击"
	var voice := "kobe_cyclone_voice" if _active_move == CYCLONE else "kobe_elbow_voice"
	var color := Color("ffe14f") if _active_move == CYCLONE else Color("ffb43b")
	var label: BallEntity = NamedCastVfx.new(
		side, fighter, title, settingf("cast_name_duration"), color, Color("9d67ff")
	)
	battle.add_entity(label)
	var effect: BallEntity = AttackVfxEntity.new(
		side, fighter, _active_move, _move_duration, _move_direction
	)
	battle.add_entity(effect)
	battle.spawn_ring(fighter.pos, color, fighter.radius * 0.65, fighter.radius * 2.7, 0.28)
	battle.spawn_particles(fighter.pos, color, 12, 152.0)
	battle.emit_combat_event(voice, 1.0)
	battle.record_stat("kobe_%s_uses" % _active_move)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 0.0

func next_move() -> String:
	return _next_move

func last_move() -> String:
	return _last_move

func active_move() -> String:
	return _active_move

func move_direction() -> Vector2:
	return _move_direction

func active_ratio() -> float:
	return clampf(_move_remaining / maxf(_move_duration, EPSILON), 0.0, 1.0)

func _sweep_cyclone(battle, fighter, side: int) -> void:
	var attack_radius: float = fighter.radius + settingf("cyclone_reach")
	for target in battle.hostile_fighters(side):
		var target_key := "fighter:%d" % int(target.fighter_uid)
		if _hit_targets.has(target_key):
			continue
		if target.pos.distance_to(fighter.pos) > attack_radius + target.radius:
			continue
		_hit_targets[target_key] = true
		var applied: float = battle.damage(
			target, settingf("cyclone_damage"), Color("ffe14f"), fighter
		)
		_apply_knockback(target, fighter.pos, settingf("cyclone_knockback"))
		_show_hit(battle, target.pos, Color("ffe14f"), applied, "cyclone")
	for entity: BallEntity in battle.damageable_entities_in_circle(
		side, fighter.pos, attack_radius
	):
		var target_key := "entity:%d" % entity.get_instance_id()
		if _hit_targets.has(target_key):
			continue
		_hit_targets[target_key] = true
		var applied: float = battle.damage_entity(
			entity, settingf("cyclone_damage"), Color("ffe14f"), side
		)
		_apply_knockback(entity, fighter.pos, settingf("cyclone_knockback"))
		_show_hit(battle, entity.pos, Color("ffe14f"), applied, "cyclone")

func _strike_elbow(battle, fighter, side: int) -> void:
	_elbow_struck = true
	var target = battle.fighter_for_uid(_target_uid)
	if target != null and target.hp > 0.0:
		var desired: Vector2 = target.pos - fighter.pos
		if desired.length_squared() > EPSILON:
			_move_direction = desired.normalized()
	var start: Vector2 = fighter.pos
	var finish: Vector2 = start + _move_direction * (fighter.radius + settingf("elbow_reach"))
	var half_width := settingf("elbow_half_width")
	for hostile in battle.hostile_fighters(side):
		if _distance_to_segment(hostile.pos, start, finish) > hostile.radius + half_width:
			continue
		var applied: float = battle.damage(
			hostile, settingf("elbow_damage"), Color("ffb43b"), fighter
		)
		_apply_knockback(hostile, fighter.pos, settingf("elbow_knockback"))
		_show_hit(battle, hostile.pos, Color("ffb43b"), applied, "elbow")
	for entity: BallEntity in battle.damageable_entities_on_segment(
		side, start, finish, half_width
	):
		var applied: float = battle.damage_entity(
			entity, settingf("elbow_damage"), Color("ffb43b"), side
		)
		_apply_knockback(entity, fighter.pos, settingf("elbow_knockback"))
		_show_hit(battle, entity.pos, Color("ffb43b"), applied, "elbow")
	battle.add_beam(start, finish, Color(1.0, 0.72, 0.18, 0.8), 0.18, half_width * 0.72)
	battle.spawn_ring(finish, Color("fff0a0"), 4.0, 48.0, 0.24)
	battle.spawn_particles(finish, Color("ffb43b"), 14, 186.0)
	battle.emit_combat_event("ram_impact", 0.82)
	battle.shake_camera(5.2)
	battle.record_stat("kobe_elbow_strikes")

func _apply_knockback(target, source_position: Vector2, impulse: float) -> void:
	var direction: Vector2 = target.pos - source_position
	if direction.length_squared() <= EPSILON:
		direction = _move_direction
	if direction.length_squared() <= EPSILON:
		direction = Vector2.RIGHT
	target.velocity += direction.normalized() * maxf(0.0, impulse)

func _show_hit(
	battle,
	position: Vector2,
	color: Color,
	applied_damage: float,
	move_kind: String
) -> void:
	if applied_damage <= 0.0:
		return
	battle.spawn_ring(position, color, 4.0, 42.0, 0.2)
	battle.spawn_particles(position, color, 8, 135.0)
	battle.emit_combat_event("body_impact", 0.72)
	battle.record_stat("kobe_%s_hits" % move_kind)

func _turn_toward(current: Vector2, desired: Vector2, maximum_angle: float) -> Vector2:
	if current.length_squared() <= EPSILON:
		return desired
	var delta_angle := wrapf(desired.angle() - current.angle(), -PI, PI)
	return current.rotated(clampf(delta_angle, -maximum_angle, maximum_angle)).normalized()

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= EPSILON:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)

func _end_move() -> void:
	_active_move = ""
	_move_remaining = 0.0
	_move_duration = 0.0
	_target_uid = -1
	_movement_suppressed = false
	_elbow_struck = false
	_hit_targets.clear()
