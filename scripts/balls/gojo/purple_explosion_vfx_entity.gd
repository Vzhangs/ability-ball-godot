extends BallEntity

const Glow := preload("res://scripts/balls/core/combat_glow.gd")

var _duration := 1.4

func _init(side: int, center: Vector2, blast_radius: float, duration: float) -> void:
	owner_side = side
	pos = center
	radius = maxf(1.0, blast_radius)
	_duration = maxf(0.05, duration)
	remaining = _duration
	tags = PackedStringArray(["gojo_purple_explosion_vfx"])
	draw_layer = -1

func animation_progress() -> float:
	return clampf(1.0 - remaining / _duration, 0.0, 1.0)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := animation_progress()
	var fade := 1.0 - smoothstep(0.4, 1.0, progress)
	if fade <= 0.001:
		return
	var center := screen_position(context)
	var reach := radius * context.scale_factor
	var expansion := 1.0 - pow(1.0 - clampf(progress / 0.32, 0.0, 1.0), 3.0)
	var wave_radius := reach * (0.08 + expansion * 0.92)
	var core_fade := pow(1.0 - progress, 2.2)
	var core_radius := reach * (0.16 + expansion * 0.11)
	Glow.halo(canvas, center, reach * (0.6 + expansion * 0.7), Color(0.68, 0.16, 1.0, fade * 0.7))
	canvas.draw_circle(center, wave_radius * 0.94, Color(0.4, 0.04, 0.85, fade * 0.16))
	for index in range(7):
		var angle := TAU * float(index) / 7.0 + progress * 0.35
		var cloud_center := center + Vector2.from_angle(angle) * wave_radius * 0.48
		Glow.halo(canvas, cloud_center, wave_radius * 0.46, Color(0.85, 0.28, 1.0, fade * 0.3))
	_draw_wave(canvas, center, wave_radius, fade, context.scale_factor)
	_draw_wave(canvas, center, wave_radius * 0.77, fade * 0.55, context.scale_factor * 0.6)
	Glow.halo(canvas, center, core_radius * 2.8, Color(0.96, 0.58, 1.0, core_fade * 0.9))
	canvas.draw_circle(center, core_radius, Color(0.94, 0.7, 1.0, core_fade * 0.65))
	canvas.draw_circle(center, core_radius * 0.5, Color(1.0, 0.96, 1.0, core_fade * 0.95))
	for index in range(20):
		var angle := float(index) * 2.399963 + progress * 0.12
		var direction := Vector2.from_angle(angle)
		var depth := float(index % 5) / 4.0
		var point := center + direction * wave_radius * (0.5 + depth * 0.52)
		var length := reach * (0.055 + depth * 0.075) * (0.3 + fade * 0.7)
		Glow.streak(canvas, point - direction * length, point,
			Color(0.94, 0.56, 1.0, fade * 0.9), maxf(0.8, 2.8 * context.scale_factor * fade))
		var side := direction.orthogonal()
		var shard_width := reach * (0.008 + depth * 0.006) * fade
		if shard_width > 0.1:
			canvas.draw_colored_polygon(PackedVector2Array([
				point + direction * length * 0.3,
				point - direction * length + side * shard_width,
				point - direction * length - side * shard_width,
			]), Color(1.0, 0.84, 1.0, fade * 0.85))

func _draw_wave(canvas: CanvasItem, center: Vector2, wave_radius: float, alpha: float, scale: float) -> void:
	canvas.draw_arc(center, wave_radius, 0.0, TAU, 96,
		Color(0.7, 0.12, 1.0, alpha * 0.22), maxf(1.0, 28.0 * scale), true)
	canvas.draw_arc(center, wave_radius, 0.0, TAU, 96,
		Color(0.83, 0.32, 1.0, alpha * 0.9), maxf(1.0, 10.0 * scale), true)
	canvas.draw_arc(center, wave_radius, 0.0, TAU, 96,
		Color(1.0, 0.88, 1.0, alpha), maxf(0.8, 2.8 * scale), true)
