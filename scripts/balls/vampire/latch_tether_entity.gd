extends BallEntity

const CURVE_SEGMENTS := 14
const FLOW_BEAD_COUNT := 2
const MOUTH_RADIUS_SCALE := 0.92

var _duration := 2.0
var _color := Color("ff3858")
var _target_entity_ref: WeakRef

func _init(
	spawn_owner_side: int,
	duration: float,
	color: Color,
	target_entity: BallEntity = null
) -> void:
	owner_side = spawn_owner_side
	_duration = maxf(0.01, duration)
	remaining = _duration
	_color = color
	_target_entity_ref = weakref(target_entity) if target_entity != null else null
	tags = PackedStringArray(["vampire_latch_tether", "vampire_blood_line"])
	draw_layer = 23

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var vampire = context.owner_for_entity(self)
	var victim = context.opponent_for_entity(self)
	if _target_entity_ref != null:
		victim = _target_entity_ref.get_ref()
		if victim == null or victim.removed:
			return
	if vampire == null or victim == null:
		return
	var direction: Vector2 = victim.pos - vampire.pos
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var tangent := Vector2(-direction.y, direction.x)
	var mouth: Vector2 = vampire.pos + direction * vampire.radius * MOUTH_RADIUS_SCALE
	var victim_edge: Vector2 = victim.pos - direction * victim.radius * 0.72
	var fade := clampf(remaining / minf(0.24, _duration), 0.0, 1.0)
	for strand_index in range(3):
		var lateral: float = float(strand_index - 1) * victim.radius * 0.17
		var source: Vector2 = victim_edge + tangent * lateral
		var finish: Vector2 = mouth + tangent * lateral * 0.28
		var wave: float = sin(context.elapsed * 12.0 + float(strand_index) * 1.7)
		var control: Vector2 = (source + finish) * 0.5 + tangent * (16.0 + absf(lateral) * 0.28) * wave
		var points := PackedVector2Array()
		for segment_index in range(CURVE_SEGMENTS + 1):
			var progress := float(segment_index) / float(CURVE_SEGMENTS)
			points.append(context.point(_quadratic(source, control, finish, progress)))
		var line_pulse := 1.0 + sin(context.elapsed * 18.0 + float(strand_index)) * 0.22
		canvas.draw_polyline(points, Color(_color.r, 0.0, 0.05, fade * 0.3), maxf(4.5, 8.0 * line_pulse * context.scale_factor), true)
		canvas.draw_polyline(points, Color(1.0, _color.g, _color.b, fade * 0.9), maxf(1.5, 2.5 * line_pulse * context.scale_factor), true)
		for bead_index in range(FLOW_BEAD_COUNT):
			var bead_progress: float = fmod(
				context.elapsed * 2.5
				+ float(strand_index) * 0.23
				+ float(bead_index) / float(FLOW_BEAD_COUNT),
				1.0
			)
			var bead: Vector2 = _quadratic(source, control, finish, bead_progress)
			var bead_position := context.point(bead)
			canvas.draw_circle(bead_position, maxf(3.0, 4.6 * context.scale_factor), Color(_color.r, 0.0, 0.06, fade * 0.24))
			canvas.draw_circle(bead_position, maxf(1.8, 2.8 * context.scale_factor), Color("ff9daa"))

func _quadratic(start: Vector2, control: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return start * inverse * inverse + control * 2.0 * inverse * progress + finish * progress * progress
