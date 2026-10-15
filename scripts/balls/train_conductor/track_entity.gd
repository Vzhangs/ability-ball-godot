extends BallEntity

const RAIL_GAUGE := 14.0
const SLEEPER_HALF_LENGTH := 19.0
const SLEEPER_SPACING := 13.0
const BALLAST_WIDTH := 38.0
const EPSILON := 0.0001

var _local_points := PackedVector2Array()
var _committed_point_count := 1
var _sample_spacing := 12.0
var _absorption_radius := 12.0
var _body_color := Color("173b56")
var _accent_color := Color("f0b84a")
var _finalized := false
var _age := 0.0
var _settlement_flash := 0.0
var _departure_flash := 0.0

func _init(
	spawn_owner_side: int,
	start_position: Vector2,
	body_color: Color,
	accent_color: Color,
	sample_spacing: float,
	absorb_radius: float
) -> void:
	owner_side = spawn_owner_side
	pos = start_position
	_body_color = body_color
	_accent_color = accent_color
	_sample_spacing = maxf(1.0, sample_spacing)
	_absorption_radius = maxf(1.0, absorb_radius)
	radius = _absorption_radius
	remaining = -1.0
	_local_points.append(Vector2.ZERO)
	tags = PackedStringArray(["train_track"])
	draw_layer = -30

func step(_battle, delta: float) -> void:
	_age += delta
	_settlement_flash = maxf(0.0, _settlement_flash - delta * 3.8)
	_departure_flash = maxf(0.0, _departure_flash - delta * 2.2)

func append_path_to(world_position: Vector2, force_endpoint: bool) -> int:
	if removed or is_captured() or _finalized:
		return 0
	var appended := 0
	var last_world := pos + _local_points[_local_points.size() - 1]
	var offset := world_position - last_world
	while offset.length() >= _sample_spacing:
		last_world += offset.normalized() * _sample_spacing
		_local_points.append(last_world - pos)
		appended += 1
		offset = world_position - last_world
	if force_endpoint and offset.length_squared() > EPSILON:
		_local_points.append(world_position - pos)
		appended += 1
	return appended

func commit_pending() -> bool:
	if removed or is_captured() or _finalized or _committed_point_count >= _local_points.size():
		return false
	_committed_point_count = _local_points.size()
	_settlement_flash = 1.0
	return true

func finalize_route(lifetime: float) -> void:
	if removed or is_captured():
		return
	_committed_point_count = _local_points.size()
	_finalized = true
	_settlement_flash = 1.0
	_departure_flash = 1.0
	remaining = maxf(0.05, lifetime)

func is_finalized() -> bool:
	return _finalized

func point_count() -> int:
	return _local_points.size()

func committed_point_count() -> int:
	return _committed_point_count

func route_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	for local_point in _local_points:
		result.append(pos + local_point)
	return result

func route_length() -> float:
	var length := 0.0
	for index in range(1, _local_points.size()):
		length += _local_points[index - 1].distance_to(_local_points[index])
	return length

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _local_points.size() < 2:
		return
	var alpha_multiplier := 0.54 if is_captured() else 1.0
	# Build one visually continuous railway. The previous implementation drew a
	# complete sleeper set for every tiny sampled segment, which made the route
	# look like a thin dashed wire instead of a railway at video scale.
	for index in range(_local_points.size() - 1):
		var committed := index + 1 < _committed_point_count
		_draw_track_bed(
			canvas,
			context,
			pos + _local_points[index],
			pos + _local_points[index + 1],
			committed,
			alpha_multiplier
		)
	_draw_continuous_sleepers(canvas, context, alpha_multiplier)
	for index in range(_local_points.size() - 1):
		var committed := index + 1 < _committed_point_count
		_draw_rails(
			canvas,
			context,
			pos + _local_points[index],
			pos + _local_points[index + 1],
			committed,
			alpha_multiplier
		)
	var first_world := pos + _local_points[0]
	var second_world := pos + _local_points[1]
	_draw_terminal(canvas, context, first_world, second_world - first_world, alpha_multiplier)
	var last_index := _local_points.size() - 1
	var last_world := pos + _local_points[last_index]
	var previous_world := pos + _local_points[last_index - 1]
	if _finalized:
		_draw_terminal(canvas, context, last_world, previous_world - last_world, alpha_multiplier)
	else:
		_draw_construction_head(canvas, context, last_world, alpha_multiplier)
	if _departure_flash > 0.0:
		_draw_departure_flash(canvas, context, alpha_multiplier)
	if _settlement_flash > 0.0 and not is_captured():
		var committed_index := mini(_committed_point_count - 1, _local_points.size() - 1)
		if committed_index >= 0:
			var center := context.point(pos + _local_points[committed_index])
			canvas.draw_circle(
				center,
				(4.0 + (1.0 - _settlement_flash) * 13.0) * context.scale_factor,
				Color(_accent_color.r, _accent_color.g, _accent_color.b, _settlement_flash * 0.62),
				false,
				maxf(1.0, 2.0 * context.scale_factor),
				true
			)

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func attraction_position() -> Vector2:
	if is_captured() or _local_points.is_empty():
		return pos
	var center := Vector2.ZERO
	for local_point in _local_points:
		center += pos + local_point
	return center / float(_local_points.size())

func absorption_radius() -> float:
	return _absorption_radius

func absorption_visual_color() -> Color:
	return _accent_color

func disable_for_capture() -> bool:
	var world_points := route_points()
	if not super.disable_for_capture():
		return false
	var center := Vector2.ZERO
	for world_point in world_points:
		center += world_point
	if not world_points.is_empty():
		center /= float(world_points.size())
	pos = center
	_local_points.clear()
	for world_point in world_points:
		_local_points.append(world_point - center)
	return true

func visual_age() -> float:
	return _age

func settlement_flash() -> float:
	return _settlement_flash

func _draw_track_bed(
	canvas: CanvasItem,
	context: BallRenderContext,
	start_world: Vector2,
	finish_world: Vector2,
	committed: bool,
	alpha_multiplier: float
) -> void:
	var world_direction := finish_world - start_world
	if world_direction.length_squared() <= EPSILON:
		return
	var start := context.point(start_world)
	var finish := context.point(finish_world)
	var alpha := (0.88 if committed else 0.26) * alpha_multiplier
	var ballast_color := Color(0.11, 0.09, 0.075, alpha * 0.92)
	var shoulder_color := Color(_body_color.r, _body_color.g, _body_color.b, alpha * 0.46)
	canvas.draw_line(start, finish, ballast_color, maxf(4.0, BALLAST_WIDTH * context.scale_factor), true)
	canvas.draw_line(start, finish, shoulder_color, maxf(3.0, 29.0 * context.scale_factor), true)

func _draw_continuous_sleepers(
	canvas: CanvasItem,
	context: BallRenderContext,
	alpha_multiplier: float
) -> void:
	var distance_until_sleeper := 0.0
	var sleeper_index := 0
	for index in range(_local_points.size() - 1):
		var start_world := pos + _local_points[index]
		var finish_world := pos + _local_points[index + 1]
		var offset := finish_world - start_world
		var segment_length := offset.length()
		if segment_length <= EPSILON:
			continue
		var direction := offset / segment_length
		var normal := direction.orthogonal()
		var committed := index + 1 < _committed_point_count
		var alpha := (0.96 if committed else 0.32) * alpha_multiplier
		var along := distance_until_sleeper
		while along <= segment_length + EPSILON:
			var center := context.point(start_world + direction * along)
			var half_length := SLEEPER_HALF_LENGTH * context.scale_factor
			var sleeper_color := Color(0.47, 0.28, 0.14, alpha)
			canvas.draw_line(
				center - normal * half_length,
				center + normal * half_length,
				Color(0.08, 0.055, 0.04, alpha * 0.72),
				maxf(2.2, 5.6 * context.scale_factor),
				true
			)
			canvas.draw_line(
				center - normal * half_length,
				center + normal * half_length,
				sleeper_color,
				maxf(1.2, 3.2 * context.scale_factor),
				true
			)
			if sleeper_index % 2 == 0:
				for rail_side in [-1.0, 1.0]:
					canvas.draw_circle(
						center + normal * RAIL_GAUGE * context.scale_factor * rail_side,
						maxf(0.65, 0.95 * context.scale_factor),
						Color(0.56, 0.64, 0.66, alpha * 0.82)
					)
			sleeper_index += 1
			along += SLEEPER_SPACING
		distance_until_sleeper = along - segment_length

func _draw_rails(
	canvas: CanvasItem,
	context: BallRenderContext,
	start_world: Vector2,
	finish_world: Vector2,
	committed: bool,
	alpha_multiplier: float
) -> void:
	var offset := finish_world - start_world
	if offset.length_squared() <= EPSILON:
		return
	var normal := offset.normalized().orthogonal()
	var gauge := RAIL_GAUGE * context.scale_factor
	var start := context.point(start_world)
	var finish := context.point(finish_world)
	var alpha := (1.0 if committed else 0.36) * alpha_multiplier
	for rail_side in [-1.0, 1.0]:
		var rail_start: Vector2 = start + normal * gauge * rail_side
		var rail_finish: Vector2 = finish + normal * gauge * rail_side
		canvas.draw_line(
			rail_start,
			rail_finish,
			Color(0.16, 0.19, 0.20, alpha),
			maxf(2.2, 5.4 * context.scale_factor),
			true
		)
		canvas.draw_line(
			rail_start,
			rail_finish,
			Color(0.78, 0.86, 0.88, alpha),
			maxf(1.0, 2.35 * context.scale_factor),
			true
		)

func _draw_terminal(
	canvas: CanvasItem,
	context: BallRenderContext,
	world_position: Vector2,
	into_route: Vector2,
	alpha_multiplier: float
) -> void:
	if into_route.length_squared() <= EPSILON:
		return
	var direction := into_route.normalized()
	var normal := direction.orthogonal()
	var center := context.point(world_position + direction * 3.5)
	var scale_factor := context.scale_factor
	var terminal_color := Color(0.95, 0.69, 0.20, 0.96 * alpha_multiplier)
	canvas.draw_line(
		center - normal * 21.0 * scale_factor,
		center + normal * 21.0 * scale_factor,
		Color(0.07, 0.08, 0.08, 0.96 * alpha_multiplier),
		maxf(3.0, 7.0 * scale_factor),
		true
	)
	canvas.draw_line(
		center - normal * 21.0 * scale_factor,
		center + normal * 21.0 * scale_factor,
		terminal_color,
		maxf(1.4, 3.0 * scale_factor),
		true
	)
	for rail_side in [-1.0, 1.0]:
		var post_center: Vector2 = center + normal * RAIL_GAUGE * scale_factor * rail_side
		canvas.draw_line(
			post_center,
			post_center + direction * 12.0 * scale_factor,
			Color(0.19, 0.21, 0.21, 0.98 * alpha_multiplier),
			maxf(2.0, 5.0 * scale_factor),
			true
		)

func _draw_construction_head(
	canvas: CanvasItem,
	context: BallRenderContext,
	world_position: Vector2,
	alpha_multiplier: float
) -> void:
	var center := context.point(world_position)
	var pulse := 0.5 + 0.5 * sin(_age * 7.0)
	var radius_value := (5.0 + pulse * 3.0) * context.scale_factor
	canvas.draw_circle(center, radius_value * 1.8, Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.12 * alpha_multiplier))
	canvas.draw_circle(center, radius_value, Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.88 * alpha_multiplier))
	canvas.draw_circle(center, radius_value * 0.42, Color(1.0, 0.95, 0.68, 0.96 * alpha_multiplier))

func _draw_departure_flash(
	canvas: CanvasItem,
	context: BallRenderContext,
	alpha_multiplier: float
) -> void:
	var flash_color := Color(
		_accent_color.r,
		_accent_color.g,
		_accent_color.b,
		_departure_flash * 0.36 * alpha_multiplier
	)
	for index in range(_local_points.size() - 1):
		canvas.draw_line(
			context.point(pos + _local_points[index]),
			context.point(pos + _local_points[index + 1]),
			flash_color,
			maxf(2.0, 6.0 * context.scale_factor),
			true
		)
