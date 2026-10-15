extends BallEntity

const PurpleExplosionVfx := preload("res://scripts/balls/gojo/purple_explosion_vfx_entity.gd")
const BLUE := "blue"
const RED := "red"
const PURPLE := "purple"
const EPSILON := 0.0001
const MAX_IMPACTS_PER_STEP := 4
const CONTACT_RELEASE_MARGIN := 1.0

var technique_kind := BLUE
var _damage_amount := 0.0
var _native_color := Color("45dfff")
var _core_color := Color("eaffff")
var _purple_hit_targets: Dictionary = {}
var _contact_targets: Dictionary = {}
var _hit_cooldowns: Dictionary = {}
var _hit_interval := 0.0
var _previous_position := Vector2.ZERO
var _effect_radius := 0.0
var _force_acceleration := 0.0
var _force_maximum_speed := 1.0
var _impact_impulse := 0.0
var _purple_erase_radius := 0.0
var _purple_explosion_radius := 0.0
var _purple_explosion_duration := 1.4

func _init(spawn_owner_side: int, spawn_position: Vector2, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_previous_position = pos
	technique_kind = String(config.get("kind", BLUE))
	velocity = config.get("velocity", Vector2.ZERO) as Vector2
	radius = maxf(1.0, float(config.get("radius", 7.0)))
	_damage_amount = maxf(0.0, float(config.get("damage", 2.0)))
	remaining = maxf(0.05, float(config.get("duration", 10.0)))
	_effect_radius = maxf(0.0, float(config.get("effect_radius", 0.0)))
	_force_acceleration = maxf(0.0, float(config.get("force_acceleration", 0.0)))
	_force_maximum_speed = maxf(1.0, float(config.get("force_maximum_speed", 1.0)))
	_impact_impulse = maxf(0.0, float(config.get("impact_impulse", 0.0)))
	_hit_interval = maxf(0.0, float(config.get("hit_interval", 0.0)))
	_purple_erase_radius = maxf(0.0, float(config.get("purple_erase_radius", 0.0)))
	_purple_explosion_radius = maxf(0.0, float(config.get("purple_explosion_radius", 0.0)))
	_purple_explosion_duration = maxf(0.05, float(config.get("purple_explosion_duration", 1.4)))
	_native_color = _kind_color(technique_kind)
	_core_color = _kind_core_color(technique_kind)
	tags = PackedStringArray(["projectile", "gojo_technique_orb", "gojo_orb_%s" % technique_kind])
	draw_layer = 10

func tick_lifetime(_delta: float) -> void:
	# Motion owns lifetime so newly spawned and existing orbs receive the same full step.
	pass

func step(battle, delta: float) -> void:
	if removed:
		return
	_previous_position = pos
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0 or _damage_amount <= EPSILON:
		removed = true
		return
	_apply_spatial_effect(battle, delta)
	_update_hit_contacts(delta)
	var time_left := delta
	var impact_count := 0
	while time_left > EPSILON and impact_count < MAX_IMPACTS_PER_STEP and not removed:
		_update_hit_contacts(0.0)
		var start := pos
		var finish := start + velocity * time_left
		var body_hit := _first_body_hit(battle, start, finish)
		var body_fraction := float(body_hit.get("fraction", -1.0))
		var wall_hit := _arena_wall_hit(start, finish, battle.arena_size())
		var wall_fraction := float(wall_hit.get("fraction", -1.0))
		var hit := body_hit
		var hit_fraction := body_fraction
		if wall_fraction >= 0.0 and (hit_fraction < 0.0 or wall_fraction < hit_fraction):
			hit = wall_hit
			hit_fraction = wall_fraction
		var travel_finish := start.lerp(finish, hit_fraction) if hit_fraction >= 0.0 else finish
		pos = travel_finish
		if hit_fraction < 0.0:
			break
		_resolve_hit(battle, hit)
		impact_count += 1
		time_left *= maxf(0.0, 1.0 - hit_fraction)
	_update_hit_contacts(0.0)
	if pos.x < -radius or pos.x > battle.arena_size().x + radius \
			or pos.y < -radius or pos.y > battle.arena_size().y + radius:
		removed = true

func previous_position() -> Vector2:
	return _previous_position

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var draw_radius := radius * context.scale_factor
	var alpha := 0.42 if is_captured() else 1.0
	if technique_kind == PURPLE:
		_draw_hollow_purple(canvas, context, center, draw_radius, alpha)
		return
	var direction := velocity.normalized()
	if direction.length_squared() > EPSILON:
		var tail_length := draw_radius * 2.8
		var tail_color := _native_color
		tail_color.a = 0.2 * alpha
		canvas.draw_line(center, center - direction * tail_length, tail_color, draw_radius * 1.35, true)
	var pulse := 0.94 + 0.08 * sin(context.elapsed * 10.0)
	var glow := _native_color
	glow.a = 0.22 * alpha
	canvas.draw_circle(center, draw_radius * 2.25 * pulse, glow)
	var rim := _native_color
	rim.a = 0.96 * alpha
	canvas.draw_circle(center, draw_radius * 1.18, Color(0.03, 0.025, 0.08, 0.94 * alpha))
	canvas.draw_circle(center, draw_radius, rim)
	canvas.draw_circle(center, draw_radius * 0.62, Color(_core_color.r, _core_color.g, _core_color.b, 0.92 * alpha))
	canvas.draw_circle(
		center - Vector2(draw_radius * 0.2, draw_radius * 0.24),
		draw_radius * 0.22,
		Color(1.0, 1.0, 1.0, 0.94 * alpha)
	)
	var arc_count := 2
	for arc_index in range(arc_count):
		var angle := context.elapsed * (5.5 + float(arc_index)) + float(arc_index) * TAU / float(arc_count)
		canvas.draw_arc(
			center,
			draw_radius * (1.35 + float(arc_index) * 0.18),
			angle,
			angle + PI * 0.72,
			16,
			Color(_native_color.r, _native_color.g, _native_color.b, (0.82 - float(arc_index) * 0.12) * alpha),
			maxf(1.0, draw_radius * 0.1),
			true
		)

func _draw_hollow_purple(
	canvas: CanvasItem,
	context: BallRenderContext,
	center: Vector2,
	draw_radius: float,
	alpha: float
) -> void:
	var direction := velocity.normalized()
	if direction.length_squared() <= EPSILON:
		direction = Vector2.RIGHT
	var side := direction.orthogonal()
	var pulse := 1.0 + sin(context.elapsed * 14.0) * 0.045
	var wave_front := center + direction * draw_radius * 0.72
	var outer_flow := PackedVector2Array([
		center + direction * draw_radius * 1.95,
		center + direction * draw_radius * 1.22 + side * draw_radius * 1.2 * pulse,
		center + direction * draw_radius * 0.18 + side * draw_radius * 1.58,
		center - direction * draw_radius * 1.25 + side * draw_radius * 1.35,
		center - direction * draw_radius * 3.0 + side * draw_radius * 0.82,
		center - direction * draw_radius * 5.8 + side * draw_radius * 0.18,
		center - direction * draw_radius * 4.25 - side * draw_radius * 0.56,
		center - direction * draw_radius * 2.15 - side * draw_radius * 1.12,
		center - direction * draw_radius * 0.52 - side * draw_radius * 1.5,
		center + direction * draw_radius * 0.94 - side * draw_radius * 1.12,
	])
	canvas.draw_colored_polygon(outer_flow, Color(0.42, 0.025, 0.82, 0.18 * alpha))
	canvas.draw_line(
		center - direction * draw_radius * 4.9,
		wave_front,
		Color(0.6, 0.055, 1.0, 0.18 * alpha),
		draw_radius * 3.0 * pulse,
		true
	)
	var destruction_shell := PackedVector2Array([
		center + direction * draw_radius * 1.62,
		center + direction * draw_radius * 0.72 + side * draw_radius * 0.9,
		center - direction * draw_radius * 1.18 + side * draw_radius * 0.76,
		center - direction * draw_radius * 3.75 + side * draw_radius * 0.3,
		center - direction * draw_radius * 4.65,
		center - direction * draw_radius * 3.35 - side * draw_radius * 0.38,
		center - direction * draw_radius * 1.0 - side * draw_radius * 0.82,
		center + direction * draw_radius * 0.76 - side * draw_radius * 0.86,
	])
	canvas.draw_colored_polygon(destruction_shell, Color(0.22, 0.008, 0.5, 0.96 * alpha))
	canvas.draw_line(
		center - direction * draw_radius * 3.65 + side * draw_radius * 0.22,
		center + direction * draw_radius * 0.72 + side * draw_radius * 0.18,
		Color(1.0, 0.08, 0.3, 0.45 * alpha),
		draw_radius * 0.7,
		true
	)
	canvas.draw_line(
		center - direction * draw_radius * 3.35 - side * draw_radius * 0.28,
		center + direction * draw_radius * 0.68 - side * draw_radius * 0.2,
		Color(0.08, 0.6, 1.0, 0.5 * alpha),
		draw_radius * 0.72,
		true
	)
	var white_current := PackedVector2Array([
		center + direction * draw_radius * 1.48,
		center + direction * draw_radius * 0.62 + side * draw_radius * 0.48,
		center - direction * draw_radius * 1.35 + side * draw_radius * 0.38,
		center - direction * draw_radius * 3.7 + side * draw_radius * 0.1,
		center - direction * draw_radius * 4.3,
		center - direction * draw_radius * 3.28 - side * draw_radius * 0.18,
		center - direction * draw_radius * 1.16 - side * draw_radius * 0.42,
		center + direction * draw_radius * 0.62 - side * draw_radius * 0.46,
	])
	canvas.draw_colored_polygon(white_current, Color(0.98, 0.82, 1.0, 0.96 * alpha))
	canvas.draw_line(
		center - direction * draw_radius * 3.1,
		center + direction * draw_radius * 1.02,
		Color(1.0, 0.985, 1.0, 0.96 * alpha),
		draw_radius * 0.34,
		true
	)
	var front_angle := direction.angle()
	for front_index in range(3):
		var front_depth := float(front_index)
		var front_color := Color(0.96, 0.64, 1.0, (0.82 - front_depth * 0.2) * alpha)
		canvas.draw_arc(
			wave_front - direction * draw_radius * front_depth * 0.16,
			draw_radius * (1.1 + front_depth * 0.28) * pulse,
			front_angle - PI * 0.5,
			front_angle + PI * 0.5,
			24,
			front_color,
			maxf(1.0, draw_radius * (0.13 - front_depth * 0.025)),
			true
		)
	for streak_index in range(7):
		var streak_depth := float(streak_index) / 6.0
		var oscillation := sin(context.elapsed * (7.5 + streak_depth * 2.0) + float(streak_index) * 1.37)
		var streak_offset := side * oscillation * draw_radius * (0.35 + streak_depth * 0.78)
		var streak_start := center - direction * draw_radius * (2.0 + streak_depth * 4.8) + streak_offset
		var streak_end := center + direction * draw_radius * (0.2 + streak_depth * 0.62) + streak_offset * 0.12
		var streak_color := Color("f05cff") if streak_index % 2 == 0 else Color("8a54ff")
		streak_color.a = (0.5 - streak_depth * 0.18) * alpha
		canvas.draw_line(
			streak_start,
			streak_end,
			streak_color,
			maxf(1.0, draw_radius * (0.13 - streak_depth * 0.045)),
			true
		)
	for shard_index in range(10):
		var shard_depth := float(shard_index % 5) / 4.0
		var shard_sign := -1.0 if shard_index % 2 == 0 else 1.0
		var shard_center := center \
			- direction * draw_radius * (0.25 + shard_depth * 4.6) \
			+ side * shard_sign * draw_radius * (1.0 + 0.28 * sin(context.elapsed * 5.0 + shard_index))
		var shard_length := draw_radius * (0.18 + 0.1 * float(shard_index % 3))
		var shard_points := PackedVector2Array([
			shard_center + direction * shard_length,
			shard_center - direction * shard_length * 0.72 + side * draw_radius * 0.09,
			shard_center - direction * shard_length * 0.45 - side * draw_radius * 0.08,
		])
		canvas.draw_colored_polygon(shard_points, Color(0.025, 0.002, 0.07, 0.86 * alpha))

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_visual_color() -> Color:
	return _native_color

func damage_amount() -> float:
	return _damage_amount

func effect_radius() -> float:
	return _effect_radius

func _apply_spatial_effect(battle, delta: float) -> void:
	if technique_kind == PURPLE:
		_erase_hostile_projectiles(battle)
		return
	if _effect_radius <= EPSILON or _force_acceleration <= EPSILON:
		return
	var direction_sign := -1.0 if technique_kind == BLUE else 1.0
	for fighter in battle.hostile_fighters(owner_side):
		_apply_force_to_body(fighter, fighter.radius, direction_sign, delta)
	for entity: BallEntity in battle.entities():
		if entity == self or entity.removed or entity.is_captured():
			continue
		var own_technique := owner_fighter_uid >= 0 \
			and entity.owner_fighter_uid == owner_fighter_uid \
			and (entity.has_tag("gojo_orb_blue") or entity.has_tag("gojo_orb_red"))
		if not own_technique and not entity.is_hostile_to(owner_side):
			continue
		if not entity.has_tag("projectile") and not entity.is_absorbable() \
				and not entity.can_receive_attack(owner_side) \
				and not (entity.participates_in_fighter_collision() or entity.participates_in_entity_collision() or entity.team_marker_world_height() > 0.0):
			continue
		_apply_force_to_body(entity, entity.radius, direction_sign, delta)

func _apply_force_to_body(target, target_radius: float, direction_sign: float, delta: float) -> void:
	var offset: Vector2 = target.pos - pos
	var threshold := _effect_radius + maxf(0.0, target_radius)
	if offset.length_squared() > threshold * threshold:
		return
	if offset.length_squared() <= EPSILON:
		offset = -target.velocity
	if offset.length_squared() <= EPSILON:
		offset = Vector2.RIGHT
	var falloff := clampf(1.0 - offset.length() / maxf(threshold, EPSILON), 0.0, 1.0)
	var acceleration := offset.normalized() * direction_sign * _force_acceleration * falloff
	var prior_speed: float = target.velocity.length()
	target.velocity += acceleration * maxf(0.0, delta)
	target.velocity = target.velocity.limit_length(maxf(prior_speed, _force_maximum_speed))

func _erase_hostile_projectiles(battle) -> void:
	if _purple_erase_radius <= EPSILON:
		return
	for projectile: BallEntity in battle.entities(-1, "projectile"):
		if projectile == self or not projectile.is_hostile_to(owner_side):
			continue
		var target_key := _entity_target_key(projectile)
		if _purple_hit_targets.has(target_key):
			continue
		var threshold := _purple_erase_radius + projectile.radius
		if projectile.pos.distance_squared_to(pos) > threshold * threshold:
			continue
		_purple_hit_targets[target_key] = true
		if projectile.can_receive_attack(owner_side):
			battle.damage_entity(projectile, _damage_amount, _native_color, owner_side)
		else:
			projectile.removed = true
		battle.spawn_ring(projectile.pos, _native_color, 2.0, threshold * 1.5, 0.2)
		battle.record_stat("gojo_purple_projectiles_erased")

func _update_hit_contacts(delta: float) -> void:
	for key: String in _hit_cooldowns.keys():
		var cooldown := maxf(0.0, float(_hit_cooldowns[key]) - delta)
		if cooldown <= EPSILON:
			_hit_cooldowns.erase(key)
		else:
			_hit_cooldowns[key] = cooldown
	for key: String in _contact_targets.keys():
		var target_ref: WeakRef = _contact_targets[key]
		var target = target_ref.get_ref()
		if target == null:
			_contact_targets.erase(key)
			continue
		var release_distance: float = radius + target.radius + CONTACT_RELEASE_MARGIN
		if pos.distance_squared_to(target.pos) > release_distance * release_distance:
			_contact_targets.erase(key)

func _target_hit_blocked(key: String) -> bool:
	return _purple_hit_targets.has(key) if technique_kind == PURPLE \
		else _contact_targets.has(key) or _hit_cooldowns.has(key)

func _first_body_hit(battle, start: Vector2, finish: Vector2) -> Dictionary:
	var result := {}
	for fighter in battle.hostile_fighters(owner_side):
		var key := _fighter_target_key(fighter)
		if _target_hit_blocked(key):
			continue
		var fraction := _segment_circle_hit_fraction(start, finish, fighter.pos, fighter.radius + radius)
		if fraction >= 0.0 and (result.is_empty() or fraction < float(result["fraction"])):
			result = {
				"kind": "fighter", "fraction": fraction, "fighter": fighter,
				"center": fighter.pos, "combined_radius": fighter.radius + radius, "key": key,
			}
	for entity: BallEntity in battle.damageable_entities(owner_side):
		var key := _entity_target_key(entity)
		if _target_hit_blocked(key):
			continue
		var fraction := _segment_circle_hit_fraction(start, finish, entity.pos, entity.radius + radius)
		if fraction >= 0.0 and (result.is_empty() or fraction < float(result["fraction"])):
			result = {
				"kind": "entity", "fraction": fraction, "entity": entity,
				"center": entity.pos, "combined_radius": entity.radius + radius, "key": key,
			}
	return result

func _resolve_hit(battle, hit: Dictionary) -> void:
	if removed:
		return
	var kind := String(hit.get("kind", ""))
	if kind == "wall":
		var wall_normal: Vector2 = hit.get("normal", Vector2.ZERO) as Vector2
		if wall_normal.length_squared() > EPSILON:
			velocity = velocity.bounce(wall_normal)
		pos += wall_normal * 0.6
		return
	if technique_kind == PURPLE:
		_explode(battle, hit)
		return
	var center: Vector2 = hit.get("center", pos) as Vector2
	var normal := pos - center
	if normal.length_squared() <= EPSILON:
		normal = -velocity
	if normal.length_squared() <= EPSILON:
		normal = Vector2.RIGHT
	normal = normal.normalized()
	var target_key := String(hit.get("key", ""))
	if not target_key.is_empty():
		var target = hit.get("fighter") if kind == "fighter" else hit.get("entity")
		_contact_targets[target_key] = weakref(target)
		_hit_cooldowns[target_key] = _hit_interval
	var applied := 0.0
	if kind == "fighter":
		applied = battle.damage(
			hit.get("fighter"),
			_damage_amount,
			_native_color,
			battle.owner_for_entity(self)
		)
	elif kind == "entity":
		applied = battle.damage_entity(
			hit.get("entity") as BallEntity,
			_damage_amount,
			_native_color,
			owner_side
		)
	if velocity.dot(normal) < 0.0:
		velocity = velocity.bounce(normal)
	pos = center + normal * (float(hit.get("combined_radius", radius)) + 0.6)
	if applied > 0.0 and _impact_impulse > 0.0:
		var impulse_direction := -normal
		if kind == "fighter":
			hit.get("fighter").velocity += impulse_direction * _impact_impulse
		elif kind == "entity":
			var hit_entity := hit.get("entity") as BallEntity
			if hit_entity != null:
				hit_entity.velocity += impulse_direction * _impact_impulse
	battle.spawn_ring(pos, _native_color, radius * 0.4, radius * 3.2, 0.2)
	battle.spawn_particles(pos, _native_color, 5, 125.0)
	battle.emit_combat_event("projectile_hit", 0.46)
	if applied > 0.0:
		battle.record_stat("gojo_%s_orb_hits" % technique_kind)

func _explode(battle, hit: Dictionary) -> void:
	removed = true
	remaining = 0.0
	velocity = Vector2.ZERO
	var source = battle.owner_for_entity(self)
	for fighter in battle.hostile_fighters(owner_side):
		if fighter != hit.get("fighter") and pos.distance_to(fighter.pos) > _purple_explosion_radius + fighter.radius:
			continue
		var key := _fighter_target_key(fighter)
		if _purple_hit_targets.has(key):
			continue
		_purple_hit_targets[key] = true
		if battle.damage(fighter, _damage_amount, _native_color, source) > 0.0:
			battle.record_stat("gojo_purple_orb_hits")
	for entity: BallEntity in battle.damageable_entities(owner_side):
		if entity != hit.get("entity") and pos.distance_to(entity.pos) > _purple_explosion_radius + entity.radius:
			continue
		var key := _entity_target_key(entity)
		if _purple_hit_targets.has(key):
			continue
		_purple_hit_targets[key] = true
		if battle.damage_entity(entity, _damage_amount, _native_color, owner_side) > 0.0:
			battle.record_stat("gojo_purple_orb_hits")

	var visual_radius := maxf(radius * 3.0, _purple_explosion_radius)
	var explosion: BallEntity = PurpleExplosionVfx.new(owner_side, pos, visual_radius, _purple_explosion_duration)
	explosion.owner_fighter_uid = owner_fighter_uid
	battle.add_entity(explosion)
	battle.spawn_particles(pos, _native_color, 28, 260.0)
	battle.spawn_particles(pos, Color("fbe5ff"), 12, 180.0)
	battle.emit_combat_event("projectile_hit", 1.0)
	battle.shake_camera(5.0)
	battle.record_stat("gojo_purple_explosions")

func _arena_wall_hit(start: Vector2, finish: Vector2, arena_size: Vector2) -> Dictionary:
	var result := {}
	var travel := finish - start
	var minimum := Vector2(radius, radius)
	var maximum := arena_size - minimum
	if finish.x < minimum.x and travel.x < -EPSILON:
		result = {"kind": "wall", "fraction": (minimum.x - start.x) / travel.x, "normal": Vector2.RIGHT}
	elif finish.x > maximum.x and travel.x > EPSILON:
		result = {"kind": "wall", "fraction": (maximum.x - start.x) / travel.x, "normal": Vector2.LEFT}
	if finish.y < minimum.y and travel.y < -EPSILON:
		var fraction := (minimum.y - start.y) / travel.y
		if result.is_empty() or fraction < float(result["fraction"]):
			result = {"kind": "wall", "fraction": fraction, "normal": Vector2.DOWN}
	elif finish.y > maximum.y and travel.y > EPSILON:
		var fraction := (maximum.y - start.y) / travel.y
		if result.is_empty() or fraction < float(result["fraction"]):
			result = {"kind": "wall", "fraction": fraction, "normal": Vector2.UP}
	if not result.is_empty():
		result["fraction"] = clampf(float(result["fraction"]), 0.0, 1.0)
	return result

func _segment_circle_hit_fraction(
	start: Vector2,
	finish: Vector2,
	center: Vector2,
	combined_radius: float
) -> float:
	var offset := start - center
	var radius_squared := combined_radius * combined_radius
	if offset.length_squared() <= radius_squared:
		return 0.0
	var segment := finish - start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= EPSILON:
		return -1.0
	var projection := offset.dot(segment)
	var discriminant := projection * projection - segment_length_squared * (
		offset.length_squared() - radius_squared
	)
	if discriminant < 0.0:
		return -1.0
	var fraction := (-projection - sqrt(discriminant)) / segment_length_squared
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0

func _fighter_target_key(fighter) -> String:
	return "fighter:%d" % int(fighter.fighter_uid)


func _entity_target_key(entity: BallEntity) -> String:
	return "entity:%d" % entity.get_instance_id()

func _kind_color(kind: String) -> Color:
	match kind:
		RED:
			return Color("ff4059")
		PURPLE:
			return Color("a94dff")
		_:
			return Color("45dfff")

func _kind_core_color(kind: String) -> Color:
	match kind:
		RED:
			return Color("ffe5d2")
		PURPLE:
			return Color("f1dcff")
		_:
			return Color("e7ffff")
