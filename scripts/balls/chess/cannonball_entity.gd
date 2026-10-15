extends BallEntity

const CannonBlastEntity := preload("res://scripts/balls/chess/cannon_blast_entity.gd")
const EPSILON := 0.0001

var _damage := 0.0
var _explosion_radius := 0.0
var _blast_duration := 0.5
var _body_color := Color("a92120")
var _accent_color := Color("f6d89a")

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_velocity: Vector2,
	spawn_radius: float,
	spawn_damage: float,
	spawn_explosion_radius: float,
	duration: float,
	blast_duration: float,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	velocity = spawn_velocity
	radius = spawn_radius
	_damage = maxf(0.0, spawn_damage)
	_explosion_radius = maxf(radius, spawn_explosion_radius)
	_blast_duration = maxf(0.05, blast_duration)
	remaining = maxf(0.0, duration)
	_body_color = body_color
	_accent_color = accent_color
	tags = PackedStringArray(["projectile", "chess_cannonball"])
	draw_layer = 8

func tick_lifetime(_delta: float) -> void:
	# This projectile is spawned during the ability pass, so step() owns its whole timeline.
	pass

func step(battle, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	var start := pos
	var finish := pos + velocity * delta
	var hit_fraction := -1.0
	var opponent = battle.opponent_for_entity(self)
	if opponent != null:
		hit_fraction = _segment_circle_hit_fraction(
			start,
			finish,
			opponent.pos,
			opponent.radius + radius
		)
	for entity: BallEntity in battle.damageable_entities(owner_side):
		var entity_fraction := _segment_circle_hit_fraction(
			start,
			finish,
			entity.pos,
			entity.radius + radius
		)
		if entity_fraction >= 0.0 and (hit_fraction < 0.0 or entity_fraction < hit_fraction):
			hit_fraction = entity_fraction
	var travel_finish := start.lerp(finish, hit_fraction) if hit_fraction >= 0.0 else finish
	pos = travel_finish
	if hit_fraction >= 0.0:
		_explode(battle)
		return
	pos = travel_finish
	var arena_size: Vector2 = battle.arena_size()
	var touched_wall := (
		pos.x <= radius
		or pos.x >= arena_size.x - radius
		or pos.y <= radius
		or pos.y >= arena_size.y - radius
	)
	if touched_wall:
		pos.x = clampf(pos.x, radius, arena_size.x - radius)
		pos.y = clampf(pos.y, radius, arena_size.y - radius)
		_explode(battle)
	elif remaining <= 0.0:
		_explode(battle)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var draw_radius := radius * context.scale_factor
	var body := ownership_visual_color(_body_color)
	var accent := ownership_visual_color(_accent_color)
	var alpha := 0.58 if is_captured() else 1.0
	var direction := velocity.normalized()
	if direction.length_squared() > EPSILON:
		var tail := direction * minf(58.0, velocity.length() * 0.12) * context.scale_factor
		canvas.draw_line(
			center + direction * draw_radius * 0.15,
			center - tail,
			Color(body.r, body.g, body.b, 0.28 * alpha),
			maxf(3.0, draw_radius * 2.2),
			true
		)
		canvas.draw_line(
			center,
			center - tail * 0.86,
			Color(accent.r, accent.g, accent.b, 0.76 * alpha),
			maxf(2.0, draw_radius * 1.08),
			true
		)
		canvas.draw_line(
			center,
			center - tail * 0.58,
			Color(1.0, 0.96, 0.76, 0.92 * alpha),
			maxf(1.2, draw_radius * 0.38),
			true
		)
	var pulse := 0.88 + sin(context.elapsed * 19.0 + owner_side) * 0.12
	canvas.draw_circle(center, draw_radius * 3.25 * pulse, Color(accent.r, accent.g, accent.b, 0.13 * alpha))
	canvas.draw_circle(center, draw_radius * 1.38, Color(0.11, 0.035, 0.02, alpha))
	canvas.draw_circle(center, draw_radius * 1.08, Color(body.r, body.g, body.b, alpha))
	canvas.draw_circle(center, draw_radius * 0.67, Color(1.0, 0.78, 0.28, alpha))
	canvas.draw_circle(center, draw_radius * 0.34, Color(1.0, 0.98, 0.84, alpha))
	for arc_index in range(2):
		var start := context.elapsed * (7.0 + arc_index * 2.0) + arc_index * PI
		canvas.draw_arc(
			center,
			draw_radius * (1.52 + arc_index * 0.28),
			start,
			start + PI * 0.92,
			18,
			Color(accent.r, accent.g, accent.b, (0.82 - arc_index * 0.22) * alpha),
			maxf(1.0, draw_radius * (0.18 - arc_index * 0.03)),
			true
		)
	if is_captured():
		canvas.draw_arc(center, draw_radius * 1.5, context.elapsed * 7.0, context.elapsed * 7.0 + PI * 1.4, 18, accent, 1.5, true)

func explosion_radius() -> float:
	return _explosion_radius

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	# A cannonball may be captured or swallowed, but mind control never reflects projectiles.
	return false

func absorption_visual_color() -> Color:
	return ownership_visual_color(_body_color)

func _explode(battle) -> void:
	if removed:
		return
	removed = true

	var source = battle.owner_for_entity(self)
	var opponent = battle.opponent_for_entity(self)
	if opponent != null and opponent.pos.distance_squared_to(pos) <= pow(_explosion_radius + opponent.radius, 2.0):
		battle.damage(opponent, _damage, _accent_color, source)
	for entity: BallEntity in battle.damageable_entities_in_circle(owner_side, pos, _explosion_radius):
		battle.damage_entity(entity, _damage, _accent_color, owner_side)
	battle.add_entity(CannonBlastEntity.new(
		owner_side,
		pos,
		_explosion_radius,
		_blast_duration,
		_body_color,
		_accent_color
	))
	battle.spawn_ring(pos, Color.WHITE, radius * 0.5, _explosion_radius * 1.12, 0.3)
	battle.spawn_ring(pos, _accent_color, radius * 0.8, _explosion_radius, 0.42)
	battle.spawn_ring(pos, _body_color, radius * 0.4, _explosion_radius * 0.76, 0.28)
	battle.spawn_particles(pos, _accent_color, 32, 248.0)
	battle.shake_camera(4.8)
	battle.emit_combat_event("projectile_hit", 0.9)
	battle.record_stat("chess_cannon_explosions")

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
	var discriminant := projection * projection - segment_length_squared * (offset.length_squared() - radius_squared)
	if discriminant < 0.0:
		return -1.0
	var fraction := (-projection - sqrt(discriminant)) / segment_length_squared
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0
