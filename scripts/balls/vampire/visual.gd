extends BallVisual

const FANG_SOCKET_RADIUS_SCALE := 0.84
const FANG_TIP_RADIUS_SCALE := 1.28
const FANG_SOCKET_SEPARATION_SCALE := 0.34
const FANG_TIP_SEPARATION_SCALE := 0.27

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var facing := _facing_direction()
	var tangent := Vector2(-facing.y, facing.x)
	var elapsed: float = context["elapsed"]
	var pulse := 0.5 + sin(elapsed * 4.6) * 0.5

	canvas.draw_circle(position, radius * 1.08, Color(0.48, 0.015, 0.08, 0.22 + pulse * 0.08))
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.GRADIENT, context["elapsed"])
	canvas.draw_arc(position, radius * 0.87, facing.angle() - 1.12, facing.angle() + 1.12, 24, Color("ff8a9c"), 2.1, true)

	# Only the two white fangs protrude; their roots remain inside the presentation-only body edge.
	var fang_color := Color("fff4e8")
	for side_sign in [-1.0, 1.0]:
		var socket_center: Vector2 = (
			position
			+ facing * radius * FANG_SOCKET_RADIUS_SCALE
			+ tangent * radius * FANG_SOCKET_SEPARATION_SCALE * side_sign
		)
		var base_center: Vector2 = socket_center + facing * radius * 0.015
		var tip: Vector2 = (
			position
			+ facing * radius * FANG_TIP_RADIUS_SCALE
			+ tangent * radius * FANG_TIP_SEPARATION_SCALE * side_sign
		)
		var half_base := tangent * radius * 0.08
		canvas.draw_colored_polygon(PackedVector2Array([
			base_center - half_base,
			base_center + half_base,
			tip,
		]), fang_color)
		canvas.draw_polyline(PackedVector2Array([
			base_center - half_base,
			tip,
			base_center + half_base,
		]), Color("ffc6ce"), 1.0, true)

func _facing_direction() -> Vector2:
	if ability == null or not ability.has_method("facing_direction"):
		return Vector2.RIGHT
	var value = ability.call("facing_direction")
	if value is Vector2 and value.length_squared() > 0.0001:
		return value.normalized()
	return Vector2.RIGHT
