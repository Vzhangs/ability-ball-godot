extends BallVisual

const EyeRenderer := preload("res://scripts/balls/yuri/eye_renderer.gd")

func trail_alpha() -> float:
	return 0.22

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var controlled := int(ability.call("controlled_count")) if ability != null else 0
	for ring in range(3):
		var ring_radius := radius * (1.26 + float(ring) * 0.18)
		var start := elapsed * (0.8 + float(ring) * 0.16) + float(ring) * 1.9
		canvas.draw_arc(position, ring_radius, start, start + PI * 1.18, 28, Color(0.91, 0.32, 1.0, 0.24 - float(ring) * 0.045), 2.0, true)
	for node in range(mini(controlled, 6)):
		var angle := elapsed * 1.7 + TAU * float(node) / float(maxi(1, mini(controlled, 6)))
		var node_position := position + Vector2.from_angle(angle) * radius * 1.58
		canvas.draw_circle(node_position, radius * 0.085, Color("f7b6ff"))

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	canvas.draw_circle(position, radius * 1.08, Color(0.94, 0.36, 1.0, 0.18))
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius * 0.82, Color("24102f"))
	canvas.draw_circle(position, radius, fighter.accent, false, 2.5)
	EyeRenderer.draw_eye(canvas, position, radius, elapsed)
