extends BallEntity

const LINGER_DURATION := 0.14
const DASH_WORLD_LENGTH := 13.0
const GAP_WORLD_LENGTH := 8.0

var _aim_duration := 1.0
var _age := 0.0
var _line_color := Color.WHITE
var _reticle_color := Color("ff496d")

func _init(
	spawn_owner_side: int,
	duration: float,
	line_color: Color,
	reticle_color: Color
) -> void:
	owner_side = spawn_owner_side
	_aim_duration = maxf(0.01, duration)
	remaining = _aim_duration + LINGER_DURATION
	_line_color = line_color
	_reticle_color = reticle_color
	tags = PackedStringArray(["sniper_aim_vfx"])
	draw_layer = 42

func step(battle, delta: float) -> void:
	_age = minf(_aim_duration + LINGER_DURATION, _age + delta)
	pos = battle.opponent_for_side(owner_side).pos

func animation_progress() -> float:
	return clampf(_age / _aim_duration, 0.0, 1.0)

func animation_alpha() -> float:
	if _age <= _aim_duration:
		return 1.0
	return clampf(1.0 - (_age - _aim_duration) / LINGER_DURATION, 0.0, 1.0)

func reticle_radius(target_radius: float) -> float:
	var eased := 1.0 - pow(1.0 - animation_progress(), 3.0)
	return lerpf(target_radius * 2.15 + 14.0, target_radius * 1.22 + 2.0, eased)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var owner = context.owner_for_entity(self)
	var target = context.opponent_for_entity(self)
	if owner == null or target == null:
		return
	var direction: Vector2 = (target.pos - owner.pos).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT if owner_side == 0 else Vector2.LEFT
	var source_world: Vector2 = owner.pos + direction * owner.radius * 1.58
	var source := context.point(source_world)
	var destination := context.point(target.pos)
	var alpha := animation_alpha()
	_draw_dashed_line(canvas, source, destination, context, alpha)
	var center := destination
	var radius_screen := reticle_radius(target.radius) * context.scale_factor
	var progress := animation_progress()
	var pulse := 0.78 + 0.22 * sin(context.elapsed * 18.0)
	var glow := _reticle_color
	glow.a = alpha * 0.20 * pulse
	canvas.draw_circle(center, radius_screen * 1.08, glow, false, maxf(2.0, 7.0 * context.scale_factor), true)
	var crisp := _reticle_color
	crisp.a = alpha * lerpf(0.62, 1.0, progress)
	var rotation := context.elapsed * 0.8
	for quadrant in range(4):
		var start_angle := rotation + float(quadrant) * PI * 0.5 + 0.13
		canvas.draw_arc(center, radius_screen, start_angle, start_angle + 0.86, 14, crisp, maxf(1.4, 2.3 * context.scale_factor), true)
	var inner := Color.WHITE
	inner.a = alpha * (0.38 + progress * 0.48)
	for axis in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		canvas.draw_line(
			center + axis * radius_screen * 0.68,
			center + axis * radius_screen * 1.08,
			inner,
			maxf(1.1, 1.7 * context.scale_factor),
			true
		)
	var lock_dot := _reticle_color
	lock_dot.a = alpha * progress * 0.82
	canvas.draw_circle(center, maxf(1.4, 2.2 * context.scale_factor), lock_dot)

func _draw_dashed_line(
	canvas: CanvasItem,
	start: Vector2,
	finish: Vector2,
	context: BallRenderContext,
	alpha: float
) -> void:
	var segment := finish - start
	var length := segment.length()
	if length <= 0.001:
		return
	var direction := segment / length
	var dash_length := DASH_WORLD_LENGTH * context.scale_factor
	var gap_length := GAP_WORLD_LENGTH * context.scale_factor
	var period := dash_length + gap_length
	var cursor := -fmod(context.elapsed * 46.0 * context.scale_factor, period)
	var line_color := _line_color
	line_color.a = alpha * lerpf(0.22, 0.72, animation_progress())
	while cursor < length:
		var from_distance := maxf(0.0, cursor)
		var to_distance := minf(length, cursor + dash_length)
		if to_distance > from_distance:
			canvas.draw_line(
				start + direction * from_distance,
				start + direction * to_distance,
				line_color,
				maxf(1.0, 1.5 * context.scale_factor),
				true
			)
		cursor += period
