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
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.ORBIT, context["elapsed"])
	canvas.draw_circle(position, radius, fighter.accent, false, 2.5)
	EyeRenderer.draw_eye(canvas, position, radius, elapsed)
	if ability != null:
		_draw_overload_feedback(
			canvas,
			position,
			radius,
			elapsed,
			float(ability.call("overload_flash_ratio")),
			int(ability.call("overload_excess_count"))
		)

func _draw_overload_feedback(
	canvas: CanvasItem,
	position: Vector2,
	radius: float,
	elapsed: float,
	flash_ratio: float,
	excess_count: int
) -> void:
	if flash_ratio <= 0.0 or excess_count <= 0:
		return
	var intensity := clampf(0.7 + float(excess_count) * 0.08, 0.7, 1.0) * flash_ratio
	var arc_color := Color(1.0, 0.25, 0.9, 0.72 * intensity)
	var core_color := Color(1.0, 0.88, 1.0, 0.9 * intensity)
	var bolt_count := mini(6, 2 + excess_count)
	for bolt_index in range(bolt_count):
		var base_angle := -PI * 0.86 + PI * 1.72 * float(bolt_index) / float(maxi(1, bolt_count - 1))
		var points := PackedVector2Array()
		for segment_index in range(6):
			var progress := float(segment_index) / 5.0
			var jitter := sin(
				elapsed * 31.0
					+ float(bolt_index) * 2.17
					+ float(segment_index) * 3.41
			) * radius * 0.11 * sin(progress * PI)
			var direction := Vector2.from_angle(base_angle)
			var normal := direction.orthogonal()
			points.append(
				position
					+ direction * lerpf(radius * 0.34, radius * 1.34, progress)
					+ normal * jitter
			)
		canvas.draw_polyline(points, arc_color, 3.2, true)
		canvas.draw_polyline(points, core_color, 1.1, true)
	canvas.draw_arc(
		position,
		radius * (1.08 + 0.04 * sin(elapsed * 24.0)),
		-PI * 0.9,
		-PI * 0.1,
		20,
		Color(0.92, 0.34, 1.0, 0.34 * intensity),
		2.0,
		true
	)
