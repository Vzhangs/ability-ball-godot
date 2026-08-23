extends BallVisual

const LOW_COLOR := Color("2f72e8")
const HIGH_COLOR := Color("ff4e5a")

func trail_alpha() -> float:
	return 0.24

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	if ability == null or not bool(ability.call("is_grid_active")):
		return
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	for ring_index in range(2):
		var ring_radius := radius * (1.24 + float(ring_index) * 0.24)
		var start_angle := elapsed * (0.9 + float(ring_index) * 0.25) + float(ring_index) * PI
		canvas.draw_arc(
			position,
			ring_radius,
			start_angle,
			start_angle + PI * 1.42,
			30,
			Color(0.42, 0.9, 1.0, 0.3 - float(ring_index) * 0.08),
			2.0,
			true
		)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var active := ability != null and bool(ability.call("is_grid_active"))
	if active:
		canvas.draw_circle(position, radius * 1.12, Color(0.42, 0.9, 1.0, 0.2))
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius * 0.84, Color("151533"))
	canvas.draw_circle(position, radius, fighter.accent, false, 2.6)
	var values: Array[int] = []
	if active:
		values.assign(ability.call("current_values"))
	var cell_size := radius * 0.28
	var gap := radius * 0.07
	var total_size := cell_size * 3.0 + gap * 2.0
	var start := position - Vector2.ONE * total_size * 0.5
	for row in range(3):
		for column in range(3):
			var index := row * 3 + column
			var cell_rect := Rect2(
				start + Vector2(column, row) * (cell_size + gap),
				Vector2.ONE * cell_size
			)
			var color := Color(fighter.accent.r, fighter.accent.g, fighter.accent.b, 0.38)
			if active and values.size() == 9:
				var ratio := float(values[index]) / maxf(1.0, module.settingf("damage_max"))
				color = LOW_COLOR.lerp(HIGH_COLOR, clampf(ratio, 0.0, 1.0))
				color.a = 0.92
			canvas.draw_rect(cell_rect, color)
			canvas.draw_rect(cell_rect, Color(0.86, 0.97, 1.0, 0.76), false, maxf(1.0, radius * 0.045))
