extends BallEntity

const IceSlowEffect := preload("res://scripts/balls/core/ice_slow_status_effect.gd")
const BurnStatusEffectScript := preload("res://scripts/balls/core/burn_status_effect.gd")

var damage_amount := 0.0
var projectile_kind := "basic"
var _color := Color.WHITE
var _ice_slow_multiplier := 1.0
var _ice_slow_duration := 0.0
var _burn_damage := 0.0
var _burn_tick_interval := 1.0
var _burn_duration := 0.0
var _boundary_padding := 0.0

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_velocity: Vector2,
	spawn_radius: float,
	spawn_damage: float,
	spawn_color: Color,
	duration: float,
	kind: String,
	ice_slow_multiplier: float,
	ice_slow_duration: float,
	burn_damage: float,
	burn_tick_interval: float,
	burn_duration: float,
	boundary_padding: float
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	velocity = spawn_velocity
	radius = spawn_radius
	damage_amount = spawn_damage
	_color = spawn_color
	remaining = duration
	projectile_kind = kind
	_ice_slow_multiplier = ice_slow_multiplier
	_ice_slow_duration = ice_slow_duration
	_burn_damage = burn_damage
	_burn_tick_interval = burn_tick_interval
	_burn_duration = burn_duration
	_boundary_padding = boundary_padding
	tags = PackedStringArray(["projectile", "plant_projectile"])
	draw_layer = -10

func tick_lifetime(_delta: float) -> void:
	pass

func step(battle, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	var start := pos
	var finish := pos + velocity * delta
	var target = battle.opponent_for_entity(self)
	var target_fraction := -1.0
	if target != null:
		target_fraction = _segment_circle_hit_fraction(start, finish, target.pos, target.radius + radius)
	var hit_entity: BallEntity = null
	for entity: BallEntity in battle.damageable_entities(owner_side):
		var entity_fraction := _segment_circle_hit_fraction(start, finish, entity.pos, entity.radius + radius)
		if entity_fraction >= 0.0 and (target_fraction < 0.0 or entity_fraction < target_fraction):
			target_fraction = entity_fraction
			hit_entity = entity
	var travel_finish := start.lerp(finish, target_fraction) if target_fraction >= 0.0 else finish
	pos = travel_finish
	if target_fraction >= 0.0:
		var applied := 0.0
		if hit_entity == null and target != null:
			var source = battle.owner_for_entity(self)
			applied = battle.damage(target, damage_amount, _color, source)
			_apply_hit_debuff(battle, target, applied)
		else:
			applied = battle.damage_entity(hit_entity, damage_amount, _color, owner_side)
			_apply_hit_debuff(battle, hit_entity, applied)
		battle.spawn_particles(pos, _color, 7 if projectile_kind == "fire" else 5, 112.0)
		battle.emit_combat_event("projectile_hit", 0.5 if applied > 0.0 else 0.3)
		removed = true
		return
	pos = travel_finish
	var arena_size: Vector2 = battle.arena_size()
	if (
		remaining <= 0.0
		or pos.x < -_boundary_padding
		or pos.x > arena_size.x + _boundary_padding
		or pos.y < -_boundary_padding
		or pos.y > arena_size.y + _boundary_padding
	):
		removed = true

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var position := screen_position(context)
	var draw_radius := radius * scale_factor
	var color := ownership_visual_color(_color)
	var tail_direction := -velocity.normalized() if velocity.length_squared() > 0.001 else Vector2.LEFT
	var tail_length := minf(28.0, velocity.length() * 0.07) * scale_factor
	canvas.draw_line(position, position + tail_direction * tail_length, Color(color.r, color.g, color.b, 0.42), maxf(1.5, draw_radius * 0.72), true)
	canvas.draw_circle(position, draw_radius * 1.85, Color(color.r, color.g, color.b, 0.2))
	canvas.draw_circle(position, draw_radius, color)
	canvas.draw_circle(position - tail_direction * draw_radius * 0.18, draw_radius * 0.34, Color(1.0, 1.0, 1.0, 0.82))
	if projectile_kind == "fire":
		canvas.draw_colored_polygon(PackedVector2Array([
			position + tail_direction * draw_radius * 0.65,
			position + tail_direction * draw_radius * 2.2 + tail_direction.rotated(PI * 0.5) * draw_radius * 0.5,
			position + tail_direction * draw_radius * 2.2 - tail_direction.rotated(PI * 0.5) * draw_radius * 0.5,
		]), Color(1.0, 0.36, 0.06, 0.72))
	elif projectile_kind == "ice":
		canvas.draw_arc(position, draw_radius * 1.4, 0.0, TAU, 12, Color(0.74, 0.98, 1.0, 0.82), 1.2, true)
	if is_captured():
		canvas.draw_arc(position, draw_radius * 1.7, context.elapsed * 8.0, context.elapsed * 8.0 + PI * 1.35, 16, color, 1.5, true)

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_visual_color() -> Color:
	return ownership_visual_color(_color)

func _apply_hit_debuff(battle, target, applied_damage: float) -> void:
	if applied_damage <= 0.0 or target == null:
		return
	if target is BallEntity and (target as BallEntity).removed:
		return
	if projectile_kind == "ice":
		battle.apply_status(target, IceSlowEffect.new(
			_ice_slow_duration,
			owner_side,
			_ice_slow_multiplier
		))
	elif projectile_kind == "fire":
		battle.apply_status(target, BurnStatusEffectScript.new(
			_burn_duration,
			owner_side,
			_burn_damage,
			_burn_tick_interval,
			"plant_fire_pea",
			Color("ff6724")
		))
		battle.record_stat("plant_burns_applied")

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
	var discriminant := projection * projection - segment_length_squared * (offset.length_squared() - radius_squared)
	if discriminant < 0.0:
		return -1.0
	var fraction := (-projection - sqrt(discriminant)) / segment_length_squared
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0
