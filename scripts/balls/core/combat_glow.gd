extends RefCounted

## Shared, cached light falloff. Drawing never advances simulation or random state.
static var _texture: GradientTexture2D

static func texture() -> GradientTexture2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.32, 0.6, 1.0])
		gradient.colors = PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.86), Color(1, 1, 1, 0.43),
			Color(1, 1, 1, 0.10), Color(1, 1, 1, 0),
		])
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.width = 256
		_texture.height = 256
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
	return _texture

static func halo(canvas: CanvasItem, center: Vector2, radius: float, color: Color, aspect := Vector2.ONE) -> void:
	if radius <= 0.01 or color.a <= 0.001:
		return
	var extent := aspect * radius
	canvas.draw_texture_rect(texture(), Rect2(center - extent, extent * 2.0), false, color)

static func streak(canvas: CanvasItem, start: Vector2, finish: Vector2, color: Color, width: float) -> void:
	if start.distance_squared_to(finish) < 0.001 or width <= 0.01:
		return
	canvas.draw_line(start, finish, Color(color, color.a * 0.10), width * 4.0, true)
	canvas.draw_line(start, finish, Color(color, color.a * 0.30), width * 1.9, true)
	canvas.draw_line(start, finish, color, width, true)
	canvas.draw_line(start, finish, Color(color.lerp(Color.WHITE, 0.75), color.a * 0.86), maxf(0.65, width * 0.3), true)
