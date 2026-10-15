extends BallVisual

const OUTLINE := Color("18232c")
const ARMOR_SHADOW := Color("52616b")
const ARMOR_LIGHT := Color("e6e7dc")
const ARMOR_EDGE := Color("aebcbd")
const PANEL_DARK := Color("173f57")
const PANEL_GLASS := Color("579bad")
const MUZZLE_FORWARD := 1.28

func trail_alpha() -> float:
	return 0.12

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var center: Vector2 = context.position
	var size: float = context.radius
	canvas.draw_circle(center + Vector2(0.0, size * 0.20), size * 1.10, Color(0.0, 0.0, 0.0, 0.32))

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var center: Vector2 = context.position
	var size: float = context.radius
	var direction := Vector2.RIGHT
	var charge := 0.0
	var flash := 0.0
	if ability != null:
		direction = ability.call("aim_direction")
		charge = float(ability.call("charge_progress"))
		flash = float(ability.call("flash_ratio"))
	var normal := direction.orthogonal()
	Surface.draw(canvas, center, size, fighter.color, ARMOR_LIGHT, Surface.Style.METAL, context["elapsed"])
	canvas.draw_arc(center, size * 0.94, PI * 1.08, PI * 1.79, 24, ARMOR_LIGHT, size * 0.075, true)
	canvas.draw_circle(center, size * 0.97, ARMOR_EDGE, false, maxf(1.2, size * 0.045), true)
	_draw_recessed_armor(canvas, center, direction, normal, size)
	for side_sign in [-1.0, 1.0]:
		var armor := _points(center, direction, normal, size, [
			Vector2(-0.55, side_sign * 0.38), Vector2(0.18, side_sign * 0.43),
			Vector2(0.32, side_sign * 0.65), Vector2(-0.40, side_sign * 0.71),
		])
		_plate(canvas, armor, ARMOR_LIGHT, size)
		canvas.draw_line(_point(center, direction, normal, size, -0.34, side_sign * 0.56),
			_point(center, direction, normal, size, 0.11, side_sign * 0.56), PANEL_DARK, size * 0.12, true)
		canvas.draw_line(_point(center, direction, normal, size, -0.30, side_sign * 0.56),
			_point(center, direction, normal, size, 0.08, side_sign * 0.56), PANEL_GLASS, maxf(1.0, size * 0.045), true)
	# Keep a round hull and readable health beneath the upright panel bank.
	canvas.draw_circle(center - direction * size * 0.20, size * 0.34, ARMOR_SHADOW)
	canvas.draw_arc(center - direction * size * 0.20, size * 0.34, 0.2, PI * 1.20, 18, ARMOR_LIGHT, size * 0.045, true)
	_draw_projector(canvas, center, direction, normal, size, charge, flash)

func _draw_recessed_armor(canvas: CanvasItem, center: Vector2, direction: Vector2, normal: Vector2, size: float) -> void:
	for side_sign in [-1.0, 1.0]:
		var inset := _points(center, direction, normal, size, [
			Vector2(-0.60, side_sign * 0.43), Vector2(0.40, side_sign * 0.53),
			Vector2(0.44, side_sign * 0.76), Vector2(0.0, side_sign * 0.90),
			Vector2(-0.46, side_sign * 0.77),
		])
		_plate(canvas, inset, ARMOR_SHADOW, size)
		canvas.draw_line(_point(center, direction, normal, size, -0.40, side_sign * 0.70),
			_point(center, direction, normal, size, 0.23, side_sign * 0.75), ARMOR_EDGE, maxf(1.2, size * 0.055), true)

func _draw_projector(canvas: CanvasItem, center: Vector2, direction: Vector2, normal: Vector2, size: float, charge: float, flash: float) -> void:
	var energy := maxf(charge, flash)
	var spread := 0.10 * charge
	var base := center + direction * size * 0.40
	canvas.draw_circle(base, size * 0.38, OUTLINE)
	canvas.draw_circle(base, size * 0.28, ARMOR_EDGE)
	canvas.draw_circle(base, size * 0.18, ARMOR_SHADOW)
	for side_sign in [-1.0, 1.0]:
		var y: float = side_sign * (0.66 + spread)
		var wing := _points(center, direction, normal, size, [
			Vector2(0.12, y * 0.65), Vector2(0.16, y * 1.29),
			Vector2(0.51, y * 1.41), Vector2(1.01, y * 1.10),
			Vector2(0.89, y * 0.68), Vector2(0.46, y * 0.83),
		])
		_plate(canvas, wing, ARMOR_LIGHT, size)
		var mirror := _points(center, direction, normal, size, [
			Vector2(0.28, y * 0.94), Vector2(0.30, y * 1.17),
			Vector2(0.53, y * 1.21), Vector2(0.86, y * 1.01), Vector2(0.79, y * 0.87),
		])
		canvas.draw_colored_polygon(mirror, PANEL_GLASS.lerp(Color("fff3bf"), energy * 0.85))
		canvas.draw_line(_point(center, direction, normal, size, 0.21, side_sign * 0.20),
			_point(center, direction, normal, size, 0.60, y), ARMOR_SHADOW, size * 0.14, true)
		canvas.draw_circle(_point(center, direction, normal, size, 0.37, y * 0.73), size * 0.11, OUTLINE)
		canvas.draw_circle(_point(center, direction, normal, size, 0.37, y * 0.73), size * 0.064, ARMOR_LIGHT)
	# A broad armored emitter with stacked apertures replaces the pointed crystal.
	var head := _points(center, direction, normal, size, [
		Vector2(0.77, -0.61), Vector2(1.13, -0.67), Vector2(1.30, -0.51),
		Vector2(1.30, 0.51), Vector2(1.13, 0.67), Vector2(0.77, 0.61),
	])
	_plate(canvas, head, ARMOR_EDGE, size)
	canvas.draw_line(_point(center, direction, normal, size, 0.88, -0.56),
		_point(center, direction, normal, size, 0.88, 0.56), ARMOR_LIGHT, size * 0.11, true)
	for index in range(4):
		var y := -0.45 + float(index) * 0.30
		var pane := _points(center, direction, normal, size, [
			Vector2(1.00, y - 0.11), Vector2(1.24, y - 0.11),
			Vector2(1.24, y + 0.11), Vector2(1.00, y + 0.11),
		])
		canvas.draw_colored_polygon(pane, PANEL_DARK)
		canvas.draw_line(_point(center, direction, normal, size, 1.12, y - 0.075),
			_point(center, direction, normal, size, 1.12, y + 0.075), PANEL_GLASS.lerp(Color("fffad9"), energy), maxf(1.2, size * 0.09), true)
	if energy > 0.001:
		var muzzle := center + direction * size * MUZZLE_FORWARD
		canvas.draw_circle(muzzle, size * (0.11 + energy * 0.24), Color(1.0, 0.90, 0.60, energy * 0.18))
		canvas.draw_circle(muzzle, size * 0.085, Color(1.0, 1.0, 0.93, energy))

func _point(center: Vector2, direction: Vector2, normal: Vector2, size: float, x: float, y: float) -> Vector2:
	return center + (direction * x + normal * y) * size

func _points(center: Vector2, direction: Vector2, normal: Vector2, size: float, local_points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in local_points:
		result.append(center + (direction * point.x + normal * point.y) * size)
	return result

func _plate(canvas: CanvasItem, points: PackedVector2Array, color: Color, size: float) -> void:
	canvas.draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, OUTLINE, maxf(1.2, size * 0.055), true)
