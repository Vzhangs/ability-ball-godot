extends BallEntity

const LINK_SEGMENTS := 18

var _source
var _target_ref: WeakRef
var _duration := 1.0
var _psychic_color := Color("f07cff")
var _target_color := Color.WHITE

func _init(
	spawn_owner_side: int,
	source,
	target: BallEntity,
	duration: float,
	psychic_color: Color,
	target_color: Color
) -> void:
	owner_side = spawn_owner_side
	_source = source
	_target_ref = weakref(target)
	pos = source.pos
	_duration = maxf(0.001, duration)
	remaining = _duration
	_psychic_color = psychic_color
	_target_color = target_color
	tags = PackedStringArray(["psychic_link_vfx"])
	draw_layer = 24

func step(_battle, _delta: float) -> void:
	var target = _target_ref.get_ref()
	if target == null or target.removed:
		removed = true
		return
	pos = _source.pos

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var target = _target_ref.get_ref()
	if target == null or target.removed:
		return
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var alpha := sin(progress * PI)
	var start := screen_position(context, _source.pos)
	var finish := screen_position(context, target.pos)
	var offset := finish - start
	if offset.length_squared() <= 0.01:
		return
	var tangent := Vector2(-offset.y, offset.x).normalized()
	var points := PackedVector2Array()
	for index in range(LINK_SEGMENTS + 1):
		var ratio := float(index) / float(LINK_SEGMENTS)
		var envelope := sin(ratio * PI)
		var wave := sin(ratio * PI * 6.0 - context.elapsed * 18.0)
		points.append(start.lerp(finish, ratio) + tangent * wave * envelope * 7.0 * context.scale_factor)
	canvas.draw_polyline(points, Color(_psychic_color.r, _psychic_color.g, _psychic_color.b, alpha * 0.34), 6.0 * context.scale_factor, true)
	canvas.draw_polyline(points, Color(1.0, 0.82, 1.0, alpha * 0.92), 1.8 * context.scale_factor, true)
	var target_radius: float = (target.radius + 8.0 + progress * 12.0) * context.scale_factor
	canvas.draw_arc(finish, target_radius, context.elapsed * 7.0, context.elapsed * 7.0 + PI * 1.55, 28, Color(_target_color.r, _target_color.g, _target_color.b, alpha * 0.84), 2.6 * context.scale_factor, true)
	canvas.draw_arc(finish, target_radius * 0.72, -context.elapsed * 9.0, -context.elapsed * 9.0 + PI * 1.35, 24, Color(_psychic_color.r, _psychic_color.g, _psychic_color.b, alpha * 0.82), 2.0 * context.scale_factor, true)
