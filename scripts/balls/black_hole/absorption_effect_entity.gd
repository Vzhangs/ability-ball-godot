extends BallEntity

var _center_source
var _duration := 0.0
var _elapsed := 0.0
var _start_angle := 0.0
var _start_distance := 0.0
var _start_radius := 8.0
var _color := Color("bc63ff")
var _swirl_sign := 1.0

func _init(
	spawn_owner_side: int,
	center_source,
	spawn_position: Vector2,
	visual_radius: float,
	duration: float,
	color: Color,
	swirl_sign: float
) -> void:
	owner_side = spawn_owner_side
	_center_source = center_source
	pos = spawn_position
	_start_distance = maxf(1.0, spawn_position.distance_to(center_source.pos))
	_start_angle = (spawn_position - center_source.pos).angle()
	_start_radius = clampf(visual_radius, 5.0, 18.0)
	_duration = duration
	remaining = duration
	_color = color
	_swirl_sign = swirl_sign
	tags = PackedStringArray(["absorption_vfx"])
	draw_layer = 20

func tick_lifetime(_delta: float) -> void:
	# Completion emits the final collapse particles, so this entity owns its lifetime.
	pass

func step(battle, delta: float) -> void:
	_elapsed = minf(_duration, _elapsed + delta)
	remaining = maxf(0.0, _duration - _elapsed)
	pos = _position_at(_progress())
	if remaining > 0.0:
		return
	var center: Vector2 = _center_source.pos
	battle.spawn_particles(center, _color, 12, 155.0)
	battle.spawn_ring(center, _color, 5.0, 62.0, 0.28)
	battle.shake_camera(1.8)
	removed = true

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := _progress()
	var collapse := pow(1.0 - progress, 1.35)
	var scale_factor := context.scale_factor
	var center := screen_position(context, _center_source.pos)
	for ghost_index in range(4, -1, -1):
		var ghost_progress := maxf(0.0, progress - float(ghost_index) * 0.045)
		var ghost_position := screen_position(context, _position_at(ghost_progress))
		var ghost_scale := pow(1.0 - ghost_progress, 1.35)
		var alpha := (0.12 + float(4 - ghost_index) * 0.07) * ghost_scale
		canvas.draw_circle(
			ghost_position,
			maxf(1.0, _start_radius * ghost_scale * scale_factor),
			Color(_color.r, _color.g, _color.b, alpha)
		)
	var position := screen_position(context)
	var draw_radius := maxf(1.0, _start_radius * collapse * scale_factor)
	var direction := (center - position).normalized()
	var tangent := Vector2(-direction.y, direction.x) * _swirl_sign
	var streak_length := (10.0 + progress * 28.0) * scale_factor
	canvas.draw_line(position - tangent * streak_length, position + direction * streak_length * 0.6, Color(_color.r, _color.g, _color.b, 0.68 * collapse), maxf(1.0, draw_radius * 0.55), true)
	canvas.draw_circle(position, draw_radius * 1.8, Color(_color.r, _color.g, _color.b, 0.16 * collapse))
	canvas.draw_circle(position, draw_radius, Color(_color.r, _color.g, _color.b, 0.88 * collapse))
	for ring_index in range(2):
		var ring_radius := (8.0 + ring_index * 8.0 + progress * 11.0) * scale_factor
		canvas.draw_arc(center, ring_radius, progress * TAU * 3.0 + ring_index, progress * TAU * 3.0 + ring_index + PI * 1.25, 18, Color(_color.r, _color.g, _color.b, 0.34 * collapse), 1.5, true)

func _progress() -> float:
	return clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0)

func _position_at(progress: float) -> Vector2:
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var angle := _start_angle + _swirl_sign * eased * PI * 1.85
	var distance := lerpf(_start_distance, 3.0, eased)
	return _center_source.pos + Vector2.from_angle(angle) * distance
