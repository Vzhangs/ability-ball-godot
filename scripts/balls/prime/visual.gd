extends BallVisual

const NODE_COUNT := 7
const INNER_COLOR := Color("071b2a")
const PRIME_CYAN := Color("54e6e1")
const PRIME_GOLD := Color("f6c85f")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

func trail_alpha() -> float:
	return 0.32

func trail_width_multiplier() -> float:
	return 1.08

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var flash_ratio := _impact_flash_ratio()
	for ring_index in range(2):
		var ring_radius := radius * (1.20 + float(ring_index) * 0.20 + flash_ratio * 0.08)
		var start_angle := elapsed * (0.72 + float(ring_index) * 0.24) + float(ring_index) * PI
		canvas.draw_arc(
			center,
			ring_radius,
			start_angle,
			start_angle + PI * 1.34,
			28,
			Color(PRIME_CYAN.r, PRIME_CYAN.g, PRIME_CYAN.b, 0.18 + flash_ratio * 0.18),
			maxf(1.2, radius * 0.05),
			true
		)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var flash_ratio := _impact_flash_ratio()
	var prime_value := _current_prime()
	var pulse := 1.0 + sin(elapsed * 2.8) * 0.018 + flash_ratio * 0.075

	canvas.draw_circle(
		center,
		radius * 1.18 * pulse,
		Color(PRIME_CYAN.r, PRIME_CYAN.g, PRIME_CYAN.b, 0.11 + flash_ratio * 0.20)
	)
	Surface.draw(canvas, center, radius, fighter.color, fighter.accent, Surface.Style.ORBIT, context["elapsed"])
	canvas.draw_circle(center, radius, fighter.accent, false, maxf(2.5, radius * 0.09))
	canvas.draw_circle(center, radius * 0.72, PRIME_CYAN, false, maxf(1.2, radius * 0.045))

	_draw_prime_nodes(canvas, center, radius, elapsed, prime_value, flash_ratio)
	_draw_prime_badge(canvas, center, radius, flash_ratio)
	_draw_next_damage_badge(canvas, center, radius, prime_value, flash_ratio)

func _draw_prime_nodes(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float,
	prime_value: int,
	flash_ratio: float
) -> void:
	var active_count := 1 + posmod(prime_value, NODE_COUNT)
	var rotation := elapsed * 0.48
	for index in range(NODE_COUNT):
		var angle := rotation + float(index) * TAU / float(NODE_COUNT)
		var node_center := center + Vector2.from_angle(angle) * radius * 0.76
		var active := index < active_count
		var node_color := PRIME_GOLD if active else PRIME_CYAN
		var node_radius := radius * (0.075 if active else 0.045)
		if active:
			canvas.draw_circle(
				node_center,
				node_radius * (1.8 + flash_ratio * 0.6),
				Color(node_color.r, node_color.g, node_color.b, 0.16 + flash_ratio * 0.16)
			)
		canvas.draw_circle(
			node_center,
			node_radius,
			Color(node_color.r, node_color.g, node_color.b, 0.96 if active else 0.52)
		)

func _draw_prime_badge(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	flash_ratio: float
) -> void:
	var badge_radius := radius * 0.43 * (1.0 + flash_ratio * 0.10)
	canvas.draw_circle(center, badge_radius * 1.18, Color(0.02, 0.09, 0.14, 0.88))
	canvas.draw_circle(center, badge_radius, Color(PRIME_GOLD.r, PRIME_GOLD.g, PRIME_GOLD.b, 0.16))
	canvas.draw_circle(center, badge_radius, PRIME_GOLD, false, maxf(1.8, radius * 0.065))
	var font_size := clampi(int(round(radius * 0.78)), 15, 40)
	var text_width := radius * 0.9
	var baseline := Vector2(
		center.x - text_width * 0.5,
		center.y + float(font_size) * 0.34
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline + Vector2(1.2, 1.2),
		"P",
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(0.0, 0.0, 0.0, 0.88)
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline,
		"P",
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(1.0, 0.91, 0.58, 0.92)
	)

func _draw_next_damage_badge(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	prime_value: int,
	flash_ratio: float
) -> void:
	if ability == null:
		return
	var label := str(prime_value)
	var font_size := clampi(int(round(radius * 0.52)), 12, 27)
	var badge_height := maxf(17.0, float(font_size) * 1.38)
	var estimated_text_width := float(font_size) * (float(label.length()) * 0.68 + 0.7)
	var badge_width := maxf(radius * 1.05, estimated_text_width + radius * 0.38)
	var pulse := 1.0 + flash_ratio * 0.08
	var badge_size := Vector2(badge_width, badge_height) * pulse
	var badge_center := center + Vector2(0.0, -radius - badge_size.y * 0.72)
	_draw_pill(
		canvas,
		badge_center,
		badge_size + Vector2.ONE * maxf(3.0, radius * 0.14),
		Color(PRIME_CYAN.r, PRIME_CYAN.g, PRIME_CYAN.b, 0.10 + flash_ratio * 0.12)
	)
	_draw_pill(canvas, badge_center, badge_size, Color(0.015, 0.065, 0.095, 0.94))
	_draw_pill_outline(
		canvas,
		badge_center,
		badge_size,
		Color(PRIME_GOLD.r, PRIME_GOLD.g, PRIME_GOLD.b, 0.92),
		maxf(1.2, radius * 0.048)
	)
	var text_width := badge_size.x
	var baseline := Vector2(
		badge_center.x - text_width * 0.5,
		badge_center.y + float(font_size) * 0.34
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline + Vector2(1.0, 1.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(0.0, 0.0, 0.0, 0.94)
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline,
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(1.0, 0.94, 0.68, 1.0)
	)

func _draw_pill(
	canvas: CanvasItem,
	center: Vector2,
	size: Vector2,
	color: Color
) -> void:
	var cap_radius := size.y * 0.5
	var middle_width := maxf(0.0, size.x - size.y)
	canvas.draw_rect(
		Rect2(center - Vector2(middle_width * 0.5, cap_radius), Vector2(middle_width, size.y)),
		color
	)
	canvas.draw_circle(center + Vector2(-middle_width * 0.5, 0.0), cap_radius, color)
	canvas.draw_circle(center + Vector2(middle_width * 0.5, 0.0), cap_radius, color)

func _draw_pill_outline(
	canvas: CanvasItem,
	center: Vector2,
	size: Vector2,
	color: Color,
	width: float
) -> void:
	var cap_radius := size.y * 0.5
	var middle_width := maxf(0.0, size.x - size.y)
	canvas.draw_line(
		center + Vector2(-middle_width * 0.5, -cap_radius),
		center + Vector2(middle_width * 0.5, -cap_radius),
		color,
		width,
		true
	)
	canvas.draw_line(
		center + Vector2(-middle_width * 0.5, cap_radius),
		center + Vector2(middle_width * 0.5, cap_radius),
		color,
		width,
		true
	)
	canvas.draw_arc(
		center + Vector2(-middle_width * 0.5, 0.0),
		cap_radius,
		PI * 0.5,
		PI * 1.5,
		16,
		color,
		width,
		true
	)
	canvas.draw_arc(
		center + Vector2(middle_width * 0.5, 0.0),
		cap_radius,
		-PI * 0.5,
		PI * 0.5,
		16,
		color,
		width,
		true
	)

func _current_prime() -> int:
	return int(ability.call("current_prime")) if ability != null else 2

func _impact_flash_ratio() -> float:
	return float(ability.call("impact_flash_ratio")) if ability != null else 0.0
