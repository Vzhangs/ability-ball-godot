extends BallEntity

var _heal_amount := 0.0
var _color := Color("ffd84d")
var _duration := 1.0
var _start_position := Vector2.ZERO
var _landing_position := Vector2.ZERO
var _travel_duration := 1.0
var _travel_elapsed := 0.0
var _arc_height := 0.0
var _landed := false

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	target_position: Vector2,
	spawn_radius: float,
	travel_duration: float,
	landed_lifetime: float,
	heal_amount: float,
	arc_height: float
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_start_position = spawn_position
	_landing_position = target_position
	radius = spawn_radius
	_travel_duration = travel_duration
	_arc_height = arc_height
	remaining = travel_duration + landed_lifetime
	_duration = remaining
	_heal_amount = heal_amount
	tags = PackedStringArray(["plant_sun_pickup"])
	draw_layer = 4

func is_landed() -> bool:
	return _landed

func landing_position() -> Vector2:
	return _landing_position

func step(battle, delta: float) -> void:
	if not _landed:
		_travel_elapsed = minf(_travel_duration, _travel_elapsed + delta)
		var progress := clampf(_travel_elapsed / _travel_duration, 0.0, 1.0)
		var eased_progress := progress * progress * (3.0 - 2.0 * progress)
		var previous_position := pos
		pos = _start_position.lerp(_landing_position, eased_progress)
		pos.y -= sin(progress * PI) * _arc_height
		velocity = (pos - previous_position) / delta if delta > 0.0 else Vector2.ZERO
		if progress >= 1.0:
			pos = _landing_position
			velocity = Vector2.ZERO
			_landed = true
			battle.spawn_ring(pos, ownership_visual_color(_color), radius, 48.0, 0.38)
			battle.spawn_particles(pos, ownership_visual_color(_color), 7, 78.0)
		return
	var candidates: Array = battle.active_fighters()
	candidates.sort_custom(func(first, second) -> bool:
		return first.fighter_uid < second.fighter_uid
	)
	for candidate in candidates:
		if (
			candidate.hp <= 0.0
			or candidate.team_id != owner_side
			or candidate.pos.distance_to(pos) > candidate.radius + radius
		):
			continue
		var applied: float = battle.heal(candidate, _heal_amount)
		if applied <= 0.0:
			continue
		removed = true
		battle.record_stat("plant_sun_pickups_collected")
		battle.spawn_ring(pos, ownership_visual_color(_color), radius, 62.0, 0.35)
		battle.spawn_particles(pos, ownership_visual_color(_color), 11, 118.0)
		battle.emit_combat_event("track", 0.5)
		return

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var position := screen_position(context)
	var pulse := 1.0 + sin(context.elapsed * 5.0 + float(get_instance_id() % 13)) * 0.1
	var draw_radius := radius * context.scale_factor * pulse
	var color := ownership_visual_color(_color)
	var fade := clampf(remaining / minf(_duration, 2.0), 0.0, 1.0)
	color.a *= fade
	if not _landed and velocity.length_squared() > 0.001:
		var tail_length := minf(radius * 3.2, velocity.length() * 0.08) * context.scale_factor
		canvas.draw_line(
			position,
			position - velocity.normalized() * tail_length,
			Color(color.r, color.g, color.b, 0.28 * fade),
			maxf(2.0, draw_radius * 0.42),
			true
		)
	canvas.draw_circle(position, draw_radius * 1.65, Color(color.r, color.g, color.b, 0.18 * fade))
	for ray in range(8):
		var direction := Vector2.from_angle(float(ray) * TAU / 8.0 + context.elapsed * 0.7)
		canvas.draw_line(position + direction * draw_radius * 1.05, position + direction * draw_radius * 1.52, color, 1.6, true)
	canvas.draw_circle(position, draw_radius, color)
	canvas.draw_circle(position - Vector2.ONE * draw_radius * 0.2, draw_radius * 0.3, Color(1.0, 1.0, 0.86, 0.86 * fade))
	if _landed:
		canvas.draw_arc(position, draw_radius * 1.78, context.elapsed * 0.8, context.elapsed * 0.8 + PI * 1.45, 18, Color(color.r, color.g, color.b, 0.45 * fade), 1.2, true)

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return ownership_visual_color(_color)
