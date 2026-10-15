extends BallEntity

const CYCLONE := "cyclone"
const ELBOW := "elbow"

var _source
var _attack_kind := CYCLONE
var _duration := 0.8
var _direction := Vector2.RIGHT

func _init(
	spawn_owner_side: int,
	source,
	attack_style: String,
	duration: float,
	direction: Vector2
) -> void:
	owner_side = spawn_owner_side
	owner_fighter_uid = source.fighter_uid
	_source = source
	_attack_kind = attack_style
	_duration = maxf(0.05, duration)
	remaining = _duration
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	pos = source.pos
	radius = source.radius
	tags = PackedStringArray(["kobe_attack_vfx", "kobe_%s_vfx" % attack_style])
	draw_layer = 95

func step(_battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	pos = _source.pos

func attack_kind() -> String:
	return _attack_kind

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _source == null:
		return
	var center := screen_position(context, _source.pos)
	var draw_radius := radius * context.scale_factor
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var envelope := minf(1.0, progress * 7.0) * minf(1.0, remaining * 8.0)
	if _attack_kind == CYCLONE:
		_draw_cyclone(canvas, center, draw_radius, context.elapsed, envelope)
	else:
		_draw_elbow(canvas, center, draw_radius, envelope, progress)

func _draw_cyclone(
	canvas: CanvasItem,
	center: Vector2,
	draw_radius: float,
	elapsed: float,
	envelope: float
) -> void:
	var spin := elapsed * 18.0 + float(owner_fighter_uid) * 0.37
	for blade_index in range(4):
		var angle := spin + TAU * float(blade_index) / 4.0
		var direction := Vector2.from_angle(angle)
		var tangent := direction.orthogonal()
		var inner := center + direction * draw_radius * 0.38
		var outer := center + direction * draw_radius * 2.15
		var bolt_path := PackedVector2Array([
			inner,
			center + direction * draw_radius * 0.98 + tangent * draw_radius * 0.2,
			center + direction * draw_radius * 1.34 - tangent * draw_radius * 0.18,
			outer,
		])
		# A wide polyline keeps the lightning silhouette while avoiding the
		# self-intersecting polygon that Godot cannot triangulate at some angles.
		canvas.draw_polyline(bolt_path, Color(0.72, 0.48, 1.0, 0.5 * envelope), 7.2, true)
		canvas.draw_polyline(bolt_path, Color(1.0, 0.84, 0.18, 0.92 * envelope), 3.4, true)
		canvas.draw_circle(outer, draw_radius * 0.1, Color(1.0, 0.96, 0.65, 0.82 * envelope))
	for ring_index in range(3):
		canvas.draw_arc(
			center,
			draw_radius * (1.18 + float(ring_index) * 0.29),
			-spin * (0.36 + float(ring_index) * 0.08),
			-spin * (0.36 + float(ring_index) * 0.08) + PI * 1.42,
			32,
			Color(0.98, 0.78, 0.16, (0.62 - float(ring_index) * 0.12) * envelope),
			2.4,
			true
		)

func _draw_elbow(
	canvas: CanvasItem,
	center: Vector2,
	draw_radius: float,
	envelope: float,
	progress: float
) -> void:
	var direction := _direction
	var tangent := direction.orthogonal()
	var thrust := 0.72 + sin(progress * PI) * 0.48
	var shoulder := center + direction * draw_radius * 0.42 - tangent * draw_radius * 0.2
	var joint := center + direction * draw_radius * thrust + tangent * draw_radius * 0.42
	var fist := center + direction * draw_radius * (1.72 + progress * 0.42)
	var arm_path := PackedVector2Array([shoulder, joint, fist])
	canvas.draw_polyline(arm_path, Color(0.36, 0.12, 0.58, 0.74 * envelope), draw_radius * 0.48, true)
	canvas.draw_polyline(arm_path, Color(0.98, 0.72, 0.25, 0.94 * envelope), draw_radius * 0.3, true)
	canvas.draw_circle(joint, draw_radius * 0.2, Color(1.0, 0.86, 0.38, 0.92 * envelope))
	canvas.draw_circle(fist, draw_radius * 0.24, Color(1.0, 0.84, 0.3, 0.92 * envelope))
	canvas.draw_arc(fist, draw_radius * 0.46, -PI * 0.55, PI * 0.55, 18, Color(1.0, 0.95, 0.65, 0.82 * envelope), 2.4, true)
