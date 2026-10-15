extends RefCounted

const SPEED := "speed"
const MAX_HP := "max_hp"
const IMPACT := "impact"
const REGEN := "regen"
const KINDS := [SPEED, MAX_HP, IMPACT, REGEN]

static func color_for(attribute_kind: String) -> Color:
	match attribute_kind:
		SPEED:
			return Color("56ddff")
		MAX_HP:
			return Color("ff6278")
		IMPACT:
			return Color("ffad3d")
		REGEN:
			return Color("65f29a")
	return Color.WHITE

static func draw_symbol(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	attribute_kind: String,
	alpha: float = 1.0,
	ink_color: Color = Color(1.0, 1.0, 0.94, 1.0)
) -> void:
	var ink := Color(
		ink_color.r,
		ink_color.g,
		ink_color.b,
		clampf(alpha, 0.0, 1.0) * ink_color.a
	)
	var shadow := Color(0.02, 0.04, 0.08, ink.a * 0.52)
	match attribute_kind:
		SPEED:
			_draw_speed(canvas, center, size, ink, shadow)
		MAX_HP:
			_draw_heart(canvas, center, size, ink, shadow)
		IMPACT:
			_draw_sword(canvas, center, size * 1.22, ink, shadow)
		REGEN:
			_draw_regen(canvas, center, size, ink, shadow)

static func _draw_speed(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	ink: Color,
	shadow: Color
) -> void:
	var points := PackedVector2Array([
		center + Vector2(-size * 0.08, -size * 0.52),
		center + Vector2(size * 0.38, -size * 0.52),
		center + Vector2(size * 0.08, -size * 0.08),
		center + Vector2(size * 0.37, -size * 0.08),
		center + Vector2(-size * 0.32, size * 0.58),
		center + Vector2(-size * 0.10, size * 0.10),
		center + Vector2(-size * 0.39, size * 0.10),
	])
	canvas.draw_colored_polygon(_offset_polygon(points, Vector2(size * 0.07, size * 0.08)), shadow)
	canvas.draw_colored_polygon(points, ink)

static func _draw_heart(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	ink: Color,
	shadow: Color
) -> void:
	var shadow_offset := Vector2(size * 0.06, size * 0.07)
	var left := center + Vector2(-size * 0.22, -size * 0.13)
	var right := center + Vector2(size * 0.22, -size * 0.13)
	var lower := PackedVector2Array([
		center + Vector2(-size * 0.47, -size * 0.05),
		center + Vector2(size * 0.47, -size * 0.05),
		center + Vector2(0.0, size * 0.53),
	])
	canvas.draw_circle(left + shadow_offset, size * 0.27, shadow)
	canvas.draw_circle(right + shadow_offset, size * 0.27, shadow)
	canvas.draw_colored_polygon(_offset_polygon(lower, shadow_offset), shadow)
	canvas.draw_circle(left, size * 0.27, ink)
	canvas.draw_circle(right, size * 0.27, ink)
	canvas.draw_colored_polygon(lower, ink)

static func _draw_sword(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	ink: Color,
	shadow: Color
) -> void:
	var direction := Vector2(0.68, -0.73)
	var normal := direction.orthogonal()
	var blade_start := center - direction * size * 0.25
	var blade_tip := center + direction * size * 0.56
	var blade := PackedVector2Array([
		blade_start + normal * size * 0.11,
		blade_tip,
		blade_start - normal * size * 0.11,
	])
	var offset := Vector2(size * 0.06, size * 0.07)
	canvas.draw_colored_polygon(_offset_polygon(blade, offset), shadow)
	canvas.draw_colored_polygon(blade, ink)
	canvas.draw_line(
		center - normal * size * 0.31 + offset,
		center + normal * size * 0.31 + offset,
		shadow,
		maxf(2.0, size * 0.15),
		true
	)
	canvas.draw_line(
		center - normal * size * 0.31,
		center + normal * size * 0.31,
		ink,
		maxf(2.0, size * 0.15),
		true
	)
	canvas.draw_line(
		blade_start,
		center - direction * size * 0.52,
		ink,
		maxf(2.0, size * 0.18),
		true
	)

static func _draw_regen(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	ink: Color,
	shadow: Color
) -> void:
	var offset := Vector2(size * 0.06, size * 0.07)
	var horizontal := Rect2(
		center + Vector2(-size * 0.46, -size * 0.13),
		Vector2(size * 0.92, size * 0.26)
	)
	var vertical := Rect2(
		center + Vector2(-size * 0.13, -size * 0.46),
		Vector2(size * 0.26, size * 0.92)
	)
	canvas.draw_rect(Rect2(horizontal.position + offset, horizontal.size), shadow)
	canvas.draw_rect(Rect2(vertical.position + offset, vertical.size), shadow)
	canvas.draw_rect(horizontal, ink)
	canvas.draw_rect(vertical, ink)

static func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(point + offset)
	return result
