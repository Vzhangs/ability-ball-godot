extends BallEntity

var _duration := 0.0
var _blast_radius := 0.0

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_radius: float,
	spawn_duration: float
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_blast_radius = maxf(1.0, spawn_radius)
	_duration = maxf(0.01, spawn_duration)
	remaining = _duration
	tags = PackedStringArray(["flame_combustion_vfx"])
	draw_layer = -12

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var fade := pow(1.0 - progress, 0.72)
	var scale_factor := context.scale_factor
	var center := screen_position(context)
	var wave_radius := _blast_radius * scale_factor * sin(progress * PI * 0.5)
	if wave_radius <= 2.0:
		return
	var phase := pos.x * 0.071 + pos.y * 0.053
	canvas.draw_colored_polygon(
		_blast_shape(center, wave_radius, phase),
		ownership_visual_color(Color(0.88, 0.08, 0.008, fade * 0.24))
	)
	canvas.draw_colored_polygon(
		_blast_shape(center, wave_radius * 0.72, phase + 1.7),
		ownership_visual_color(Color(1.0, 0.34, 0.018, fade * 0.32))
	)
	canvas.draw_colored_polygon(
		_blast_shape(center, wave_radius * 0.42, phase + 3.1),
		ownership_visual_color(Color(1.0, 0.83, 0.18, fade * 0.48))
	)
	for flame_index in range(12):
		var angle := TAU * float(flame_index) / 12.0
		var radial := Vector2.from_angle(angle)
		var tangent := radial.rotated(PI * 0.5)
		var base := center + radial * wave_radius * (0.44 + 0.12 * sin(phase + flame_index))
		var tip := center + radial * wave_radius * (0.92 + 0.08 * sin(phase * 1.3 + flame_index * 2.0))
		var half_width := maxf(1.0, wave_radius * 0.075 * fade)
		canvas.draw_colored_polygon(PackedVector2Array([
			base - tangent * half_width,
			tip,
			base + tangent * half_width,
		]), ownership_visual_color(Color(1.0, 0.46, 0.04, fade * 0.82)))

func _blast_shape(center: Vector2, draw_radius: float, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in range(20):
		var angle := TAU * float(point_index) / 20.0
		var raggedness := 0.82 \
			+ 0.13 * sin(float(point_index) * 2.37 + phase) \
			+ 0.05 * sin(float(point_index) * 4.81 - phase)
		points.append(center + Vector2.from_angle(angle) * draw_radius * raggedness)
	return points
