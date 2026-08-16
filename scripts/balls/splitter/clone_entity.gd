extends BallEntity

const BODY_RADIUS := 13.0
const MAX_HP := 12.0
const CONTACT_DAMAGE := 2.0
const IMPACT_WEAR := 2.0
const CONTACT_INTERVAL := 0.32
const MINIMUM_SPEED := 175.0
const MAXIMUM_SPEED := 285.0
const HEALTH_BARS_PER_ROW := 1
const HEALTH_BAR_WIDTH := 40.0
const HEALTH_BAR_HEIGHT := 2.0
const HEALTH_BAR_VERTICAL_GAP := 2.0
const HEALTH_BAR_TOP_GAP := 8.0

var hp := MAX_HP
var max_hp := MAX_HP

var _clone_id := 0
var _health_bar_index := 0
var _color := Color.WHITE
var _accent := Color.WHITE
var _contact_timer := 0.0
var _hit_flash := 0.0

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_velocity: Vector2,
	color: Color,
	accent: Color,
	spawn_clone_id: int
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	velocity = spawn_velocity
	radius = BODY_RADIUS
	_color = color
	_accent = accent
	_clone_id = spawn_clone_id
	tags = PackedStringArray(["clone", "splitter_clone"])
	draw_layer = -5

func clone_id() -> int:
	return _clone_id

func health_bar_index() -> int:
	return _health_bar_index

func set_health_bar_index(index: int) -> void:
	_health_bar_index = maxi(0, index)

func step(battle, delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta * 5.5)
	_normalize_speed()
	pos += velocity * delta
	_resolve_wall_collision(battle)
	_resolve_fighter_collision(battle)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var position := screen_position(context)
	var draw_radius := radius * scale_factor
	var body_color := _color
	body_color.a = 0.86 if not is_captured() else 0.62
	canvas.draw_circle(position, draw_radius * 1.28, Color(_accent.r, _accent.g, _accent.b, 0.2))
	canvas.draw_circle(position, draw_radius, body_color)
	canvas.draw_circle(position, draw_radius, _accent, false, maxf(1.0, 1.4 * scale_factor))
	canvas.draw_line(
		position + Vector2(-draw_radius * 0.5, -draw_radius * 0.22),
		position + Vector2(draw_radius * 0.5, draw_radius * 0.22),
		Color(0.94, 1.0, 1.0, 0.8),
		maxf(1.0, 1.5 * scale_factor),
		true
	)
	if _hit_flash > 0.0:
		canvas.draw_circle(position, draw_radius, Color(1.0, 1.0, 1.0, _hit_flash * 0.7))

func draw_hud(canvas: CanvasItem, health_bar_bounds: Rect2) -> void:
	if is_captured():
		return
	var bounds := mini_health_bar_bounds(health_bar_bounds)
	canvas.draw_rect(bounds.grow(1.0), Color(0.01, 0.035, 0.05, 0.92))
	canvas.draw_rect(Rect2(bounds.position, Vector2(bounds.size.x * hp / max_hp, bounds.size.y)), _accent)
	canvas.draw_rect(bounds, Color(0.82, 0.98, 1.0, 0.72), false, 1.0)

func mini_health_bar_bounds(main_health_bar_bounds: Rect2) -> Rect2:
	var row_left := (
		main_health_bar_bounds.position.x
		if owner_side == 0
		else main_health_bar_bounds.end.x - HEALTH_BAR_WIDTH
	)
	var top_left := Vector2(
		row_left,
		main_health_bar_bounds.end.y + HEALTH_BAR_TOP_GAP
		+ _health_bar_index * (HEALTH_BAR_HEIGHT + HEALTH_BAR_VERTICAL_GAP)
	)
	return Rect2(top_left, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT))

func can_receive_attack(source_side: int) -> bool:
	return not removed and not is_captured() and is_hostile_to(source_side)

func receive_attack(
	battle,
	amount: float,
	source_side: int,
	hit_color: Color
) -> float:
	if not can_receive_attack(source_side):
		return 0.0
	var applied := _receive_damage(battle, amount)
	if applied > 0.0:
		battle.spawn_particles(pos, hit_color, 3, 76.0)
	return applied

func receive_collision_damage(battle, amount: float) -> float:
	return _receive_damage(battle, amount)

func _receive_damage(battle, amount: float) -> float:
	if removed or amount <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp = maxf(0.0, hp - applied)
	_hit_flash = 1.0
	battle.record_stat("clone_damage_taken", int(ceil(applied)))
	if hp > 0.0:
		return applied
	removed = true
	battle.record_stat("clones_destroyed")
	battle.spawn_ring(pos, _accent, radius, 52.0, 0.28)
	battle.spawn_particles(pos, _color, 9, 130.0)
	battle.emit_combat_event("impact", 0.42)
	return applied

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return _color

func _normalize_speed() -> void:
	if velocity.length_squared() <= 0.001:
		velocity = Vector2.RIGHT.rotated(float(_clone_id) * 1.618) * MINIMUM_SPEED
		return
	var speed := velocity.length()
	if speed < MINIMUM_SPEED:
		velocity = velocity.normalized() * MINIMUM_SPEED
	elif speed > MAXIMUM_SPEED:
		velocity = velocity.normalized() * MAXIMUM_SPEED

func _resolve_wall_collision(battle) -> void:
	var arena_size: Vector2 = battle.arena_size()
	var bounced := false
	if pos.x < radius:
		pos.x = radius
		velocity.x = absf(velocity.x)
		bounced = true
	elif pos.x > arena_size.x - radius:
		pos.x = arena_size.x - radius
		velocity.x = -absf(velocity.x)
		bounced = true
	if pos.y < radius:
		pos.y = radius
		velocity.y = absf(velocity.y)
		bounced = true
	elif pos.y > arena_size.y - radius:
		pos.y = arena_size.y - radius
		velocity.y = -absf(velocity.y)
		bounced = true
	if bounced:
		velocity = velocity.rotated(battle.random_range(-0.045, 0.045))
		battle.spawn_particles(pos, _accent, 2, 48.0)

func _resolve_fighter_collision(battle) -> void:
	var target = battle.opponent_for_side(owner_side)
	var offset: Vector2 = target.pos - pos
	var minimum_distance: float = radius + target.radius
	var distance := offset.length()
	if distance >= minimum_distance:
		return
	var normal := offset / distance if distance > 0.001 else velocity.normalized()
	if normal.length_squared() <= 0.001:
		normal = Vector2.RIGHT
	pos -= normal * (minimum_distance - maxf(distance, 0.001))
	if velocity.dot(normal) > 0.0:
		velocity = velocity.bounce(normal) + target.velocity * 0.12
	if _contact_timer > 0.0:
		return
	_contact_timer = CONTACT_INTERVAL
	var source = battle.fighter_for_side(owner_side)
	battle.damage(target, CONTACT_DAMAGE, _accent, source)
	var target_side: int = battle.side_for_fighter(target)
	var counter_damage: float = battle.contact_damage_for_side(target_side, self)
	if counter_damage > 0.0:
		battle.damage_entity(self, counter_damage, target.accent, target_side)
	if not removed:
		receive_collision_damage(battle, IMPACT_WEAR)
	battle.record_stat("clone_contact_hits")
	battle.spawn_ring(pos + normal * radius, _accent, 4.0, 32.0, 0.2)
	battle.spawn_particles(pos + normal * radius, _accent, 4, 92.0)
	battle.emit_combat_event("impact", 0.25)

func resolve_clone_collision(battle, other: BallEntity) -> void:
	if other == self or removed or other.removed:
		return
	var offset: Vector2 = other.pos - pos
	var minimum_distance: float = radius + other.radius
	var distance := offset.length()
	if distance >= minimum_distance:
		return
	var normal := offset / distance if distance > 0.001 else Vector2.RIGHT
	var overlap := minimum_distance - maxf(distance, 0.001)
	pos -= normal * overlap * 0.5
	other.pos += normal * overlap * 0.5
	var relative_speed: float = (other.velocity - velocity).dot(normal)
	if relative_speed < 0.0:
		var impulse: float = -relative_speed
		velocity -= normal * impulse
		other.velocity += normal * impulse
	if owner_side == other.owner_side or _contact_timer > 0.0 or not bool(other.call("can_receive_clone_contact")):
		return
	_contact_timer = CONTACT_INTERVAL
	other.call("begin_clone_contact")
	receive_collision_damage(battle, CONTACT_DAMAGE)
	other.call("receive_collision_damage", battle, CONTACT_DAMAGE)
	battle.record_stat("clone_duel_hits")

func can_receive_clone_contact() -> bool:
	return not removed and _contact_timer <= 0.0

func begin_clone_contact() -> void:
	_contact_timer = CONTACT_INTERVAL
