extends RefCounted

const Glow := preload("res://scripts/balls/core/combat_glow.gd")
enum Style { GRADIENT, SOLID, ORBIT, METAL, CRYSTAL }
const TEXTURE_SIZE := 192
const CACHE_LIMIT := 64
static var _textures: Dictionary = {}

static func draw(canvas: CanvasItem, center: Vector2, radius: float, base: Color, accent: Color, style: Style, elapsed: float = 0.0) -> void:
	if radius <= 0.0:
		return
	Glow.halo(canvas, center, radius * 1.52, Color(accent, 0.16))
	canvas.draw_texture_rect(texture(base, accent, style), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	if style == Style.ORBIT:
		_draw_orbit(canvas, center, radius, accent, elapsed)
	elif style == Style.CRYSTAL:
		var glint := center + Vector2(-0.42, -0.48) * radius
		var strength := 0.55 + 0.20 * sin(elapsed * 2.1)
		Glow.streak(canvas, glint - Vector2(radius * 0.14, 0.0), glint + Vector2(radius * 0.14, 0.0), Color(accent.lightened(0.7), strength), maxf(0.6, radius * 0.018))
		canvas.draw_line(glint - Vector2(0.0, radius * 0.10), glint + Vector2(0.0, radius * 0.10), Color(Color.WHITE, strength), maxf(0.6, radius * 0.018), true)

static func _draw_orbit(canvas: CanvasItem, center: Vector2, radius: float, accent: Color, elapsed: float) -> void:
	var angle := elapsed * 0.48
	for index in range(3):
		var start := angle + float(index) * TAU / 3.0
		canvas.draw_arc(center, radius * 1.13, start, start + 1.38, 24, Color(accent, 0.14), maxf(3.0, radius * 0.13), true)
		canvas.draw_arc(center, radius * 1.13, start, start + 1.38, 24, Color(accent, 0.88), maxf(0.9, radius * 0.035), true)
		var node := center + Vector2.from_angle(start + 1.38) * radius * 1.13
		Glow.halo(canvas, node, radius * 0.23, Color(accent, 0.65))
		canvas.draw_circle(node, maxf(0.9, radius * 0.037), accent.lightened(0.7), true, -1.0, true)

static func texture(base: Color, accent: Color, style: Style) -> CanvasTexture:
	var key := "%s/%s/%d" % [base.to_html(), accent.to_html(), style]
	if _textures.has(key):
		return _textures[key]
	var pixels := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(TEXTURE_SIZE):
		for x in range(TEXTURE_SIZE):
			var point := (Vector2(x, y) + Vector2.ONE * 0.5) / float(TEXTURE_SIZE) * 2.0 - Vector2.ONE
			var distance := point.length()
			if distance >= 1.0:
				continue
			var color := _shade(point, distance, base, accent, style)
			color.a = smoothstep(1.0, 0.982, distance)
			pixels.set_pixel(x, y, color)
	pixels.generate_mipmaps()
	var result := CanvasTexture.new()
	result.diffuse_texture = ImageTexture.create_from_image(pixels)
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _textures.size() >= CACHE_LIMIT:
		_textures.erase(_textures.keys()[0])
	_textures[key] = result
	return result

static func _shade(point: Vector2, distance: float, base: Color, accent: Color, style: Style) -> Color:
	var depth := sqrt(maxf(0.0, 1.0 - distance * distance))
	var light := clampf(Vector3(point.x, point.y, depth).dot(Vector3(-0.43, -0.57, 0.70)), 0.0, 1.0)
	var color := base
	match style:
		Style.SOLID:
			# Keep the broad face a true solid color; bevel and gloss live at its edge.
			color = base.darkened(smoothstep(0.70, 1.0, distance) * 0.55)
		Style.ORBIT:
			color = base.darkened(0.58).lerp(base, light * 0.65)
			color = color.lerp(accent, pow(distance, 9.0) * 0.60)
		Style.METAL:
			var band := exp(-pow((point.y + point.x * 0.35 + 0.31) * 7.0, 2.0))
			color = base.darkened(0.65).lerp(base.lightened(0.12), light)
			color = color.lerp(accent.lightened(0.3), band * 0.38)
		Style.CRYSTAL:
			var sector := floorf((point.angle() + PI) / (TAU / 7.0)) * TAU / 7.0
			var facet := cos(sector - 0.8) * (0.12 if distance > 0.57 else -0.06)
			color = base.darkened(0.58).lerp(accent, clampf(light * 0.68 + facet, 0.0, 0.86))
			color = color.lerp(base.lightened(0.25), exp(-pow((point.y - point.x * 0.8 - 0.25) * 12.0, 2.0)) * 0.22)
		_:
			color = base.darkened(0.68).lerp(base, light)
			color = color.lerp(accent, pow(light, 3.0) * 0.66)
	var highlight := exp(-((point - Vector2(-0.34, -0.46)) * Vector2(5.0, 8.0)).length_squared())
	color = color.lerp(Color.WHITE, highlight * (0.38 if style == Style.SOLID else 0.65))
	var rim := smoothstep(0.90, 0.945, distance) * (1.0 - smoothstep(0.958, 0.994, distance))
	color = color.lerp(accent.lightened(0.25), rim * (0.35 + 0.5 * light))
	return color
