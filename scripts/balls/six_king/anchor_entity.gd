extends BallEntity

var _duration := 0.0

func _init(spawn_owner_side: int, spawn_position: Vector2, duration: float) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	remaining = duration
	_duration = duration
	tags = PackedStringArray(["six_king_anchor"])
	draw_layer = -20

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var fighter = context.fighter_for_side(owner_side)
	var position := screen_position(context)
	var target := screen_position(context, fighter.pos)
	var alpha := clampf(remaining / _duration, 0.0, 1.0)
	canvas.draw_line(position, target, Color(0.59, 0.89, 1.0, alpha * 0.72), 2.0, true)
	var inward := (context.viewport_size * 0.5 - position).normalized()
	var tangent := Vector2(-inward.y, inward.x)
	var polygon := PackedVector2Array([
		position + inward * 20.0,
		position - inward * 6.0 + tangent * 8.0,
		position - inward * 6.0 - tangent * 8.0,
	])
	canvas.draw_colored_polygon(polygon, Color(0.18, 1.0, 0.38, alpha))

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return Color(0.18, 1.0, 0.38)
