extends BallAbility

const SlashEffectEntity := preload("res://scripts/balls/wind_swordsman/slash_effect_entity.gd")
const GroundCrackEntity := preload("res://scripts/balls/wind_swordsman/ground_crack_entity.gd")
const WindWallEntity := preload("res://scripts/balls/wind_swordsman/wind_wall_entity.gd")

var _slash_timer := 0.0
var _standstill_remaining := 0.0
var _resume_velocity := Vector2.ZERO
var _resume_pending := false

func before_motion(_battle, fighter, _opponent, _side: int, delta: float) -> void:
	_slash_timer = maxf(0.0, _slash_timer - delta)
	if _standstill_remaining > 0.0:
		_standstill_remaining = maxf(0.0, _standstill_remaining - delta)
		fighter.velocity = Vector2.ZERO
		return
	if _resume_pending:
		fighter.velocity = _resume_velocity
		_resume_pending = false

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return 0.0 if _standstill_remaining > 0.0 or _resume_pending else 1.0

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	for wall: BallEntity in battle.entities(side, "wind_wall"):
		wall.call("intercept_projectiles", battle, delta)
	if _slash_timer > 0.0:
		return
	if _can_strike_target(fighter.pos, opponent.pos, opponent.radius):
		_release_slash(battle, fighter, opponent, side, opponent.pos)
		return
	var entity_target := _nearest_strikeable_entity(battle, fighter, side)
	if entity_target != null:
		_release_slash(battle, fighter, opponent, side, entity_target.pos)

func activate(battle, fighter, opponent, side: int) -> void:
	var direction := _aim_direction(fighter, opponent)
	_begin_standstill(fighter)
	var active_walls: Array[BallEntity] = battle.entities(side, "wind_wall")
	while active_walls.size() >= settingi("max_walls"):
		active_walls.pop_front().removed = true
	var wall: BallEntity = WindWallEntity.new(
		side,
		fighter.pos + direction * settingf("wall_distance"),
		direction,
		{
			"duration": settingf("wall_duration"),
			"curve_radius": settingf("wall_curve_radius"),
			"arc_span": deg_to_rad(settingf("wall_arc_degrees")),
			"thickness": settingf("wall_thickness"),
		},
		fighter.accent
	)
	battle.add_entity(wall)
	wall.call("intercept_projectiles", battle, settingf("wall_activation_lookahead"))
	battle.spawn_ring(wall.pos, fighter.accent, 8.0, settingf("wall_curve_radius") * 0.72, 0.34)
	battle.spawn_particles(wall.pos, fighter.accent, 10, 115.0)
	battle.emit_combat_event("wind_cast", 0.76)
	battle.record_stat("wind_walls")

func _release_slash(battle, fighter, opponent, side: int, target_position: Vector2) -> void:
	_slash_timer = settingf("slash_cooldown")
	var direction := _aim_direction_to(fighter, target_position)
	_begin_standstill(fighter)
	var reach := settingf("slash_reach")
	var half_width := settingf("slash_half_width")
	var start: Vector2 = fighter.pos
	var finish: Vector2 = fighter.pos + direction * reach
	var crack_center := (start + finish) * 0.5
	var damage := settingf("slash_damage")
	var hit_something := false
	if _circle_intersects_segment(opponent.pos, opponent.radius, start, finish, half_width):
		battle.damage(opponent, damage, fighter.accent, fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities_on_segment(
		side,
		start,
		finish,
		half_width
	):
		battle.damage_entity(entity, damage, fighter.accent, side)
		hit_something = true
	battle.add_entity(SlashEffectEntity.new(
		side,
		fighter.pos,
		direction,
		reach,
		half_width,
		settingf("slash_effect_duration"),
		fighter.accent
	))
	battle.add_entity(GroundCrackEntity.new(
		side,
		crack_center,
		direction,
		reach,
		settingf("crack_duration"),
		fighter.accent
	))
	battle.spawn_particles(target_position, fighter.accent, 8, 165.0)
	battle.emit_combat_event("blade_slash", 0.82)
	battle.record_stat("wind_slashes")
	if hit_something:
		battle.shake_camera(3.8)

func _begin_standstill(fighter) -> void:
	var duration := settingf("skill_standstill_duration")
	if duration <= 0.0:
		return
	if not _resume_pending:
		_resume_velocity = fighter.velocity
		_resume_pending = true
	_standstill_remaining = maxf(_standstill_remaining, duration)
	fighter.velocity = Vector2.ZERO

func _aim_direction(fighter, opponent) -> Vector2:
	return _aim_direction_to(fighter, opponent.pos)

func _aim_direction_to(fighter, target_position: Vector2) -> Vector2:
	var direction: Vector2 = target_position - fighter.pos
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	if fighter.velocity.length_squared() > 0.0001:
		return fighter.velocity.normalized()
	return Vector2.RIGHT

func _nearest_strikeable_entity(battle, fighter, side: int) -> BallEntity:
	var nearest: BallEntity = null
	var nearest_distance_squared := INF
	for entity: BallEntity in battle.damageable_entities(side):
		if not _can_strike_target(fighter.pos, entity.pos, entity.radius):
			continue
		var distance_squared: float = fighter.pos.distance_squared_to(entity.pos)
		if distance_squared < nearest_distance_squared:
			nearest = entity
			nearest_distance_squared = distance_squared
	return nearest

func _can_strike_target(origin: Vector2, target_position: Vector2, target_radius: float) -> bool:
	var distance := origin.distance_to(target_position)
	return (
		distance <= settingf("slash_trigger_range")
		and distance <= settingf("slash_reach") + target_radius + settingf("slash_half_width")
	)

func _circle_intersects_segment(
	center: Vector2,
	radius: float,
	start: Vector2,
	finish: Vector2,
	half_width: float
) -> bool:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return center.distance_to(start) <= radius + half_width
	var offset := clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
	return center.distance_to(start + segment * offset) <= radius + half_width
