extends BallEntity

const Wind := preload("res://scripts/balls/gale/wind_status.gd")
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _config: Dictionary
var _duration := 1.0
var _coordinator: WeakRef

func _init(side: int, first: Vector2, second: Vector2, config: Dictionary) -> void:
	owner_side = side
	_start = first
	_end = second
	pos = (first + second) * 0.5
	_config = config.duplicate()
	remaining = float(config["lane_duration"])
	_duration = remaining
	radius = float(config["lane_half_width"])
	tags = PackedStringArray(["gale_lane"])
	draw_layer = -40

func step(battle, _delta: float) -> void:
	if _coordinator != null:
		var coordinator: BallEntity = _coordinator.get_ref()
		if coordinator != null and not coordinator.removed and not coordinator.is_captured() and coordinator != self:
			return
	var lanes: Array[BallEntity] = []
	for lane: BallEntity in battle.entities(owner_side, "gale_lane"):
		if lane.owner_fighter_uid == owner_fighter_uid: lanes.append(lane)
	if lanes.is_empty(): return
	if lanes[0] != self:
		set_coordinator(lanes[0])
		return
	for lane in lanes: lane.call("set_coordinator", self)
	var targets: Array = []
	targets.append_array(battle.active_fighters())
	for unit: BallEntity in battle.entities():
		if not unit.is_terrain() and (unit.participates_in_fighter_collision() or unit.participates_in_entity_collision() or unit.team_marker_world_height() > 0.0):
			targets.append(unit)
	for target in targets:
		var touching := false
		for lane in lanes:
			if lane.call("contains_circle", target.pos, target.radius):
				touching = true
				break
		if not touching: continue
		var side: int = target.owner_side if target is BallEntity else target.team_id
		var ratio := float(_config["friendly_multiplier"] if side == owner_side else _config["hostile_multiplier"])
		var status := Wind.new(float(_config["effect_linger"]), owner_side, ratio)
		status.source_fighter_uid = owner_fighter_uid
		battle.apply_status(target, status)

func set_coordinator(entity: BallEntity) -> void:
	_coordinator = weakref(entity)

func contains_circle(position: Vector2, circle_radius: float) -> bool:
	return position.distance_to(Geometry2D.get_closest_point_to_segment(position, _start, _end)) <= radius + circle_radius

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_radius() -> float:
	return radius

func absorption_visual_color() -> Color:
	return Color("94ffcf")

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var start := context.point(_start)
	var end := context.point(_end)
	if is_captured():
		var direction := (_end - _start).normalized()
		start = context.point(pos - direction * radius * 0.3)
		end = context.point(pos + direction * radius * 0.3)
	if start.distance_squared_to(end) < 0.01: return
	var age := _duration - remaining
	var fade := clampf(remaining / _duration, 0.0, 1.0)
	var n := (end - start).normalized()
	var t := n.orthogonal()
	var width := radius * context.scale_factor
	canvas.draw_line(start, end, Color(0.2, 0.9, 0.68, fade * 0.1), width * 2.0, true)
	for index in range(3):
		var side := (index - 1) * width * 0.55
		canvas.draw_line(start + t * side, end + t * side, Color(0.53, 1.0, 0.8, fade * 0.3), maxf(0.8, context.scale_factor), true)
	var flow := fposmod(age * 1.8 + _start.x * 0.01 + _start.y * 0.013, 1.0)
	var p := start.lerp(end, flow)
	canvas.draw_polyline(PackedVector2Array([p - n * 4.0 * context.scale_factor + t * 4.0 * context.scale_factor, p, p - n * 4.0 * context.scale_factor - t * 4.0 * context.scale_factor]), Color(0.83, 1.0, 0.94, fade * 0.65), maxf(0.8, context.scale_factor), true)
