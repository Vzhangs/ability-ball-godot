extends BallEntity

const IronCurtainZoneEntity := preload("res://scripts/balls/iron_curtain/iron_curtain_zone_entity.gd")
const EPSILON := 0.0001

var _field_duration := 4.0
var _field_radius := 94.0
var _damage_interval := 0.5
var _impact_damage := 10.0
var _hazard_damage := 2.0
var _field_absorption_radius := 22.0
var _maximum_active_fields := 8

func _init(spawn_owner_side: int, spawn_position: Vector2, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	velocity = config.get("velocity", Vector2.ZERO) as Vector2
	radius = maxf(1.0, float(config.get("radius", 13.0)))
	remaining = maxf(0.1, float(config.get("duration", 5.0)))
	_impact_damage = maxf(0.0, float(config.get("impact_damage", 10.0)))
	_field_duration = maxf(0.1, float(config.get("field_duration", 4.0)))
	_field_radius = maxf(1.0, float(config.get("field_radius", 94.0)))
	_damage_interval = maxf(0.01, float(config.get("damage_interval", 0.5)))
	_hazard_damage = maxf(0.0, float(config.get("damage", 2.0)))
	_field_absorption_radius = maxf(1.0, float(config.get("field_absorption_radius", 22.0)))
	_maximum_active_fields = maxi(1, int(config.get("maximum_active_fields", 8)))
	tags = PackedStringArray(["projectile", "iron_dragon_projectile"])
	draw_layer = 10

func tick_lifetime(_delta: float) -> void:
	# step() owns motion and the impact fallback at the end of the configured lifetime.
	pass

func step(battle, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	var start := pos
	var finish := pos + velocity * delta
	var hit := _first_body_hit(battle, start, finish)
	var hit_fraction := float(hit.get("fraction", -1.0))
	var wall_fraction := _arena_wall_hit_fraction(start, finish, battle.arena_size())
	if wall_fraction >= 0.0 and (hit_fraction < 0.0 or wall_fraction < hit_fraction):
		hit = {"kind": "wall", "fraction": wall_fraction}
		hit_fraction = wall_fraction
	var travel_finish := start.lerp(finish, hit_fraction) if hit_fraction >= 0.0 else finish
	pos = travel_finish
	if hit_fraction >= 0.0:
		_apply_impact_damage(battle, hit)
		_deploy_hazard_field(battle)
		return
	pos = travel_finish
	if remaining <= 0.0:
		_deploy_hazard_field(battle)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var draw_radius := radius * context.scale_factor
	var direction := velocity.normalized()
	var alpha := 0.44 if is_captured() else 1.0
	if direction.length_squared() > EPSILON:
		var tail_length := draw_radius * 5.4
		canvas.draw_line(center, center - direction * tail_length, Color(0.65, 0.02, 0.03, 0.2 * alpha), draw_radius * 2.7, true)
		canvas.draw_line(center, center - direction * tail_length * 0.82, Color(1.0, 0.13, 0.08, 0.58 * alpha), draw_radius * 1.2, true)
		canvas.draw_line(center, center - direction * tail_length * 0.54, Color(1.0, 0.76, 0.56, 0.86 * alpha), maxf(1.4, draw_radius * 0.36), true)
	var pulse := 0.9 + 0.1 * sin(context.elapsed * 18.0 + owner_side)
	canvas.draw_circle(center, draw_radius * 2.5 * pulse, Color(1.0, 0.06, 0.04, 0.14 * alpha))
	canvas.draw_circle(center, draw_radius * 1.36, Color(0.08, 0.01, 0.015, 0.96 * alpha))
	canvas.draw_circle(center, draw_radius * 1.05, Color(0.74, 0.03, 0.04, alpha))
	canvas.draw_circle(center, draw_radius * 0.68, Color(1.0, 0.22, 0.12, alpha))
	canvas.draw_circle(center - direction * draw_radius * 0.12, draw_radius * 0.32, Color(1.0, 0.88, 0.72, alpha))
	for arc_index in range(3):
		var angle := context.elapsed * (7.0 + arc_index * 1.7) + arc_index * TAU / 3.0
		canvas.draw_arc(center, draw_radius * (1.48 + arc_index * 0.22), angle, angle + PI * 0.8, 18, Color(1.0, 0.28, 0.18, (0.78 - arc_index * 0.16) * alpha), maxf(1.0, draw_radius * 0.12), true)

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_visual_color() -> Color:
	return Color("ff3227")

func _deploy_hazard_field(battle) -> void:
	if removed:
		return
	removed = true
	var owned_fields: Array[BallEntity] = []
	for entity: BallEntity in battle.entities(-1, "iron_curtain_field"):
		if entity.owner_fighter_uid == owner_fighter_uid:
			owned_fields.append(entity)
	while owned_fields.size() >= _maximum_active_fields:
		owned_fields.pop_front().removed = true
	var field: BallEntity = IronCurtainZoneEntity.new(owner_side, pos, {
		"mode": "hazard",
		"duration": _field_duration,
		"radius": _field_radius,
		"damage_interval": _damage_interval,
		"damage": _hazard_damage,
		"invulnerability_duration": 0.0,
		"absorption_radius": _field_absorption_radius,
	})
	field.owner_fighter_uid = owner_fighter_uid
	battle.add_entity(field)
	battle.spawn_ring(pos, Color("ff2c20"), radius * 0.6, _field_radius * 1.08, 0.46)
	battle.spawn_ring(pos, Color("290306"), radius * 1.4, _field_radius * 0.78, 0.32)
	battle.spawn_particles(pos, Color("ff4938"), 24, 238.0)
	battle.emit_combat_event("projectile_hit", 0.94)
	battle.shake_camera(5.0)
	battle.record_stat("iron_dragon_hazard_fields_deployed")

func _apply_impact_damage(battle, hit: Dictionary) -> void:
	if _impact_damage <= EPSILON:
		return
	var applied := 0.0
	match String(hit.get("kind", "")):
		"fighter":
			applied = battle.damage(
				hit.get("fighter"),
				_impact_damage,
				Color("ff715d"),
				battle.owner_for_entity(self)
			)
		"entity":
			applied = battle.damage_entity(
				hit.get("entity") as BallEntity,
				_impact_damage,
				Color("ff715d"),
				owner_side
			)
	if applied > 0.0:
		battle.record_stat("iron_dragon_projectile_hits")

func _first_body_hit(battle, start: Vector2, finish: Vector2) -> Dictionary:
	var result := {}
	for fighter in battle.hostile_fighters(owner_side):
		var fraction := _segment_circle_hit_fraction(start, finish, fighter.pos, fighter.radius + radius)
		if fraction >= 0.0 and (result.is_empty() or fraction < float(result["fraction"])):
			result = {"kind": "fighter", "fraction": fraction, "fighter": fighter}
	for entity: BallEntity in battle.damageable_entities(owner_side):
		var fraction := _segment_circle_hit_fraction(start, finish, entity.pos, entity.radius + radius)
		if fraction >= 0.0 and (result.is_empty() or fraction < float(result["fraction"])):
			result = {"kind": "entity", "fraction": fraction, "entity": entity}
	return result

func _arena_wall_hit_fraction(start: Vector2, finish: Vector2, arena_size: Vector2) -> float:
	var result := -1.0
	var minimum := Vector2(radius, radius)
	var maximum := arena_size - minimum
	var travel := finish - start
	if finish.x < minimum.x and travel.x < -EPSILON:
		result = (minimum.x - start.x) / travel.x
	elif finish.x > maximum.x and travel.x > EPSILON:
		result = (maximum.x - start.x) / travel.x
	if finish.y < minimum.y and travel.y < -EPSILON:
		var y_fraction := (minimum.y - start.y) / travel.y
		result = y_fraction if result < 0.0 else minf(result, y_fraction)
	elif finish.y > maximum.y and travel.y > EPSILON:
		var y_fraction := (maximum.y - start.y) / travel.y
		result = y_fraction if result < 0.0 else minf(result, y_fraction)
	return clampf(result, 0.0, 1.0) if result >= 0.0 else -1.0

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
