extends BallEntity

var _direction := Vector2.RIGHT
var _duration := 0.3
var _body_color := Color("a92120")
var _accent_color := Color("f6d89a")

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	shot_direction: Vector2,
	projectile_radius: float,
	duration: float,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_direction = shot_direction.normalized()
	if _direction.length_squared() <= 0.0001:
		_direction = Vector2.RIGHT
	radius = maxf(2.0, projectile_radius)
	_duration = maxf(0.05, duration)
	remaining = _duration
	_body_color = body_color
	_accent_color = accent_color
	tags = PackedStringArray(["chess_cannon_muzzle_vfx"])
	draw_layer = 72

func animation_progress() -> float:
	return clampf(1.0 - remaining / _duration, 0.0, 1.0)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := animation_progress()
	var envelope := sin(progress * PI)
	var fade := pow(1.0 - progress, 1.35)
	var center := screen_position(context)
	var forward := _direction
	var tangent := forward.orthogonal()
	var draw_radius := radius * context.scale_factor
	var flare_length := draw_radius * (3.4 + progress * 2.6)
	canvas.draw_circle(
		center,
		draw_radius * (2.7 + envelope * 1.2),
		Color(_accent_color.r, _accent_color.g, _accent_color.b, fade * 0.22)
	)
	for flare_index in range(5):
		var lane := float(flare_index - 2) / 2.0
		var lane_offset := tangent * draw_radius * lane * (0.6 + envelope * 0.45)
		var length_scale := 1.0 - absf(lane) * 0.26
		var half_width := draw_radius * (0.42 - absf(lane) * 0.1) * fade
		var flare := PackedVector2Array([
			center + lane_offset - tangent * half_width,
			center + lane_offset + forward * flare_length * length_scale,
			center + lane_offset + tangent * half_width,
		])
		var flare_color := _accent_color.lerp(Color.WHITE, 0.72 - absf(lane) * 0.18)
		flare_color.a = fade * (0.86 - absf(lane) * 0.18)
		canvas.draw_colored_polygon(flare, flare_color)
	canvas.draw_circle(center, draw_radius * (1.15 + envelope * 0.48), Color(1.0, 0.98, 0.8, fade))
	canvas.draw_arc(
		center,
		draw_radius * (1.4 + progress * 3.2),
		0.0,
		TAU,
		28,
		Color(_body_color.r, _body_color.g, _body_color.b, fade * 0.72),
		maxf(1.2, draw_radius * 0.24 * fade),
		true
	)
