extends BallVisual

const AttributeIcon := preload("res://scripts/balls/hero/attribute_icon.gd")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

const GEM_ORBIT_SPEED := 0.62
const GEM_ORBIT_RADIUS_SCALE := 1.30
const GEM_ICON_SIZE_SCALE := 0.46

func trail_alpha() -> float:
	return 0.31

func trail_width_multiplier() -> float:
	return 1.1

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	if ability == null or int(ability.call("total_upgrades")) <= 0:
		return
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var total := int(ability.call("total_upgrades"))
	var ring_count := mini(3, 1 + int(floor(float(total) / 4.0)))
	for ring_index in range(ring_count):
		var ring_radius := radius * (1.25 + float(ring_index) * 0.18)
		var start := elapsed * (1.4 + float(ring_index) * 0.32) + float(ring_index) * 2.1
		canvas.draw_arc(
			center,
			ring_radius,
			start,
			start + PI * 1.15,
			28,
			Color(1.0, 0.82, 0.34, 0.27 - float(ring_index) * 0.05),
			maxf(1.4, radius * 0.055),
			true
		)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var pulse := 1.0 + sin(elapsed * 3.0) * 0.025
	canvas.draw_circle(center, radius * 1.18 * pulse, Color(0.28, 0.58, 1.0, 0.16))
	Surface.draw(canvas, center, radius, fighter.color, fighter.accent, Surface.Style.GRADIENT, context["elapsed"])
	canvas.draw_circle(center, radius, fighter.accent, false, maxf(2.6, radius * 0.095))

	# A broad sword behind the badge and a gold shield create a readable hero silhouette.
	var sword_direction := Vector2(0.66, -0.75)
	var sword_normal := sword_direction.orthogonal()
	var sword_start := center - sword_direction * radius * 0.53
	var sword_tip := center + sword_direction * radius * 0.68
	canvas.draw_line(sword_start, sword_tip, Color("fff1bc"), maxf(2.8, radius * 0.11), true)
	canvas.draw_line(
		center - sword_normal * radius * 0.30,
		center + sword_normal * radius * 0.30,
		Color("d99a2b"),
		maxf(3.0, radius * 0.13),
		true
	)
	var shield := PackedVector2Array([
		center + Vector2(-radius * 0.42, -radius * 0.34),
		center + Vector2(radius * 0.42, -radius * 0.34),
		center + Vector2(radius * 0.34, radius * 0.28),
		center + Vector2(0.0, radius * 0.58),
		center + Vector2(-radius * 0.34, radius * 0.28),
	])
	canvas.draw_colored_polygon(shield, Color("e4b643"))
	var shield_inner := PackedVector2Array([
		center + Vector2(-radius * 0.30, -radius * 0.22),
		center + Vector2(radius * 0.30, -radius * 0.22),
		center + Vector2(radius * 0.24, radius * 0.19),
		center + Vector2(0.0, radius * 0.43),
		center + Vector2(-radius * 0.24, radius * 0.19),
	])
	canvas.draw_colored_polygon(shield_inner, Color("315fba"))
	canvas.draw_line(
		center + Vector2(0.0, -radius * 0.17),
		center + Vector2(0.0, radius * 0.32),
		Color("ffe9a0"),
		maxf(2.0, radius * 0.075),
		true
	)

	_draw_attribute_gems(canvas, center, radius, elapsed)

func _draw_attribute_gems(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	elapsed: float
) -> void:
	var attribute_kinds := ["speed", "max_hp", "impact", "regen"]
	var orbit_angle := elapsed * GEM_ORBIT_SPEED - PI * 0.75
	for index in range(attribute_kinds.size()):
		var attribute_kind: String = attribute_kinds[index]
		var angle := orbit_angle + float(index) * PI * 0.5
		var gem_center := center + Vector2.from_angle(angle) * radius * GEM_ORBIT_RADIUS_SCALE
		var stacks := int(ability.call("stack_count", attribute_kind)) if ability != null else 0
		var color := AttributeIcon.color_for(attribute_kind)
		var active := stacks > 0
		var active_alpha := 1.0 if active else 0.72
		var icon_size := radius * (GEM_ICON_SIZE_SCALE + minf(float(stacks), 5.0) * 0.012)
		var gem_pulse := 1.0 + sin(elapsed * 4.2 + float(index)) * (0.085 if stacks > 0 else 0.018)
		var displayed_size := icon_size * gem_pulse
		canvas.draw_circle(
			gem_center,
			displayed_size * 0.88,
			Color(color.r, color.g, color.b, 0.18 if active else 0.07)
		)
		canvas.draw_circle(
			gem_center,
			displayed_size * 0.68,
			Color(0.015, 0.025, 0.055, 0.86 if active else 0.72)
		)
		canvas.draw_circle(
			gem_center,
			displayed_size * 0.68,
			Color(color.r, color.g, color.b, 0.98 if active else 0.72),
			false,
			maxf(1.15, radius * 0.043)
		)
		AttributeIcon.draw_symbol(
			canvas,
			gem_center,
			displayed_size * 1.34,
			attribute_kind,
			0.28 if active else 0.14,
			color
		)
		AttributeIcon.draw_symbol(
			canvas,
			gem_center,
			displayed_size,
			attribute_kind,
			active_alpha,
			color.lightened(0.72 if active else 0.58)
		)
		_draw_gem_level_badge(canvas, gem_center, displayed_size, stacks, color)

func _draw_gem_level_badge(
	canvas: CanvasItem,
	gem_center: Vector2,
	displayed_size: float,
	level: int,
	accent_color: Color
) -> void:
	var badge_center := gem_center + Vector2(displayed_size * 0.52, displayed_size * 0.50)
	var badge_radius := maxf(5.6, displayed_size * 0.47)
	canvas.draw_circle(badge_center, badge_radius * 1.18, Color(0.02, 0.035, 0.08, 0.82))
	canvas.draw_circle(badge_center, badge_radius, Color(0.055, 0.075, 0.15, 0.97))
	canvas.draw_circle(
		badge_center,
		badge_radius,
		Color(accent_color.r, accent_color.g, accent_color.b, 0.96),
		false,
		maxf(1.1, displayed_size * 0.09)
	)
	var level_text := str(level)
	var font_size := clampi(int(round(displayed_size * 0.82)), 10, 22)
	var text_width := badge_radius * 2.4
	var baseline := Vector2(
		badge_center.x - text_width * 0.5,
		badge_center.y + float(font_size) * 0.34
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline + Vector2(1.0, 1.0),
		level_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(0.0, 0.0, 0.0, 0.95)
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline,
		level_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(1.0, 1.0, 0.96, 1.0)
	)
