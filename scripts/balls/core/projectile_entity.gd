class_name BallProjectileEntity
extends BallEntity

const Glow := preload("res://scripts/balls/core/combat_glow.gd")

var damage_amount := 0.0
var color := Color.WHITE
var projectile_type := "generic"

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_velocity: Vector2,
	spawn_radius: float,
	spawn_damage: float,
	spawn_color: Color,
	duration: float,
	type_id: String
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	velocity = spawn_velocity
	radius = spawn_radius
	damage_amount = spawn_damage
	color = spawn_color
	remaining = duration
	projectile_type = type_id
	tags = PackedStringArray(["projectile"])
	draw_layer = -10

func tick_lifetime(_delta: float) -> void:
	# Projectiles are spawned during the ability update pass, so their lifetime advances in
	# step() to keep both new and existing projectiles on the same gameplay timeline.
	pass

func step(battle, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	var start := pos
	var finish := pos + velocity * delta
	var target = null
	var target_fraction := -1.0
	for hostile in battle.hostile_fighters(owner_side):
		var hostile_fraction := _segment_circle_hit_fraction(
			start,
			finish,
			hostile.pos,
			hostile.radius + radius
		)
		if hostile_fraction >= 0.0 and (target_fraction < 0.0 or hostile_fraction < target_fraction):
			target = hostile
			target_fraction = hostile_fraction
	var hit_entity: BallEntity = null
	for entity: BallEntity in battle.damageable_entities(owner_side):
		var entity_fraction := _segment_circle_hit_fraction(start, finish, entity.pos, entity.radius + radius)
		if entity_fraction >= 0.0 and (target_fraction < 0.0 or entity_fraction < target_fraction):
			target_fraction = entity_fraction
			hit_entity = entity
	var travel_finish := start.lerp(finish, target_fraction) if target_fraction >= 0.0 else finish
	pos = travel_finish
	if target_fraction >= 0.0:
		var source = battle.owner_for_entity(self)
		if hit_entity == null and target != null:
			battle.damage(target, damage_amount, color, source)
		else:
			battle.damage_entity(hit_entity, damage_amount, color, owner_side)
		battle.spawn_particles(pos, color, 5, 100.0)
		battle.emit_combat_event("projectile_hit", 0.48)
		removed = true
		return
	pos = travel_finish
	var arena_size: Vector2 = battle.arena_size()
	if remaining <= 0.0 or pos.x < -20.0 or pos.x > arena_size.x + 20.0 or pos.y < -20.0 or pos.y > arena_size.y + 20.0:
		removed = true

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var position := screen_position(context)
	var draw_radius := radius * scale_factor
	if velocity.length_squared() > 1.0:
		var tail_length := minf(34.0, velocity.length() * 0.09) * scale_factor
		Glow.streak(canvas, position - velocity.normalized() * tail_length, position, Color(color, 0.58), maxf(1.0, draw_radius * 0.60))
	Glow.halo(canvas, position, draw_radius * 4.0, Color(color, 0.42))
	canvas.draw_circle(position, draw_radius, color)
	canvas.draw_circle(position, draw_radius * 0.42, Color.WHITE)
	if is_captured():
		canvas.draw_arc(position, draw_radius * 1.65, context.elapsed * 8.0, context.elapsed * 8.0 + PI * 1.35, 16, color, 1.5, true)

func is_absorbable() -> bool:
	return true

## Projectiles can be captured or absorbed, but allegiance control never reflects them.
func can_transfer_ownership() -> bool:
	return false

func absorption_visual_color() -> Color:
	return color

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
