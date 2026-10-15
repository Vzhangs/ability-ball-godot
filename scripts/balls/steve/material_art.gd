extends RefCounted

const IDS := ["wood", "stone", "iron", "gold", "diamond", "netherite"]
const NAMES := ["木头", "石头", "铁", "金", "钻石", "下界合金"]
const COLORS := [Color("a77a47"), Color("899399"), Color("d3dfdf"), Color("f6c842"), Color("43e4d5"), Color("665867")]

static func color_for(tier: int) -> Color:
	return COLORS[clampi(tier, 0, COLORS.size() - 1)]

static func draw_block(canvas: CanvasItem, center: Vector2, half: float, tier: int, color: Color, alpha: float = 1.0) -> void:
	if half < 0.01:
		return
	var base := Color(color, alpha)
	var dark := Color(color.darkened(0.44), alpha)
	var light := Color(color.lightened(0.28), alpha)
	var bounds := Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	canvas.draw_rect(bounds.grow(half * 0.1), Color(0.035, 0.045, 0.05, alpha))
	canvas.draw_rect(bounds, base)
	canvas.draw_rect(Rect2(bounds.position, Vector2(half * 2.0, half * 0.28)), light)
	canvas.draw_rect(Rect2(center + Vector2(half * 0.74, -half * 0.72), Vector2(half * 0.26, half * 1.72)), dark)
	if tier == 0:
		for row in [-0.42, 0.20, 0.75]:
			canvas.draw_line(center + Vector2(-0.95, row) * half, center + Vector2(0.73, row) * half, dark, maxf(1.0, half * 0.12))
		canvas.draw_rect(Rect2(center + Vector2(-0.4, -0.3) * half, Vector2(0.38, 0.24) * half), light, false, maxf(1.0, half * 0.09))
	elif tier == 1:
		for index in range(5):
			var offset := Vector2(-0.78 + float(index % 3) * 0.54, -0.5 + float(index / 3) * 0.84)
			canvas.draw_rect(Rect2(center + offset * half, Vector2(0.38, 0.30) * half), dark if index % 2 == 0 else light)
	elif tier == 5:
		for row in range(3):
			canvas.draw_rect(Rect2(center + Vector2(-0.72 + float(row % 2) * 0.28, -0.54 + row * 0.49) * half, Vector2(1.06, 0.22) * half), dark)
		canvas.draw_line(center + Vector2(-0.56, -0.52) * half, center + Vector2(0.38, 0.52) * half, Color(0.76, 0.51, 0.78, alpha), maxf(1.0, half * 0.1))
	else:
		canvas.draw_rect(Rect2(center - Vector2.ONE * half * 0.61, Vector2.ONE * half * 1.2), dark, false, maxf(1.0, half * 0.10))
		canvas.draw_rect(Rect2(center + Vector2(-0.51, -0.48) * half, Vector2(0.60, 0.19) * half), Color(1.0, 1.0, 1.0, alpha * 0.76))
		if tier == 4:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -0.32) * half, center + Vector2(0.4, 0.05) * half, center + Vector2(0, 0.48) * half, center + Vector2(-0.4, 0.05) * half]), light)

static func draw_sword(canvas: CanvasItem, root: Vector2, direction: Vector2, length: float, width: float, tier: int, alpha: float = 1.0) -> void:
	if length <= 0.01 or width <= 0.01:
		return
	var normal := direction.orthogonal()
	var color := color_for(tier)
	_sword_rect(canvas, root, direction, normal, Rect2(-length * 0.2, -width * 0.28, length * 0.37, width * 0.56), Color(0.19, 0.12, 0.08, alpha))
	_sword_rect(canvas, root, direction, normal, Rect2(0, -width * 1.02, length * 0.12, width * 2.04), Color(color.darkened(0.25), alpha))
	_sword_rect(canvas, root, direction, normal, Rect2(length * 0.1, -width * 0.63, length * 0.70, width * 1.26), Color(0.06, 0.08, 0.1, alpha))
	_sword_rect(canvas, root, direction, normal, Rect2(length * 0.13, -width * 0.44, length * 0.7, width * 0.88), Color(color, alpha))
	_sword_rect(canvas, root, direction, normal, Rect2(length * 0.78, -width * 0.36, length * 0.12, width * 0.72), Color(color, alpha))
	_sword_rect(canvas, root, direction, normal, Rect2(length * 0.88, -width * 0.18, length * 0.12, width * 0.36), Color(color.lightened(0.18), alpha))
	_sword_rect(canvas, root, direction, normal, Rect2(length * 0.16, -width * 0.40, length * 0.60, width * 0.20), Color(color.lightened(0.5), alpha))

static func _sword_rect(canvas: CanvasItem, root: Vector2, direction: Vector2, normal: Vector2, bounds: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for point in [bounds.position, bounds.position + Vector2(bounds.size.x, 0), bounds.end, bounds.position + Vector2(0, bounds.size.y)]:
		points.append(root + direction * point.x + normal * point.y)
	canvas.draw_colored_polygon(points, color)

static func draw_armor(canvas: CanvasItem, center: Vector2, size: float, tier: int, alpha: float = 1.0) -> void:
	if size < 0.01:
		return
	var color := color_for(tier)
	var outline := PackedVector2Array()
	for point in [Vector2(-0.38,-0.7), Vector2(-0.9,-0.42), Vector2(-0.7,0.08), Vector2(-0.49,-0.05), Vector2(-0.49,0.7), Vector2(0.49,0.7), Vector2(0.49,-0.05), Vector2(0.7,0.08), Vector2(0.9,-0.42), Vector2(0.38,-0.7), Vector2(0.24,-0.37), Vector2(-0.24,-0.37)]:
		outline.append(center + point * size)
	canvas.draw_colored_polygon(outline, Color(color, alpha))
	outline.append(outline[0])
	canvas.draw_polyline(outline, Color(color.darkened(0.52), alpha), maxf(1.0, size * 0.12), true)
	canvas.draw_line(center + Vector2(-0.30, -0.12) * size, center + Vector2(0.30, -0.12) * size, Color(color.lightened(0.6), alpha), maxf(1.0, size * 0.12))
