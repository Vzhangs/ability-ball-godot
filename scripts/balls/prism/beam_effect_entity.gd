extends BallEntity

var _start := Vector2.ZERO
var _impact := Vector2.ZERO
var _branches := PackedVector2Array()
var _duration := 0.0
var _width := 0.0

func _init(side: int, start: Vector2, impact: Vector2, branches: PackedVector2Array, duration: float, width: float) -> void:
	owner_side = side
	_start = start
	_impact = impact
	_branches = branches.duplicate()
	_duration = duration
	_width = width
	pos = impact
	remaining = duration
	draw_layer = 35
	tags = PackedStringArray(["prism_beam_vfx"])

func step(_battle, _delta: float) -> void:
	pass

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := clampf(1.0 - remaining / maxf(_duration, 0.001), 0.0, 1.0)
	var alpha := pow(1.0 - progress, 0.65)
	if alpha < 0.001:
		return
	var scale := context.scale_factor
	var impact := context.point(_impact)
	var width := maxf(1.8, _width * scale) * (1.0 - progress * 0.48)
	_draw_ray(canvas, context.point(_start), impact, width, alpha, Color("ffe9a1"))
	for branch in _branches:
		_draw_ray(canvas, impact, context.point(branch), width * 0.52, alpha, Color("fff1bc"))
		_draw_impact(canvas, context.point(branch), (4.0 + progress * 10.0) * scale, alpha * 0.8)
	_draw_impact(canvas, impact, (7.0 + progress * 15.0) * scale, alpha)

func _draw_ray(canvas: CanvasItem, start: Vector2, finish: Vector2, width: float, alpha: float, tint: Color) -> void:
	if start.distance_squared_to(finish) < 0.0001:
		return
	canvas.draw_line(start, finish, Color(1.0, 0.83, 0.28, alpha * 0.10), width * 4.0, true)
	canvas.draw_line(start, finish, Color(tint, alpha * 0.30), width * 2.6, true)
	canvas.draw_line(start, finish, Color(tint, alpha), width, true)
	canvas.draw_line(start, finish, Color(1.0, 1.0, 1.0, alpha), maxf(1.0, width * 0.38), true)

func _draw_impact(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	canvas.draw_circle(center, size * 1.2, Color(1.0, 0.82, 0.36, alpha * 0.12))
	for index in range(4):
		var direction := Vector2.from_angle(float(index) * PI * 0.5 + PI * 0.25)
		canvas.draw_line(center, center + direction * size, Color(1.0, 0.96, 0.73, alpha * 0.8), 1.5, true)
	canvas.draw_circle(center, maxf(1.0, size * 0.17), Color(1.0, 1.0, 1.0, alpha))
