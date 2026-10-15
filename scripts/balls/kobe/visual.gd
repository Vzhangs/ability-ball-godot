extends BallVisual

const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

func trail_alpha() -> float:
	return 0.28 if _active_move() == "cyclone" else 0.16

func trail_width_multiplier() -> float:
	return 1.35 if _active_move() == "cyclone" else 0.95

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	if _active_move() == "cyclone":
		for index in range(3):
			var angle := elapsed * (7.0 + float(index)) + TAU * float(index) / 3.0
			canvas.draw_arc(
				position, radius * (1.12 + float(index) * 0.22), angle,
				angle + PI * 1.35, 26,
				Color(1.0, 0.78, 0.12, 0.42 - float(index) * 0.09), 2.2, true
			)
	elif _active_move() == "elbow":
		var direction := _move_direction()
		canvas.draw_colored_polygon(PackedVector2Array([
			position + direction * radius * 0.3 + direction.orthogonal() * radius * 0.45,
			position + direction * radius * 2.0,
			position + direction * radius * 0.3 - direction.orthogonal() * radius * 0.45,
		]), Color(1.0, 0.63, 0.12, 0.16))

func draw_ball(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	Surface.draw(canvas, position, radius, Color("5a2a83"), Color("f4c542"), Surface.Style.SOLID, context["elapsed"])
	canvas.draw_circle(position, radius, Color("f4c542"), false, 2.8, true)
	canvas.draw_arc(position, radius * 0.72, -PI * 0.88, PI * 0.88, 28, Color("f4c542"), 2.2, true)
	canvas.draw_arc(position, radius * 0.72, PI * 0.12, PI * 1.88, 28, Color("8f5bcf"), 2.0, true)
	canvas.draw_line(
		position + Vector2(-radius * 0.78, radius * 0.22),
		position + Vector2(radius * 0.78, radius * 0.22),
		Color("f4c542"), radius * 0.2, true
	)
	var font: Font = CjkFontProviderScript.font()
	var font_size := clampi(int(radius * 0.78), 16, 36)
	var text_width := radius * 1.22
	var baseline := position + Vector2(-text_width * 0.5, radius * 0.05)
	canvas.draw_string(
		font, baseline + Vector2(1.5, 1.5), "24",
		HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, Color(0.08, 0.03, 0.1, 0.82)
	)
	canvas.draw_string(
		font, baseline, "24", HORIZONTAL_ALIGNMENT_CENTER,
		text_width, font_size, Color("fff0a0")
	)
	var eye_y := position.y - radius * 0.36
	canvas.draw_line(
		Vector2(position.x - radius * 0.44, eye_y),
		Vector2(position.x - radius * 0.12, eye_y + radius * 0.1),
		Color("fff4c2"), 2.4, true
	)
	canvas.draw_line(
		Vector2(position.x + radius * 0.44, eye_y),
		Vector2(position.x + radius * 0.12, eye_y + radius * 0.1),
		Color("fff4c2"), 2.4, true
	)

func _active_move() -> String:
	return String(ability.call("active_move")) if ability != null else ""

func _move_direction() -> Vector2:
	return ability.call("move_direction") as Vector2 if ability != null else Vector2.RIGHT
