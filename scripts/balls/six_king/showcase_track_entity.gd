extends BallEntity

var _owner
var angle := 0.0
var arms := 3
var length := 295.0
var age := 0.0
var lifetime := 12.0
var angular_speed := 0.24
var width := 21.0

func _init(spawn_owner_side: int, owner, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	_owner = owner
	angle = float(config["angle"])
	arms = int(config["arms"])
	length = float(config["length"])
	lifetime = float(config["lifetime"])
	angular_speed = float(config["angular_speed"])
	width = float(config["width"])
	radius = width * 0.5
	pos = owner.pos
	tags = PackedStringArray(["showcase_track"])
	draw_layer = -35

func step(_battle, delta: float) -> void:
	age += delta
	angle += angular_speed * delta
	pos = _owner.pos
	if age >= lifetime:
		removed = true

func touches(target) -> bool:
	for arm in range(arms):
		var arm_angle := angle + TAU * float(arm) / float(arms)
		var endpoint: Vector2 = pos + Vector2.from_angle(arm_angle) * length
		if _distance_to_segment(target.pos, pos, endpoint) <= target.radius + width * 0.5:
			return true
	return false

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var fade := minf(1.0, age / 0.5) * minf(1.0, (lifetime - age) / 0.75)
	for arm in range(arms):
		var arm_angle := angle + TAU * float(arm) / float(arms)
		canvas.draw_set_transform(screen_position(context) + context.shake_offset, arm_angle, Vector2.ONE * scale_factor)
		_draw_track_arm(canvas, fade)
	canvas.draw_set_transform(context.shake_offset, 0.0, Vector2.ONE)

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return Color(0.64, 0.66, 0.64)

func _draw_track_arm(canvas: CanvasItem, alpha: float) -> void:
	var sleeper_color := Color(0.32, 0.24, 0.18, 0.92 * alpha)
	var sleeper_light := Color(0.52, 0.39, 0.27, 0.92 * alpha)
	var rail_color := Color(0.64, 0.66, 0.64, 0.92 * alpha)
	canvas.draw_line(Vector2.ZERO, Vector2(length, 0.0), Color(0.12, 0.10, 0.08, 0.7 * alpha), width + 7.0, true)
	canvas.draw_line(Vector2(0.0, -width * 0.34), Vector2(length, -width * 0.34), rail_color, 3.0, true)
	canvas.draw_line(Vector2(0.0, width * 0.34), Vector2(length, width * 0.34), rail_color, 3.0, true)
	var distance := 8.0
	while distance < length:
		canvas.draw_rect(Rect2(Vector2(distance - 5.5, -width * 0.55), Vector2(11.0, width * 1.1)), sleeper_color)
		canvas.draw_rect(Rect2(Vector2(distance - 3.6, -width * 0.46), Vector2(7.2, width * 0.92)), sleeper_light, false, 1.2)
		distance += 15.0

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)
