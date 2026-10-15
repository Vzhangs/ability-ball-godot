extends BallEntity

var _duration := 0.2
var _body_color := Color.WHITE
var _accent_color := Color.WHITE
var _movement_direction := Vector2.RIGHT

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_radius: float,
	duration: float,
	body_color: Color,
	accent_color: Color,
	movement_direction: Vector2
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	radius = spawn_radius
	_duration = maxf(0.01, duration)
	remaining = _duration
	_body_color = body_color
	_accent_color = accent_color
	_movement_direction = movement_direction.normalized()
	if _movement_direction.length_squared() <= 0.0001:
		_movement_direction = Vector2.RIGHT
	tags = PackedStringArray(["blade_dancer_afterimage"])
	draw_layer = -8

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var life_ratio := clampf(remaining / _duration, 0.0, 1.0)
	var center := screen_position(context)
	var screen_radius := radius * context.scale_factor
	var body := _body_color
	body.a = 0.24 * life_ratio
	var accent := _accent_color
	accent.a = 0.5 * life_ratio
	canvas.draw_circle(center, screen_radius, body)
	canvas.draw_circle(center, screen_radius, accent, false, maxf(1.0, 1.8 * context.scale_factor))
	var tangent := _movement_direction.orthogonal()
	for index in range(3):
		var lateral := (float(index) - 1.0) * screen_radius * 0.42
		var start := center + tangent * lateral - _movement_direction * screen_radius * 0.62
		var finish := center + tangent * lateral + _movement_direction * screen_radius * 0.76
		canvas.draw_line(start, finish, accent, maxf(0.8, 1.1 * context.scale_factor), true)
