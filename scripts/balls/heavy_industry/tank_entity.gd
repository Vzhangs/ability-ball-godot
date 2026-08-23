extends BallEntity

const WALL_EPSILON := 0.00001
const MAX_WALL_REVERSALS_PER_STEP := 4
const MUZZLE_FLASH_DURATION := 0.12
const TRACK_EDGE := Color("b9cbc7")
const TRACK_STEEL := Color("7e8b8e")
const TRACK_BELT := Color("263136")
const TRACK_TREAD := Color("c6d0cd")
const WHEEL_RIM := Color("b9c4c0")
const WHEEL_HUB := Color("3e4b50")

var hp := 15.0
var max_hp := 15.0

var _body_color := Color("59665a")
var _accent_color := Color("ffb72e")
var _config: Dictionary = {}
var _hull_direction := Vector2.RIGHT
var _turret_angle := 0.0
var _fire_timer := 0.0
var _fighter_contact_timer := 0.0
var _entity_contact_timers: Dictionary = {}
var _hit_flash := 0.0
var _muzzle_flash := 0.0
var _deployment_elapsed := 0.0

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_direction: Vector2,
	body_color: Color,
	accent_color: Color,
	config: Dictionary
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_config = config.duplicate(true)
	radius = float(_config["radius"])
	max_hp = float(_config["max_hp"])
	hp = max_hp
	_body_color = body_color
	_accent_color = accent_color
	_hull_direction = spawn_direction.normalized()
	if _hull_direction.length_squared() <= WALL_EPSILON:
		_hull_direction = Vector2.RIGHT if owner_side == 0 else Vector2.LEFT
	velocity = _hull_direction * float(_config["speed"])
	_turret_angle = _hull_direction.angle()
	_fire_timer = float(_config["fire_interval"])
	tags = PackedStringArray(["heavy_tank"])
	draw_layer = 6

func step(battle, delta: float) -> void:
	_deployment_elapsed += delta
	_hit_flash = maxf(0.0, _hit_flash - delta * 5.2)
	_muzzle_flash = maxf(0.0, _muzzle_flash - delta)
	_fighter_contact_timer = maxf(0.0, _fighter_contact_timer - delta)
	_tick_entity_contact_timers(delta)
	_update_turret(battle, delta)
	_move_on_patrol_line(battle, delta)
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer += float(_config["fire_interval"])
	_fire_shell(battle)

func deployment_progress() -> float:
	return clampf(
		_deployment_elapsed / maxf(0.001, float(_config["deployment_duration"])),
		0.0,
		1.0
	)

func turret_angle() -> float:
	return _turret_angle

func hull_direction() -> Vector2:
	return _hull_direction

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var position := screen_position(context)
	var scale_factor := context.scale_factor
	var draw_radius := radius * scale_factor
	var body_color := ownership_visual_color(_body_color)
	var accent := ownership_visual_color(_accent_color)
	var alpha := 0.62 if is_captured() else 1.0
	body_color.a *= alpha
	accent.a *= alpha
	var body_direction := _hull_direction
	if body_direction.length_squared() <= WALL_EPSILON:
		body_direction = Vector2.RIGHT
	var hull_perpendicular := body_direction.orthogonal()
	var deploy_scale := 0.42 + 0.58 * _ease_out_back(deployment_progress())
	var half_length := draw_radius * 1.18 * deploy_scale
	var half_width := draw_radius * 0.78 * deploy_scale
	canvas.draw_colored_polygon(
		_box_points(position + Vector2(0.0, draw_radius * 0.18), body_direction, hull_perpendicular, half_length * 1.02, half_width * 1.03),
		Color(0.0, 0.0, 0.0, 0.28 * alpha)
	)
	_draw_tracks(canvas, context, position, body_direction, hull_perpendicular, half_length, half_width, accent, alpha)
	_draw_hull(canvas, position, body_direction, hull_perpendicular, half_length, half_width, body_color, accent)
	_draw_turret(canvas, position, draw_radius, accent, alpha)
	if _hit_flash > 0.0:
		canvas.draw_circle(position, draw_radius * 1.02, Color(1.0, 1.0, 1.0, _hit_flash * 0.58))
	if not is_captured():
		_draw_health_bar(canvas, position, draw_radius, accent)

func participates_in_fighter_collision() -> bool:
	return not removed and not is_captured()

func fighter_collision_inverse_mass() -> float:
	# The tank is physically heavy: hostile fighters rebound while its patrol line stays exact.
	return 0.0

func can_resolve_fighter_contact(fighter_side: int) -> bool:
	return (
		participates_in_fighter_collision()
		and fighter_side >= 0
		and fighter_side != owner_side
		and _fighter_contact_timer <= 0.0
	)

func begin_fighter_contact(_fighter_side: int) -> void:
	_fighter_contact_timer = float(_config["contact_interval"])

func participates_in_entity_collision() -> bool:
	return not removed and not is_captured()

func entity_collision_inverse_mass() -> float:
	return 0.0

func entity_contact_damage() -> float:
	return float(_config["contact_damage"])

func entity_contact_color() -> Color:
	return ownership_visual_color(_accent_color)

func can_resolve_entity_contact(other: BallEntity) -> bool:
	return (
		participates_in_entity_collision()
		and other != null
		and other.owner_side >= 0
		and other.owner_side != owner_side
		and float(_entity_contact_timers.get(other.get_instance_id(), 0.0)) <= 0.0
	)

func begin_entity_contact(other: BallEntity) -> void:
	if other != null:
		_entity_contact_timers[other.get_instance_id()] = float(_config["contact_interval"])

func resolve_entity_collision(battle, other: BallEntity) -> void:
	if (
		other == null
		or other == self
		or other.owner_side == owner_side
		or not participates_in_entity_collision()
		or not other.participates_in_entity_collision()
	):
		return
	var offset: Vector2 = other.pos - pos
	var minimum_distance := radius + other.radius
	var distance := offset.length()
	if distance >= minimum_distance:
		return
	var normal := offset / distance if distance > WALL_EPSILON else _hull_direction.orthogonal()
	if normal.length_squared() <= WALL_EPSILON:
		normal = Vector2.RIGHT
	var overlap := minimum_distance - maxf(distance, WALL_EPSILON)
	var own_inverse_mass := maxf(0.0, entity_collision_inverse_mass())
	var other_inverse_mass := maxf(0.0, other.entity_collision_inverse_mass())
	var total_inverse_mass := own_inverse_mass + other_inverse_mass
	if total_inverse_mass > 0.0:
		pos -= normal * overlap * own_inverse_mass / total_inverse_mass
		other.pos += normal * overlap * other_inverse_mass / total_inverse_mass
	var relative_speed: float = (other.velocity - velocity).dot(normal)
	if relative_speed < 0.0 and total_inverse_mass > 0.0:
		var impulse := -2.0 * relative_speed / total_inverse_mass
		other.velocity += normal * impulse * other_inverse_mass
	if not can_resolve_entity_contact(other) or not other.can_resolve_entity_contact(self):
		return
	var damage_to_other := entity_contact_damage()
	var damage_to_self := other.entity_contact_damage()
	begin_entity_contact(other)
	other.begin_entity_contact(self)
	var applied_to_other: float = battle.damage_entity(
		other,
		damage_to_other,
		entity_contact_color(),
		owner_side
	)
	var applied_to_self: float = battle.damage_entity(
		self,
		damage_to_self,
		other.entity_contact_color(),
		other.owner_side
	)
	if applied_to_other <= 0.0 and applied_to_self <= 0.0:
		return
	battle.record_stat("heavy_tank_entity_contacts")
	battle.spawn_ring(pos + normal * radius, entity_contact_color(), 3.0, 32.0, 0.2)
	battle.spawn_particles(pos + normal * radius, entity_contact_color(), 5, 92.0)
	battle.emit_combat_event("clone_impact", 0.46)

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
	battle.record_stat("heavy_tank_damage_taken", int(ceil(applied)))
	if hp > 0.0:
		battle.spawn_particles(pos, hit_color, 3, 72.0)
		return applied
	removed = true
	battle.record_stat("heavy_tanks_destroyed")
	battle.spawn_ring(pos, absorption_visual_color(), radius, 62.0, 0.32)
	battle.spawn_particles(pos, absorption_visual_color(), 12, 138.0)
	battle.emit_combat_event("impact", 0.62)
	return applied

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return ownership_visual_color(_body_color)

func on_ownership_transferred(
	_previous_owner_side: int,
	_new_owner_side: int,
	_new_owner_anchor
) -> void:
	_fighter_contact_timer = 0.0
	_entity_contact_timers.clear()

func _update_turret(battle, delta: float) -> void:
	var target = battle.opponent_for_side(owner_side)
	if target == null:
		return
	var target_direction: Vector2 = target.pos - pos
	if target_direction.length_squared() <= WALL_EPSILON:
		return
	var difference := wrapf(target_direction.angle() - _turret_angle, -PI, PI)
	var maximum_turn := float(_config["turret_rotation_speed"]) * delta
	_turret_angle = wrapf(
		_turret_angle + clampf(difference, -maximum_turn, maximum_turn),
		-PI,
		PI
	)

func _move_on_patrol_line(battle, delta: float) -> void:
	var remaining_time := delta
	var arena_size: Vector2 = battle.arena_size()
	var minimum_bounds := Vector2(radius, radius)
	var maximum_bounds := arena_size - Vector2(radius, radius)
	for _reversal in range(MAX_WALL_REVERSALS_PER_STEP):
		if remaining_time <= WALL_EPSILON:
			break
		var hit_time := remaining_time + 1.0
		if velocity.x > WALL_EPSILON:
			hit_time = minf(hit_time, (maximum_bounds.x - pos.x) / velocity.x)
		elif velocity.x < -WALL_EPSILON:
			hit_time = minf(hit_time, (minimum_bounds.x - pos.x) / velocity.x)
		if velocity.y > WALL_EPSILON:
			hit_time = minf(hit_time, (maximum_bounds.y - pos.y) / velocity.y)
		elif velocity.y < -WALL_EPSILON:
			hit_time = minf(hit_time, (minimum_bounds.y - pos.y) / velocity.y)
		if hit_time < -WALL_EPSILON or hit_time > remaining_time:
			pos += velocity * remaining_time
			remaining_time = 0.0
			break
		var traveled_time := maxf(0.0, hit_time)
		pos += velocity * traveled_time
		pos.x = clampf(pos.x, minimum_bounds.x, maximum_bounds.x)
		pos.y = clampf(pos.y, minimum_bounds.y, maximum_bounds.y)
		remaining_time -= traveled_time
		velocity = -velocity
		_hull_direction = velocity.normalized()
		_on_wall_reversed(battle)
		if traveled_time <= WALL_EPSILON:
			remaining_time = maxf(0.0, remaining_time - WALL_EPSILON)
	if remaining_time > WALL_EPSILON:
		pos += velocity * remaining_time
	pos.x = clampf(pos.x, minimum_bounds.x, maximum_bounds.x)
	pos.y = clampf(pos.y, minimum_bounds.y, maximum_bounds.y)

func _on_wall_reversed(battle) -> void:
	battle.record_stat("heavy_tank_wall_reversals")
	battle.spawn_particles(pos, ownership_visual_color(_accent_color), 4, 64.0)
	battle.emit_combat_event("wall_impact", 0.16)

func _fire_shell(battle) -> void:
	var direction := Vector2.from_angle(_turret_angle)
	var shell_radius := float(_config["shell_radius"])
	var muzzle_distance := radius * 1.38 + shell_radius + float(_config["shell_spawn_gap"])
	var muzzle_position := pos + direction * muzzle_distance
	var arena_size: Vector2 = battle.arena_size()
	muzzle_position.x = clampf(muzzle_position.x, shell_radius, arena_size.x - shell_radius)
	muzzle_position.y = clampf(muzzle_position.y, shell_radius, arena_size.y - shell_radius)
	var shell_color := ownership_visual_color(_accent_color)
	battle.add_projectile(
		owner_side,
		muzzle_position,
		direction * float(_config["shell_speed"]),
		shell_radius,
		float(_config["shell_damage"]),
		shell_color,
		float(_config["shell_lifetime"]),
		"tank_shell"
	)
	battle.record_stat("heavy_tank_shells_fired")
	battle.spawn_ring(muzzle_position, Color.WHITE, 2.0, 25.0, 0.12)
	battle.spawn_particles(muzzle_position, shell_color, 5, 112.0)
	battle.emit_combat_event("volley", 0.62)
	_muzzle_flash = MUZZLE_FLASH_DURATION

func _tick_entity_contact_timers(delta: float) -> void:
	for entity_id in _entity_contact_timers.keys():
		var next_time := maxf(0.0, float(_entity_contact_timers[entity_id]) - delta)
		if next_time <= 0.0:
			_entity_contact_timers.erase(entity_id)
		else:
			_entity_contact_timers[entity_id] = next_time

func _draw_tracks(
	canvas: CanvasItem,
	context: BallRenderContext,
	position: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	half_length: float,
	half_width: float,
	accent: Color,
	alpha: float
) -> void:
	for side_sign in [-1.0, 1.0]:
		var track_center: Vector2 = position + perpendicular * half_width * 0.72 * side_sign
		var outer_track := _box_points(track_center, direction, perpendicular, half_length * 1.04, half_width * 0.36)
		var inner_track := _box_points(track_center, direction, perpendicular, half_length * 0.96, half_width * 0.27)
		var edge_color := TRACK_EDGE
		edge_color.a *= alpha
		var steel_color := TRACK_STEEL
		steel_color.a *= alpha
		var belt_color := TRACK_BELT
		belt_color.a *= alpha
		canvas.draw_colored_polygon(outer_track, steel_color)
		canvas.draw_polyline(_closed_polygon(outer_track), edge_color, maxf(1.35, half_width * 0.1), true)
		canvas.draw_colored_polygon(inner_track, belt_color)
		var tread_phase := fmod(context.elapsed * velocity.length() * 0.055, 1.0)
		for tread_index in range(7):
			var along_ratio := fmod(float(tread_index) / 7.0 + tread_phase, 1.0)
			var along := lerpf(-half_length * 0.82, half_length * 0.82, along_ratio)
			var tread_center: Vector2 = track_center + direction * along
			canvas.draw_line(
				tread_center - perpendicular * half_width * 0.3,
				tread_center + perpendicular * half_width * 0.3,
				Color(TRACK_TREAD.r, TRACK_TREAD.g, TRACK_TREAD.b, 0.84 * alpha),
				maxf(1.15, half_width * 0.1),
				true
			)
		_draw_road_wheels(canvas, track_center, direction, half_length, half_width, alpha)
		canvas.draw_line(
			track_center - direction * half_length * 0.72,
			track_center + direction * half_length * 0.72,
			Color(accent.r, accent.g, accent.b, 0.62 * alpha),
			maxf(1.2, half_width * 0.09),
			true
		)

func _draw_road_wheels(
	canvas: CanvasItem,
	track_center: Vector2,
	direction: Vector2,
	half_length: float,
	half_width: float,
	alpha: float
) -> void:
	for wheel_index in range(3):
		var along := lerpf(-half_length * 0.56, half_length * 0.56, float(wheel_index) / 2.0)
		var wheel_center := track_center + direction * along
		canvas.draw_circle(wheel_center, half_width * 0.205, Color(WHEEL_RIM.r, WHEEL_RIM.g, WHEEL_RIM.b, 0.95 * alpha))
		canvas.draw_circle(wheel_center, half_width * 0.115, Color(WHEEL_HUB.r, WHEEL_HUB.g, WHEEL_HUB.b, 0.98 * alpha))
		canvas.draw_circle(wheel_center, half_width * 0.04, Color(TRACK_EDGE.r, TRACK_EDGE.g, TRACK_EDGE.b, 0.9 * alpha))

func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not points.is_empty():
		result.append(points[0])
	return result

func _draw_hull(
	canvas: CanvasItem,
	position: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	half_length: float,
	half_width: float,
	body_color: Color,
	accent: Color
) -> void:
	var hull_shape := PackedVector2Array([
		position + direction * half_length * 0.82 - perpendicular * half_width * 0.5,
		position + direction * half_length - perpendicular * half_width * 0.28,
		position + direction * half_length + perpendicular * half_width * 0.28,
		position + direction * half_length * 0.82 + perpendicular * half_width * 0.5,
		position - direction * half_length * 0.82 + perpendicular * half_width * 0.5,
		position - direction * half_length * 0.82 - perpendicular * half_width * 0.5,
	])
	canvas.draw_colored_polygon(hull_shape, body_color)
	canvas.draw_polyline(
		PackedVector2Array([
			hull_shape[0], hull_shape[1], hull_shape[2], hull_shape[3],
			hull_shape[4], hull_shape[5], hull_shape[0],
		]),
		accent,
		maxf(1.4, half_width * 0.12),
		true
	)
	canvas.draw_line(
		position - direction * half_length * 0.48,
		position + direction * half_length * 0.54,
		Color(0.86, 0.91, 0.82, body_color.a * 0.42),
		maxf(1.1, half_width * 0.09),
		true
	)

func _draw_turret(
	canvas: CanvasItem,
	position: Vector2,
	draw_radius: float,
	accent: Color,
	alpha: float
) -> void:
	var direction := Vector2.from_angle(_turret_angle)
	var perpendicular := direction.orthogonal()
	var barrel_start := position + direction * draw_radius * 0.1
	var barrel_end := position + direction * draw_radius * 1.38
	canvas.draw_line(barrel_start, barrel_end, Color(0.05, 0.06, 0.055, 0.98 * alpha), maxf(3.4, draw_radius * 0.26), true)
	canvas.draw_line(barrel_start, barrel_end, accent, maxf(1.5, draw_radius * 0.1), true)
	canvas.draw_circle(position, draw_radius * 0.52, Color(0.16, 0.19, 0.17, 0.98 * alpha))
	canvas.draw_colored_polygon(
		PackedVector2Array([
			position + direction * draw_radius * 0.52,
			position - direction * draw_radius * 0.32 - perpendicular * draw_radius * 0.34,
			position - direction * draw_radius * 0.46,
			position - direction * draw_radius * 0.32 + perpendicular * draw_radius * 0.34,
		]),
		Color(accent.r, accent.g, accent.b, 0.78 * alpha)
	)
	canvas.draw_circle(position, draw_radius * 0.13, Color(0.88, 0.94, 0.84, 0.9 * alpha))
	if _muzzle_flash > 0.0:
		var flash_ratio := _muzzle_flash / MUZZLE_FLASH_DURATION
		var flash_tip := barrel_end + direction * draw_radius * 0.2
		canvas.draw_colored_polygon(PackedVector2Array([
			barrel_end,
			flash_tip + perpendicular * draw_radius * 0.22 * flash_ratio,
			barrel_end + direction * draw_radius * 0.62 * flash_ratio,
			flash_tip - perpendicular * draw_radius * 0.22 * flash_ratio,
		]), Color(1.0, 0.82, 0.22, 0.88 * flash_ratio))

func _draw_health_bar(
	canvas: CanvasItem,
	position: Vector2,
	draw_radius: float,
	accent: Color
) -> void:
	var bar_size := Vector2(draw_radius * 2.1, maxf(2.2, draw_radius * 0.15))
	var bounds := Rect2(
		position + Vector2(-bar_size.x * 0.5, -draw_radius * 1.58),
		bar_size
	)
	canvas.draw_rect(bounds.grow(1.0), Color(0.01, 0.018, 0.012, 0.92))
	canvas.draw_rect(
		Rect2(bounds.position, Vector2(bounds.size.x * hp / max_hp, bounds.size.y)),
		accent
	)
	canvas.draw_rect(bounds, Color(0.86, 0.92, 0.82, 0.78), false, 1.0)

func _box_points(
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	half_length: float,
	half_width: float
) -> PackedVector2Array:
	return PackedVector2Array([
		center - direction * half_length - perpendicular * half_width,
		center + direction * half_length - perpendicular * half_width,
		center + direction * half_length + perpendicular * half_width,
		center - direction * half_length + perpendicular * half_width,
	])

func _ease_out_back(progress: float) -> float:
	var shifted := clampf(progress, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * shifted * shifted * shifted + 1.70158 * shifted * shifted
