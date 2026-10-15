extends BallEntity

var _duration := 0.0

func _init(side: int, center: Vector2, blast_radius: float, duration: float) -> void:
	owner_side = side
	pos = center
	radius = blast_radius
	_duration = duration
	remaining = duration
	tags = PackedStringArray(["creeper_blast_vfx"])
	draw_layer = -1

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var center := screen_position(context)
	var reach := radius * context.scale_factor
	var wave := reach * sin(progress * PI * 0.5)
	if wave < 0.5 or fade <= 0.001:
		return
	canvas.draw_circle(center, wave, Color(0.94, 0.96, 0.83, fade * 0.13))
	canvas.draw_circle(center, wave, Color(1.0, 1.0, 0.92, fade * 0.9), false, maxf(1.0, 7.0 * fade))
	for index in range(16):
		var angle := float(index) * TAU / 16.0
		var direction := Vector2.from_angle(angle)
		var spot := center + direction * wave * (0.45 + 0.4 * float(index % 3) / 2.0)
		var size := reach * (0.07 + 0.035 * float(index % 3)) * sin(progress * PI)
		canvas.draw_rect(Rect2(spot - Vector2.ONE * size, Vector2.ONE * size * 2.0),
			Color(0.72, 0.75, 0.69, fade * 0.66))
		canvas.draw_arc(spot, maxf(0.5, size * 1.4), angle, angle + PI * 1.45, 12,
			Color(1.0, 1.0, 0.96, fade), maxf(1.0, size * 0.35), true)
