extends BallEntity

const HIT_EPSILON := 0.0001
const WALL_EPSILON := 0.00001

var damage_amount := 0.0
var color := Color.WHITE

var _remaining_damage := 0.0
var _initial_damage := 0.0
var _scatter_count := 1
var _scatter_damage := 0.0
var _scatter_speed := 0.0
var _scatter_radius := 1.0
var _scatter_spread_degrees := 0.0
var _scatter_lifetime := 1.0
var _hit_entity_ids := {}

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_velocity: Vector2,
	spawn_radius: float,
	spawn_damage: float,
	spawn_color: Color,
	duration: float,
	scatter_count: int,
	scatter_damage: float,
	scatter_speed: float,
	scatter_radius: float,
	scatter_spread_degrees: float,
	scatter_lifetime: float
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	velocity = spawn_velocity
	radius = spawn_radius
	damage_amount = maxf(0.0, spawn_damage)
	_remaining_damage = damage_amount
	_initial_damage = damage_amount
	color = spawn_color
	remaining = duration
	_scatter_count = maxi(1, scatter_count)
	_scatter_damage = maxf(0.0, scatter_damage)
	_scatter_speed = maxf(0.0, scatter_speed)
	_scatter_radius = maxf(0.1, scatter_radius)
	_scatter_spread_degrees = clampf(scatter_spread_degrees, 0.0, 360.0)
	_scatter_lifetime = maxf(0.01, scatter_lifetime)
	tags = PackedStringArray(["projectile", "sniper_round"])
	draw_layer = 18

func tick_lifetime(_delta: float) -> void:
	# Like the shared projectile, the round advances lifetime in step() so a newly fired
	# shot receives the same full movement tick as existing projectiles.
	pass

func step(battle, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0 or _remaining_damage <= HIT_EPSILON:
		removed = true
		return
	var start := pos
	var finish := pos + velocity * delta
	var wall_hit := _wall_intersection(start, finish, battle.arena_size())
	var travel_finish := finish
	if bool(wall_hit["hit"]):
		travel_finish = start.lerp(finish, float(wall_hit["fraction"]))
	var hits := _ordered_hits(battle, start, travel_finish)
	for hit: Dictionary in hits:
		pos = start.lerp(travel_finish, float(hit["fraction"]))
		if String(hit["kind"]) == "fighter":
			_hit_main_fighter(battle)
			return
		_hit_attachment(battle, hit["entity"] as BallEntity)
		if removed:
			return
	pos = travel_finish
	if bool(wall_hit["hit"]):
		_split_on_wall(battle, Vector2(wall_hit["normal"]))

func remaining_damage() -> float:
	return _remaining_damage

func penetration_count() -> int:
	return _hit_entity_ids.size()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var position := screen_position(context)
	var direction := velocity.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	var perpendicular := direction.orthogonal()
	var length := 38.0 * scale_factor
	var half_width := maxf(1.3, radius * scale_factor)
	var tip := position + direction * length * 0.58
	var rear := position - direction * length * 0.42
	var glow_color := color
	glow_color.a = 0.18
	canvas.draw_line(rear - direction * length * 0.65, tip, glow_color, half_width * 3.4, true)
	var outer := PackedVector2Array([
		tip,
		rear + perpendicular * half_width * 1.25,
		rear - perpendicular * half_width * 1.25,
	])
	var outer_color := color
	outer_color.a = 0.82
	canvas.draw_colored_polygon(outer, outer_color)
	var core_rear := position - direction * length * 0.27
	var core := PackedVector2Array([
		tip - direction * length * 0.06,
		core_rear + perpendicular * half_width * 0.36,
		core_rear - perpendicular * half_width * 0.36,
	])
	canvas.draw_colored_polygon(core, Color(1.0, 1.0, 1.0, 0.94))
	canvas.draw_line(
		rear - direction * length * 0.92,
		rear,
		Color(color.r, color.g, color.b, 0.44),
		maxf(1.0, half_width * 0.72),
		true
	)
	if is_captured():
		canvas.draw_arc(position, half_width * 2.6, context.elapsed * 7.0, context.elapsed * 7.0 + PI * 1.4, 18, color, maxf(1.2, half_width * 0.42), true)

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_visual_color() -> Color:
	return color

func _ordered_hits(battle, start: Vector2, finish: Vector2) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var target = battle.opponent_for_side(owner_side)
	var fighter_fraction := _segment_circle_hit_fraction(
		start,
		finish,
		target.pos,
		target.radius + radius
	)
	if fighter_fraction >= 0.0:
		hits.append({"kind": "fighter", "fraction": fighter_fraction, "order": 1000000})
	var entity_order := 0
	for entity: BallEntity in battle.damageable_entities(owner_side):
		var entity_id := entity.get_instance_id()
		if _hit_entity_ids.has(entity_id):
			entity_order += 1
			continue
		var entity_fraction := _segment_circle_hit_fraction(
			start,
			finish,
			entity.pos,
			entity.radius + radius
		)
		if entity_fraction >= 0.0:
			hits.append({
				"kind": "entity",
				"fraction": entity_fraction,
				"order": entity_order,
				"entity": entity,
			})
		entity_order += 1
	hits.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_fraction := float(left["fraction"])
		var right_fraction := float(right["fraction"])
		if not is_equal_approx(left_fraction, right_fraction):
			return left_fraction < right_fraction
		if String(left["kind"]) != String(right["kind"]):
			return String(left["kind"]) == "entity"
		return int(left["order"]) < int(right["order"])
	)
	return hits

func _hit_attachment(battle, entity: BallEntity) -> void:
	if entity == null:
		return
	_hit_entity_ids[entity.get_instance_id()] = true
	var applied: float = battle.damage_entity(
		entity,
		_remaining_damage,
		color,
		owner_side
	)
	if applied <= 0.0:
		return
	_remaining_damage = maxf(0.0, _remaining_damage - applied)
	damage_amount = _remaining_damage
	battle.spawn_particles(pos, entity.absorption_visual_color(), 6, 150.0)
	battle.spawn_ring(pos, color, 3.0, 30.0, 0.15)
	battle.emit_combat_event(
		"sniper_pierce",
		clampf(applied / maxf(1.0, _initial_damage), 0.22, 0.86)
	)
	battle.record_stat("sniper_penetrations")
	if _remaining_damage <= HIT_EPSILON:
		removed = true
		battle.record_stat("sniper_rounds_depleted")

func _hit_main_fighter(battle) -> void:
	var target = battle.opponent_for_side(owner_side)
	var source = battle.fighter_for_side(owner_side)
	battle.damage(target, _remaining_damage, color, source)
	battle.spawn_ring(pos, Color.WHITE, 6.0, 76.0, 0.28)
	battle.spawn_particles(pos, color, 13, 245.0)
	battle.emit_combat_event("sniper_hit", 1.0)
	battle.shake_camera(8.5)
	battle.record_stat("sniper_main_hits")
	removed = true

func _split_on_wall(battle, wall_normal: Vector2) -> void:
	var inward_normal := wall_normal.normalized()
	if inward_normal.length_squared() <= 0.0001:
		inward_normal = -velocity.normalized()
	var reflected := velocity.bounce(inward_normal).normalized()
	if reflected.length_squared() <= 0.0001:
		reflected = inward_normal
	var per_pellet_damage := minf(
		_scatter_damage,
		_remaining_damage / float(maxi(1, _scatter_count))
	)
	if per_pellet_damage > HIT_EPSILON:
		var half_spread := deg_to_rad(_scatter_spread_degrees) * 0.5
		var is_full_circle := _scatter_spread_degrees >= 359.999
		var spawn_position := pos + inward_normal * (_scatter_radius + 0.8)
		for index in range(_scatter_count):
			var scatter_angle := 0.0
			if _scatter_count > 1:
				if is_full_circle:
					scatter_angle = -PI + TAU * float(index) / float(_scatter_count)
				else:
					var ratio := float(index) / float(_scatter_count - 1)
					scatter_angle = lerpf(-half_spread, half_spread, ratio)
			var pellet_direction := reflected.rotated(scatter_angle)
			battle.add_projectile(
				owner_side,
				spawn_position,
				pellet_direction * _scatter_speed,
				_scatter_radius,
				per_pellet_damage,
				color,
				_scatter_lifetime,
				"sniper_scatter"
			)
		battle.record_stat("sniper_scatter_spawned", _scatter_count)
	battle.spawn_ring(pos, color, 4.0, 58.0, 0.24)
	battle.spawn_particles(pos, color, 16, 260.0)
	battle.emit_combat_event("sniper_wall_split", 0.88)
	battle.shake_camera(4.8)
	battle.record_stat("sniper_wall_splits")
	removed = true

func _wall_intersection(start: Vector2, finish: Vector2, arena_size: Vector2) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var delta := finish - start
	if finish.x < radius and delta.x < -WALL_EPSILON:
		candidates.append({"fraction": (radius - start.x) / delta.x, "normal": Vector2.RIGHT})
	if finish.x > arena_size.x - radius and delta.x > WALL_EPSILON:
		candidates.append({"fraction": (arena_size.x - radius - start.x) / delta.x, "normal": Vector2.LEFT})
	if finish.y < radius and delta.y < -WALL_EPSILON:
		candidates.append({"fraction": (radius - start.y) / delta.y, "normal": Vector2.DOWN})
	if finish.y > arena_size.y - radius and delta.y > WALL_EPSILON:
		candidates.append({"fraction": (arena_size.y - radius - start.y) / delta.y, "normal": Vector2.UP})
	var best_fraction := 2.0
	var normal := Vector2.ZERO
	for candidate: Dictionary in candidates:
		var fraction := float(candidate["fraction"])
		if fraction < -WALL_EPSILON or fraction > 1.0 + WALL_EPSILON:
			continue
		if fraction < best_fraction - WALL_EPSILON:
			best_fraction = fraction
			normal = Vector2(candidate["normal"])
		elif absf(fraction - best_fraction) <= WALL_EPSILON:
			normal += Vector2(candidate["normal"])
	if best_fraction > 1.0:
		return {"hit": false, "fraction": 1.0, "normal": Vector2.ZERO}
	return {
		"hit": true,
		"fraction": clampf(best_fraction, 0.0, 1.0),
		"normal": normal.normalized(),
	}

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
	if segment_length_squared <= 0.0001:
		return -1.0
	var projection := offset.dot(segment)
	var discriminant := projection * projection - segment_length_squared * (
		offset.length_squared() - radius_squared
	)
	if discriminant < 0.0:
		return -1.0
	var fraction := (-projection - sqrt(discriminant)) / segment_length_squared
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0
