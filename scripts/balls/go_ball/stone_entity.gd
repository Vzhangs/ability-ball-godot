extends BallEntity

func combat_category() -> Dictionary:
	return {"id": "go_black" if _stone_color == StoneColor.BLACK else "go_white", "name": "黑子" if _stone_color == StoneColor.BLACK else "白子"}

enum StoneColor {
	BLACK,
	WHITE,
}

const EPSILON := 0.0001
const BLACK_COLOR := Color("111315")
const WHITE_COLOR := Color("f4f0df")
const BLACK_EDGE := Color("050607")
const WHITE_EDGE := Color("fffdf2")

var hp := 10.0
var max_hp := 10.0

var _intersection := Vector2i.ZERO
var _stone_color: StoneColor = StoneColor.BLACK
var _config: Dictionary = {}
var _age := 0.0
var _hit_flash := 0.0
var _fighter_contact_timer := 0.0
var _entity_contact_timers: Dictionary = {}
var _pending_wear_sources: Array[Dictionary] = []

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_board_intersection: Vector2i,
	spawn_stone_color: StoneColor,
	spawn_radius: float,
	config: Dictionary
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_intersection = spawn_board_intersection
	_stone_color = spawn_stone_color
	radius = maxf(1.0, spawn_radius)
	_config = config.duplicate(true)
	max_hp = maxf(1.0, float(_config["max_hp"]))
	hp = max_hp
	remaining = -1.0
	tags = PackedStringArray(["go_stone"])
	draw_layer = -3

func step(battle, delta: float) -> void:
	_age += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 5.4)
	_fighter_contact_timer = maxf(0.0, _fighter_contact_timer - delta)
	_tick_entity_contact_timers(delta)
	_apply_pending_wear(battle)
	if removed:
		return
	for entity: BallEntity in battle.entities():
		resolve_entity_collision(battle, entity)
	velocity = Vector2.ZERO

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var progress := placement_progress()
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var scale := lerpf(0.3, 1.0, eased) + sin(progress * PI) * 0.12
	var draw_radius := radius * context.scale_factor * scale
	var body := ownership_visual_color(native_color())
	var edge := ownership_visual_color(WHITE_EDGE if _stone_color == StoneColor.BLACK else BLACK_EDGE)
	var alpha := 0.58 if is_captured() else 1.0
	body.a *= alpha
	edge.a *= alpha
	canvas.draw_circle(center + Vector2(0.0, draw_radius * 0.22), draw_radius * 1.06, Color(0.0, 0.0, 0.0, 0.24 * alpha))
	canvas.draw_circle(center, draw_radius * 1.12, Color(edge.r, edge.g, edge.b, 0.13 * alpha))
	canvas.draw_circle(center, draw_radius, body)
	canvas.draw_circle(center, draw_radius, edge, false, maxf(1.1, draw_radius * 0.1))
	canvas.draw_circle(
		center + Vector2(-draw_radius * 0.27, -draw_radius * 0.3),
		draw_radius * 0.24,
		Color(1.0, 1.0, 1.0, 0.25 * alpha if _stone_color == StoneColor.BLACK else 0.58 * alpha)
	)
	if _hit_flash > 0.0:
		canvas.draw_circle(center, draw_radius, Color(1.0, 0.78, 0.32, _hit_flash * 0.62))
	if not is_captured():
		_draw_health_bar(canvas, center, draw_radius, edge)

func board_intersection() -> Vector2i:
	return _intersection

func stone_color() -> int:
	return _stone_color

func native_color() -> Color:
	return BLACK_COLOR if _stone_color == StoneColor.BLACK else WHITE_COLOR

func placement_progress() -> float:
	return clampf(_age / maxf(EPSILON, float(_config["placement_animation_duration"])), 0.0, 1.0)

func team_marker_world_height() -> float:
	return radius * 1.55

func participates_in_fighter_collision() -> bool:
	return not removed and not is_captured()

func fighter_collision_inverse_mass() -> float:
	return 0.0

func can_resolve_fighter_contact(fighter_side: int) -> bool:
	return (
		participates_in_fighter_collision()
		and is_hostile_to(fighter_side)
		and _fighter_contact_timer <= 0.0
	)

func begin_fighter_contact(fighter_side: int) -> void:
	_fighter_contact_timer = float(_config["contact_interval"])
	_pending_wear_sources.append({"side": fighter_side, "actor": combat_contact_source.duplicate(true)})

func participates_in_entity_collision() -> bool:
	return not removed and not is_captured()

func entity_collision_inverse_mass() -> float:
	return 0.0

func entity_contact_damage() -> float:
	return 0.0

func entity_contact_color() -> Color:
	return ownership_visual_color(native_color())

func can_resolve_entity_contact(other: BallEntity) -> bool:
	return (
		participates_in_entity_collision()
		and other != null
		and other.owner_side >= 0
		and other.owner_side != owner_side
		and float(_entity_contact_timers.get(other.get_instance_id(), 0.0)) <= 0.0
	)

func begin_entity_contact(other: BallEntity) -> void:
	if other == null:
		return
	_entity_contact_timers[other.get_instance_id()] = float(_config["contact_interval"])
	_pending_wear_sources.append({"side": other.owner_side, "actor": other.combat_identity()})

func resolve_entity_collision(battle, other: BallEntity) -> void:
	if (
		other == null
		or other == self
		or other.owner_side == owner_side
		or not participates_in_entity_collision()
		or not other.participates_in_entity_collision()
	):
		return
	var offset := other.pos - pos
	var minimum_distance := radius + other.radius
	var distance := offset.length()
	if distance >= minimum_distance:
		return
	var normal := offset / distance if distance > EPSILON else Vector2.RIGHT
	var overlap := minimum_distance - maxf(distance, EPSILON)
	var other_inverse_mass := maxf(0.0, other.entity_collision_inverse_mass())
	if other_inverse_mass > 0.0:
		other.pos += normal * overlap
		var relative_speed := (other.velocity - velocity).dot(normal)
		if relative_speed < 0.0:
			other.velocity += normal * -2.0 * relative_speed
	if not can_resolve_entity_contact(other) or not other.can_resolve_entity_contact(self):
		return
	begin_entity_contact(other)
	other.begin_entity_contact(self)
	var incoming_damage := maxf(0.0, other.entity_contact_damage())
	if incoming_damage > 0.0:
		battle.damage_entity(self, incoming_damage, other.entity_contact_color(), other.owner_side, true, other)

func can_receive_attack(source_side: int) -> bool:
	return not removed and not is_captured() and is_hostile_to(source_side)

func receive_attack(
	battle,
	amount: float,
	source_side: int,
	hit_color: Color
) -> float:
	if not can_receive_attack(source_side) or amount <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp = maxf(0.0, hp - applied)
	_hit_flash = 1.0
	if hp > 0.0:
		battle.spawn_particles(pos, hit_color, 3, 52.0)
		return applied
	removed = true
	battle.record_stat("go_stones_destroyed")
	battle.spawn_ring(pos, native_color(), radius, radius * 3.4, 0.3)
	battle.spawn_particles(pos, native_color(), 9, 104.0)
	battle.emit_combat_event("impact", 0.38)
	return applied

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return ownership_visual_color(native_color())

func on_ownership_transferred(
	_previous_owner_side: int,
	_new_owner_side: int,
	_new_owner_anchor
) -> void:
	_fighter_contact_timer = 0.0
	_entity_contact_timers.clear()
	_pending_wear_sources.clear()

func _apply_pending_wear(battle) -> void:
	if _pending_wear_sources.is_empty():
		return
	var sources := _pending_wear_sources.duplicate()
	_pending_wear_sources.clear()
	for source: Dictionary in sources:
		if removed:
			return
		battle.damage_entity(
			self,
			float(_config["collision_wear"]),
			Color("e4bd67"),
			int(source["side"]), true, source["actor"]
		)

func _tick_entity_contact_timers(delta: float) -> void:
	for key in _entity_contact_timers.keys():
		var timer := maxf(0.0, float(_entity_contact_timers[key]) - delta)
		if timer <= 0.0:
			_entity_contact_timers.erase(key)
		else:
			_entity_contact_timers[key] = timer

func _draw_health_bar(canvas: CanvasItem, center: Vector2, draw_radius: float, edge: Color) -> void:
	var size := Vector2(maxf(11.0, draw_radius * 1.75), maxf(1.8, draw_radius * 0.16))
	var bounds := Rect2(center + Vector2(-size.x * 0.5, -draw_radius - size.y - 2.5), size)
	canvas.draw_rect(bounds.grow(1.0), Color(0.01, 0.01, 0.01, 0.86))
	canvas.draw_rect(
		Rect2(bounds.position, Vector2(bounds.size.x * hp / maxf(1.0, max_hp), bounds.size.y)),
		Color(0.86, 0.68, 0.25, 0.96)
	)
	canvas.draw_rect(bounds, Color(edge.r, edge.g, edge.b, 0.72), false, 1.0)
