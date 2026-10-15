extends BallEntity

func combat_category() -> Dictionary:
	return {"id": "dancer_blade", "name": "无柄刀"}

const MAX_SAMPLE_ANGLE := PI / 36.0
const MAX_SAMPLE_DISTANCE := 6.0

var _owner
var _slot_index := 0
var _slot_count := 1
var _fan_arc := 0.0
var _blade_tilt := 0.0
var _orbit_radius := 0.0
var _orbit_speed := 0.0
var _blade_length := 0.0
var _blade_width := 0.0
var _contact_damage := 0.0
var _native_color := Color.WHITE
var _native_accent := Color.WHITE
var _orbit_angle := 0.0
var _spin_remaining := 0.0
var _spin_angular_speed := 0.0
var _last_owner_position := Vector2.ZERO
var _touching_fighter_uids: Dictionary = {}
var _touching_entity_ids: Dictionary = {}
var _hit_sound_cooldown := 0.0

func _init(
	spawn_owner_side: int,
	owner,
	spawn_formation_slot: int,
	formation_count: int,
	settings: Dictionary,
	native_color: Color,
	native_accent: Color,
	initial_orbit_angle: float
) -> void:
	owner_side = spawn_owner_side
	owner_fighter_uid = owner.fighter_uid
	_owner = owner
	_slot_index = maxi(0, spawn_formation_slot)
	_slot_count = maxi(1, formation_count)
	_fan_arc = deg_to_rad(float(settings.get("fan_arc_degrees", 100.0)))
	_blade_tilt = deg_to_rad(float(settings.get("blade_tilt_degrees", 45.0)))
	_orbit_radius = float(settings.get("blade_orbit_radius", 48.0))
	_orbit_speed = float(settings.get("blade_orbit_speed", 0.7))
	_blade_length = float(settings.get("blade_length", 38.0))
	_blade_width = float(settings.get("blade_width", 6.0))
	_contact_damage = float(settings.get("blade_damage", 3.0))
	_native_color = native_color
	_native_accent = native_accent
	_orbit_angle = initial_orbit_angle
	_last_owner_position = owner.pos
	remaining = -1.0
	radius = maxf(2.0, _blade_width * 0.62)
	tags = PackedStringArray(["blade_dancer_blade"])
	draw_layer = ABOVE_BALL_DRAW_LAYER
	_update_position(owner.pos)

func step(battle, delta: float) -> void:
	if _owner == null or _owner.hp <= 0.0:
		removed = true
		return
	_hit_sound_cooldown = maxf(0.0, _hit_sound_cooldown - delta)
	var normal_delta := _orbit_speed * delta
	var spin_delta := 0.0
	if _spin_remaining > 0.0:
		var active_delta := minf(delta, _spin_remaining)
		spin_delta = _spin_angular_speed * active_delta
		_spin_remaining = maxf(0.0, _spin_remaining - active_delta)
		if _spin_remaining <= 0.0:
			_spin_angular_speed = 0.0
	var angular_delta := normal_delta + spin_delta
	var owner_position: Vector2 = _owner.pos
	var translation_distance := _last_owner_position.distance_to(owner_position)
	var sample_count := maxi(
		1,
		maxi(
			int(ceil(absf(angular_delta) / MAX_SAMPLE_ANGLE)),
			int(ceil(translation_distance / MAX_SAMPLE_DISTANCE))
		)
	)
	var start_owner_position := _last_owner_position
	var angle_step := angular_delta / float(sample_count)
	for sample_index in range(1, sample_count + 1):
		_orbit_angle = fposmod(_orbit_angle + angle_step, TAU)
		var weight := float(sample_index) / float(sample_count)
		_update_position(start_owner_position.lerp(owner_position, weight))
		_resolve_contacts(battle)
	_last_owner_position = owner_position

func start_spin(duration: float, turns: float, direction_sign: float) -> void:
	_spin_remaining = maxf(0.0, duration)
	_spin_angular_speed = (
		TAU * maxf(0.0, turns) * signf(direction_sign) / _spin_remaining
		if _spin_remaining > 0.0
		else 0.0
	)

func on_ownership_transferred(
	_previous_owner_side: int,
	_new_owner_side: int,
	new_owner_anchor
) -> void:
	if new_owner_anchor == null:
		return
	_owner = new_owner_anchor
	_last_owner_position = new_owner_anchor.pos
	_touching_fighter_uids.clear()
	_touching_entity_ids.clear()
	_update_position(new_owner_anchor.pos)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var scale_factor := context.scale_factor
	var direction := blade_direction()
	var tangent := direction.orthogonal()
	var half_length := _blade_length * scale_factor * 0.5
	var half_width := _blade_width * scale_factor * 0.5
	var glow_color := ownership_visual_color(_native_accent)
	var body_color := ownership_visual_color(_native_color)
	var glow_polygon := PackedVector2Array([
		center - direction * half_length * 1.08,
		center - direction * half_length * 0.18 + tangent * half_width * 1.8,
		center + direction * half_length * 0.18 + tangent * half_width * 1.8,
		center + direction * half_length * 1.08,
		center + direction * half_length * 0.18 - tangent * half_width * 1.8,
		center - direction * half_length * 0.18 - tangent * half_width * 1.8,
	])
	var blade_polygon := PackedVector2Array([
		center - direction * half_length,
		center - direction * half_length * 0.16 + tangent * half_width,
		center + direction * half_length * 0.16 + tangent * half_width,
		center + direction * half_length,
		center + direction * half_length * 0.16 - tangent * half_width,
		center - direction * half_length * 0.16 - tangent * half_width,
	])
	var glow_fill := glow_color
	glow_fill.a = 0.24
	canvas.draw_colored_polygon(glow_polygon, glow_fill)
	canvas.draw_colored_polygon(blade_polygon, body_color)
	var outline := glow_color
	outline.a = 0.96
	var outline_points := blade_polygon
	outline_points.append(blade_polygon[0])
	canvas.draw_polyline(outline_points, outline, maxf(1.2, 1.4 * scale_factor), true)
	var core := Color(1.0, 1.0, 1.0, 0.88)
	canvas.draw_line(
		center - direction * half_length * 0.72,
		center + direction * half_length * 0.72,
		core,
		maxf(0.8, 1.2 * scale_factor),
		true
	)

func team_marker_world_height() -> float:
	return _blade_width * 0.75

func is_absorbable() -> bool:
	return true

func attraction_position() -> Vector2:
	return pos

func absorption_radius() -> float:
	return maxf(radius, _blade_width)

func absorption_visual_color() -> Color:
	return ownership_visual_color(_native_accent)

func blade_direction() -> Vector2:
	return Vector2.from_angle(_slot_world_angle() + _blade_tilt)

func formation_slot() -> int:
	return _slot_index

func orbit_owner_uid() -> int:
	return _owner.fighter_uid if _owner != null else -1

func spin_active() -> bool:
	return _spin_remaining > 0.0

func _update_position(owner_position: Vector2) -> void:
	pos = owner_position + Vector2.from_angle(_slot_world_angle()) * _orbit_radius

func _slot_world_angle() -> float:
	return _orbit_angle + _slot_offset()

func _slot_offset() -> float:
	if _slot_count <= 1:
		return 0.0
	return lerpf(-_fan_arc * 0.5, _fan_arc * 0.5, float(_slot_index) / float(_slot_count - 1))

func _resolve_contacts(battle) -> void:
	var direction := blade_direction()
	var start := pos - direction * _blade_length * 0.5
	var finish := pos + direction * _blade_length * 0.5
	var half_width := _blade_width * 0.5
	var hit_color := ownership_visual_color(_native_accent)
	var touching_fighters: Dictionary = {}
	var source = battle.owner_for_entity(self)
	for target in battle.hostile_fighters(owner_side):
		if not _circle_intersects_segment(target.pos, target.radius, start, finish, half_width):
			continue
		var target_uid := int(target.fighter_uid)
		touching_fighters[target_uid] = true
		if _touching_fighter_uids.has(target_uid):
			continue
		var applied: float = battle.damage(target, _contact_damage, hit_color, source)
		if applied > 0.0:
			_emit_hit_feedback(battle, target.pos, start, finish, hit_color)
			battle.record_stat("blade_dancer_blade_hits")
	_touching_fighter_uids = touching_fighters

	var touching_entities: Dictionary = {}
	for target_entity: BallEntity in battle.damageable_entities_on_segment(
		owner_side,
		start,
		finish,
		half_width
	):
		var target_id := target_entity.get_instance_id()
		touching_entities[target_id] = true
		if _touching_entity_ids.has(target_id):
			continue
		var applied: float = battle.damage_entity(
			target_entity,
			_contact_damage,
			hit_color,
			owner_side
		)
		if applied > 0.0:
			_emit_hit_feedback(battle, target_entity.pos, start, finish, hit_color)
			battle.record_stat("blade_dancer_blade_entity_hits")
	_touching_entity_ids = touching_entities

func _emit_hit_feedback(
	battle,
	target_position: Vector2,
	start: Vector2,
	finish: Vector2,
	color: Color
) -> void:
	var hit_position := _closest_point_on_segment(target_position, start, finish)
	battle.spawn_ring(hit_position, color, 3.0, 25.0, 0.16)
	battle.spawn_particles(hit_position, color, 4, 92.0)
	if _hit_sound_cooldown <= 0.0:
		battle.emit_combat_event("blade_dancer_blade_slice", 0.48)
		_hit_sound_cooldown = 0.055

func _circle_intersects_segment(
	center: Vector2,
	target_radius: float,
	start: Vector2,
	finish: Vector2,
	half_width: float
) -> bool:
	return center.distance_to(_closest_point_on_segment(center, start, finish)) <= target_radius + half_width

func _closest_point_on_segment(point: Vector2, start: Vector2, finish: Vector2) -> Vector2:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start
	var offset := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return start + segment * offset
