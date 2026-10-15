extends BallEntity

const VISUAL_GLOW_WIDTH := 5.4
const VISUAL_OUTER_WIDTH := 2.7
const VISUAL_CORE_WIDTH := 1.1
const CAPTURE_FOLD_DURATION := 0.34
const CAPTURE_BUNDLE_HALF_LENGTH := 7.0

var _anchor := Vector2.ZERO
var _damage := 1.0
var _collision_half_width := 2.5
var _body_color := Color.WHITE
var _accent_color := Color.WHITE
var _current_strand_end := Vector2.ZERO
var _opponent_touching := false
var _previous_owner_position := Vector2.ZERO
var _has_previous_owner_position := false
var _previous_opponent_position := Vector2.ZERO
var _has_previous_opponent_position := false
var _entity_touching := {}
var _entity_previous_positions := {}
var _age := 0.0
var _trigger_flash := 0.0
var _trigger_position := Vector2.ZERO
var _trigger_count := 0
var _capture_start_offset := Vector2.ZERO
var _capture_end_offset := Vector2.ZERO
var _capture_fold_elapsed := 0.0

func _init(spawn_owner_side: int, wall_anchor: Vector2, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	_anchor = wall_anchor
	pos = wall_anchor
	radius = maxf(0.0, float(config["collision_half_width"]))
	_collision_half_width = radius
	_damage = maxf(0.0, float(config["damage"]))
	_body_color = config["body_color"] as Color
	_accent_color = config["accent_color"] as Color
	_current_strand_end = Vector2(config.get("strand_end", wall_anchor))
	remaining = -1.0
	tags = PackedStringArray(["spider_web_line"])
	draw_layer = -24

func process_step(battle, delta: float) -> void:
	if not is_captured():
		super.process_step(battle, delta)
		return
	# Captured strands keep only their presentation timeline. Damage, collision,
	# wall anchoring, and autonomous movement remain disabled by the base contract.
	_age += delta
	_trigger_flash = maxf(0.0, _trigger_flash - delta * 3.6)
	_capture_fold_elapsed = minf(
		CAPTURE_FOLD_DURATION,
		_capture_fold_elapsed + maxf(0.0, delta)
	)

func step(battle, delta: float) -> void:
	_age += delta
	_trigger_flash = maxf(0.0, _trigger_flash - delta * 3.6)
	var owner = battle.owner_for_entity(self)
	var opponent = battle.opponent_for_entity(self)
	if owner == null or opponent == null or owner.hp <= 0.0 or opponent.hp <= 0.0:
		return
	_current_strand_end = owner.pos
	var previous_owner_position: Vector2 = (
		_previous_owner_position if _has_previous_owner_position else owner.pos
	)
	_process_fighter_target(
		battle,
		owner,
		opponent,
		previous_owner_position,
		owner.pos
	)
	_process_entity_targets(
		battle,
		previous_owner_position,
		owner.pos
	)
	_previous_owner_position = owner.pos
	_has_previous_owner_position = true

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if is_captured():
		_draw_captured_strand(canvas, context)
		return
	var owner = context.owner_for_entity(self)
	if owner == null:
		return
	var start := context.point(_anchor)
	var finish := context.point(owner.pos)
	var strand := finish - start
	if strand.length_squared() <= 0.01:
		return
	var scale_factor := context.scale_factor
	var pulse := 0.86 + 0.14 * sin(_age * 4.4 + _anchor.x * 0.013 + _anchor.y * 0.009)
	var glow_color := Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.12 * pulse)
	var outer_color := Color(0.82, 0.91, 0.96, 0.52 * pulse)
	var core_color := Color(1.0, 1.0, 1.0, 0.88 * pulse)
	canvas.draw_line(start, finish, glow_color, maxf(2.0, VISUAL_GLOW_WIDTH * scale_factor), true)
	canvas.draw_line(start, finish, outer_color, maxf(1.2, VISUAL_OUTER_WIDTH * scale_factor), true)
	canvas.draw_line(start, finish, core_color, maxf(0.8, VISUAL_CORE_WIDTH * scale_factor), true)
	_draw_anchor(canvas, start, strand.normalized(), scale_factor, pulse)
	var shimmer_progress := fposmod(_age * 0.58 + _anchor.x * 0.0017 + _anchor.y * 0.0023, 1.0)
	var shimmer := start.lerp(finish, shimmer_progress)
	canvas.draw_circle(shimmer, maxf(1.1, 2.2 * scale_factor), Color(1.0, 1.0, 1.0, 0.52 * pulse))
	if _trigger_flash > 0.0:
		var flash_center := context.point(_trigger_position)
		var flash_radius := (8.0 + (1.0 - _trigger_flash) * 25.0) * scale_factor
		canvas.draw_circle(
			flash_center,
			flash_radius,
			Color(_accent_color.r, _accent_color.g, _accent_color.b, _trigger_flash * 0.76),
			false,
			maxf(1.2, 2.8 * scale_factor),
			true
		)

func anchor_position() -> Vector2:
	return _anchor

func strand_end(battle) -> Vector2:
	if is_captured():
		return pos
	var owner = battle.owner_for_entity(self)
	return owner.pos if owner != null else _anchor

func capture_fold_progress() -> float:
	return clampf(
		_capture_fold_elapsed / CAPTURE_FOLD_DURATION,
		0.0,
		1.0
	)

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	# A wall-anchored arena hazard may be captured and consumed, but it is not a
	# follower/summon whose allegiance can be reassigned safely.
	return false

func attraction_position() -> Vector2:
	if is_captured():
		return pos
	return (_anchor + _current_strand_end) * 0.5

func absorption_radius() -> float:
	return maxf(1.0, _collision_half_width)

func absorption_visual_color() -> Color:
	return _accent_color

func disable_for_capture() -> bool:
	if not super.disable_for_capture():
		return false
	var capture_start := _anchor
	var capture_finish := _current_strand_end
	pos = (capture_start + capture_finish) * 0.5
	_capture_start_offset = capture_start - pos
	_capture_end_offset = capture_finish - pos
	_capture_fold_elapsed = 0.0
	_opponent_touching = false
	_entity_touching.clear()
	_entity_previous_positions.clear()
	return true

func is_opponent_touching() -> bool:
	return _opponent_touching

func trigger_count() -> int:
	return _trigger_count

func trigger_flash() -> float:
	return _trigger_flash

func visual_age() -> float:
	return _age

func touching_entity_count() -> int:
	var count := 0
	for touching in _entity_touching.values():
		if bool(touching):
			count += 1
	return count

func _draw_captured_strand(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := capture_fold_progress()
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var original_direction := (_capture_end_offset - _capture_start_offset).normalized()
	if original_direction.length_squared() <= 0.0001:
		original_direction = Vector2.RIGHT
	var bundle_start := -original_direction * CAPTURE_BUNDLE_HALF_LENGTH
	var bundle_end := original_direction * CAPTURE_BUNDLE_HALF_LENGTH
	var start_world := pos + _capture_start_offset.lerp(bundle_start, eased)
	var finish_world := pos + _capture_end_offset.lerp(bundle_end, eased)
	var start := context.point(start_world)
	var finish := context.point(finish_world)
	var strand := finish - start
	if strand.length_squared() <= 0.01:
		return
	var direction := strand.normalized()
	var perpendicular := direction.orthogonal()
	var fold_wave := sin(progress * PI) * minf(12.0, strand.length() * 0.16)
	var center := start.lerp(finish, 0.5)
	var points := PackedVector2Array([
		start,
		start.lerp(finish, 0.25) + perpendicular * fold_wave,
		center - perpendicular * fold_wave * 0.7,
		start.lerp(finish, 0.75) + perpendicular * fold_wave * 0.8,
		finish,
	])
	var pulse := 0.86 + 0.14 * sin(_age * 6.2)
	var scale_factor := context.scale_factor
	canvas.draw_polyline(
		points,
		Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.16 * pulse),
		maxf(2.0, VISUAL_GLOW_WIDTH * scale_factor),
		true
	)
	canvas.draw_polyline(
		points,
		Color(0.82, 0.91, 0.96, 0.58 * pulse),
		maxf(1.2, VISUAL_OUTER_WIDTH * scale_factor),
		true
	)
	canvas.draw_polyline(
		points,
		Color(1.0, 1.0, 1.0, 0.9 * pulse),
		maxf(0.8, VISUAL_CORE_WIDTH * scale_factor),
		true
	)
	var convergence := center.lerp(finish, fposmod(_age * 1.6, 1.0))
	canvas.draw_circle(
		convergence,
		maxf(1.1, 2.2 * scale_factor),
		Color(1.0, 1.0, 1.0, 0.62 * pulse)
	)

func _process_fighter_target(
	battle,
	owner,
	opponent,
	previous_strand_end: Vector2,
	current_strand_end: Vector2
) -> void:
	var previous_target_position: Vector2 = (
		_previous_opponent_position if _has_previous_opponent_position else opponent.pos
	)
	var swept_touching := _swept_strand_touches_circle(
		previous_target_position,
		opponent.pos,
		opponent.radius,
		previous_strand_end,
		current_strand_end
	)
	if swept_touching and not _opponent_touching:
		var trigger_position := _trigger_position_for_target(
			opponent.pos,
			opponent.radius,
			previous_strand_end,
			current_strand_end
		)
		var applied: float = battle.damage(opponent, _damage, _accent_color, owner)
		_start_trigger(battle, trigger_position, applied, false)
	_opponent_touching = _strand_touches_circle(
		opponent.pos,
		opponent.radius,
		current_strand_end
	)
	_previous_opponent_position = opponent.pos
	_has_previous_opponent_position = true

func _process_entity_targets(
	battle,
	previous_strand_end: Vector2,
	current_strand_end: Vector2
) -> void:
	var active_entity_ids := {}
	for entity: BallEntity in battle.damageable_entities(owner_side):
		var entity_id := entity.get_instance_id()
		active_entity_ids[entity_id] = true
		var previous_target_position: Vector2 = _entity_previous_positions.get(
			entity_id,
			entity.pos
		)
		var swept_touching := _swept_strand_touches_circle(
			previous_target_position,
			entity.pos,
			entity.radius,
			previous_strand_end,
			current_strand_end
		)
		if swept_touching and not bool(_entity_touching.get(entity_id, false)):
			var trigger_position := _trigger_position_for_target(
				entity.pos,
				entity.radius,
				previous_strand_end,
				current_strand_end
			)
			var applied: float = battle.damage_entity(
				entity,
				_damage,
				_accent_color,
				owner_side
			)
			_start_trigger(battle, trigger_position, applied, true)
		_entity_touching[entity_id] = _strand_touches_circle(
			entity.pos,
			entity.radius,
			current_strand_end
		)
		_entity_previous_positions[entity_id] = entity.pos
	for entity_id in _entity_touching.keys():
		if active_entity_ids.has(entity_id):
			continue
		_entity_touching.erase(entity_id)
		_entity_previous_positions.erase(entity_id)

func _start_trigger(
	battle,
	trigger_position: Vector2,
	applied_damage: float,
	is_entity_target: bool
) -> void:
	_trigger_position = trigger_position
	_trigger_flash = 1.0
	_trigger_count += 1
	battle.spawn_ring(trigger_position, _accent_color, 3.0, 38.0, 0.28)
	battle.spawn_particles(trigger_position, _accent_color, 7, 105.0)
	battle.emit_combat_event("web_trigger", 0.72)
	if applied_damage <= 0.0:
		return
	battle.record_stat("web_triggers")
	if is_entity_target:
		battle.record_stat("web_entity_triggers")

func _swept_strand_touches_circle(
	previous_target_position: Vector2,
	current_target_position: Vector2,
	target_radius: float,
	previous_strand_end: Vector2,
	current_strand_end: Vector2
) -> bool:
	var combined_radius := maxf(0.0, target_radius) + _collision_half_width
	if _point_in_triangle(
		previous_target_position,
		_anchor,
		previous_strand_end,
		current_strand_end
	) or _point_in_triangle(
		current_target_position,
		_anchor,
		previous_strand_end,
		current_strand_end
	):
		return true
	for edge in [
		[_anchor, previous_strand_end],
		[previous_strand_end, current_strand_end],
		[current_strand_end, _anchor],
	]:
		if _segment_distance(
			previous_target_position,
			current_target_position,
			Vector2(edge[0]),
			Vector2(edge[1])
		) <= combined_radius:
			return true
	return false

func _strand_touches_circle(
	target_position: Vector2,
	target_radius: float,
	current_strand_end: Vector2
) -> bool:
	var closest := _closest_point_on_segment(target_position, _anchor, current_strand_end)
	return target_position.distance_to(closest) <= maxf(0.0, target_radius) + _collision_half_width

func _trigger_position_for_target(
	target_position: Vector2,
	target_radius: float,
	previous_strand_end: Vector2,
	current_strand_end: Vector2
) -> Vector2:
	var combined_radius := maxf(0.0, target_radius) + _collision_half_width
	var current_closest := _closest_point_on_segment(
		target_position,
		_anchor,
		current_strand_end
	)
	if target_position.distance_to(current_closest) <= combined_radius:
		return current_closest
	var previous_closest := _closest_point_on_segment(
		target_position,
		_anchor,
		previous_strand_end
	)
	if target_position.distance_to(previous_closest) <= combined_radius:
		return previous_closest
	return target_position

func _draw_anchor(
	canvas: CanvasItem,
	center: Vector2,
	strand_direction: Vector2,
	scale_factor: float,
	pulse: float
) -> void:
	var anchor_radius := maxf(2.2, 4.8 * scale_factor)
	canvas.draw_circle(center, anchor_radius * 1.8, Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.12 * pulse))
	canvas.draw_circle(center, anchor_radius, Color(0.9, 0.97, 1.0, 0.8 * pulse))
	var tangent := strand_direction.orthogonal()
	for direction in [strand_direction, -strand_direction, tangent, -tangent]:
		canvas.draw_line(
			center,
			center + direction * anchor_radius * 1.65,
			Color(1.0, 1.0, 1.0, 0.62 * pulse),
			maxf(0.8, 1.2 * scale_factor),
			true
		)

func _closest_point_on_segment(point: Vector2, start: Vector2, finish: Vector2) -> Vector2:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start
	var offset := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return start + segment * offset

func _point_in_triangle(
	point: Vector2,
	first: Vector2,
	second: Vector2,
	third: Vector2
) -> bool:
	if absf((second - first).cross(third - first)) <= 0.0001:
		return false
	var first_cross := (second - first).cross(point - first)
	var second_cross := (third - second).cross(point - second)
	var third_cross := (first - third).cross(point - third)
	var has_negative := first_cross < 0.0 or second_cross < 0.0 or third_cross < 0.0
	var has_positive := first_cross > 0.0 or second_cross > 0.0 or third_cross > 0.0
	return not (has_negative and has_positive)

func _segment_distance(
	first_start: Vector2,
	first_end: Vector2,
	second_start: Vector2,
	second_end: Vector2
) -> float:
	if _segments_intersect(first_start, first_end, second_start, second_end):
		return 0.0
	return minf(
		minf(
			first_start.distance_to(_closest_point_on_segment(first_start, second_start, second_end)),
			first_end.distance_to(_closest_point_on_segment(first_end, second_start, second_end))
		),
		minf(
			second_start.distance_to(_closest_point_on_segment(second_start, first_start, first_end)),
			second_end.distance_to(_closest_point_on_segment(second_end, first_start, first_end))
		)
	)

func _segments_intersect(
	first_start: Vector2,
	first_end: Vector2,
	second_start: Vector2,
	second_end: Vector2
) -> bool:
	var first_segment := first_end - first_start
	var second_segment := second_end - second_start
	var denominator := first_segment.cross(second_segment)
	if absf(denominator) <= 0.0001:
		return false
	var offset := second_start - first_start
	var first_fraction := offset.cross(second_segment) / denominator
	var second_fraction := offset.cross(first_segment) / denominator
	return (
		first_fraction >= 0.0
		and first_fraction <= 1.0
		and second_fraction >= 0.0
		and second_fraction <= 1.0
	)
