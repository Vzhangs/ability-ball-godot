extends BallEntity

var _duration := 0.0

func _init(spawn_owner_side: int, spawn_position: Vector2, duration: float, zone_radius: float) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	remaining = duration
	_duration = duration
	radius = zone_radius
	tags = PackedStringArray(["flame_zone"])
	draw_layer = -40

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var alpha := clampf(remaining / _duration, 0.0, 1.0)
	var position := screen_position(context)
	var draw_radius := radius * scale_factor
	canvas.draw_circle(position, draw_radius, Color(1.0, 0.19, 0.02, alpha * 0.19))
	canvas.draw_circle(position, draw_radius * 0.65, Color(1.0, 0.68, 0.08, alpha * 0.18))

func is_absorbable() -> bool:
	return true

func absorption_radius() -> float:
	return minf(12.0, radius * 0.35)

func absorption_visual_color() -> Color:
	return Color("ff7a24")
