extends BallEntity

var _duration := 1.0
var _maximum_radius := 100.0
var _color := Color("f07cff")

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	maximum_radius: float,
	duration: float,
	color: Color
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_maximum_radius = maximum_radius
	_duration = maxf(0.001, duration)
	remaining = _duration
	_color = color
	tags = PackedStringArray(["psychic_pulse_vfx"])
	draw_layer = 18

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var fade := pow(1.0 - progress, 0.78)
	var center := screen_position(context)
	var scale_factor := context.scale_factor
	canvas.draw_circle(
		center,
		_maximum_radius * progress * scale_factor,
		Color(_color.r, _color.g, _color.b, fade * 0.045)
	)
	for wave in range(4):
		var wave_progress := clampf(progress * 1.42 - float(wave) * 0.12, 0.0, 1.0)
		if wave_progress <= 0.0:
			continue
		var wave_radius := _maximum_radius * wave_progress * scale_factor
		var alpha := (1.0 - wave_progress) * fade * (0.68 - float(wave) * 0.09)
		var rotation := context.elapsed * (1.7 + float(wave) * 0.22) + float(wave) * 0.8
		for arc in range(3):
			var start_angle := rotation + float(arc) * TAU / 3.0
			canvas.draw_arc(
				center,
				wave_radius,
				start_angle,
				start_angle + PI * 0.48,
				18,
				Color(_color.r, _color.g, _color.b, alpha),
				maxf(1.0, (3.2 - float(wave) * 0.45) * scale_factor),
				true
			)
