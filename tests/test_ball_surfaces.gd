extends SceneTree

const Surface := preload("res://scripts/balls/core/ball_surface.gd")
const Card := preload("res://scripts/ui/ball_picker_card.gd")
const FontProvider := preload("res://scripts/ui/cjk_font_provider.gd")
var failures: Array[String] = []

class Gallery extends Control:
	var elapsed := 0.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("080f1d"))
		draw_string(FontProvider.font(), Vector2(36, 54), "能力球 · 材质图鉴", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("eaf4ff"))
		draw_string(FontProvider.font(), Vector2(36, 84), "渐变光泽 / 纯色珐琅 / 能量外环 / 拉丝金属 / 折光晶体", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("7f9cb8"))
		var labels := ["渐变", "纯色", "外圈", "金属", "晶体"]
		for index in range(5):
			var center := Vector2(116 + index * 210, 180)
			Surface.draw(self, center, 55.0, Color("286ccb"), Color("74efff"), index, elapsed)
			draw_string(FontProvider.font(), center + Vector2(-55, 90), labels[index], HORIZONTAL_ALIGNMENT_CENTER, 110, 18, Color("c9dfef"))

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	_check_materials()
	var capture_dir := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	root.size = Vector2i(1080, 1200)
	root.content_scale_size = root.size
	var gallery := Gallery.new()
	gallery.size = Vector2(1080, 1200)
	root.add_child(gallery)
	var cards: Array[Control] = []
	var modules := BallRegistry.modules()
	for index in range(modules.size()):
		var card := Card.new()
		card.position = Vector2(43 + (index % 6) * 172, 304 + (index / 6) * 176)
		card.configure(modules[index], false)
		gallery.add_child(card)
		card.set_process(false)
		cards.append(card)
	var cache_count := 0
	for age in [0.0, 0.7, 2.4, 5.2]:
		gallery.elapsed = age
		gallery.queue_redraw()
		for card in cards:
			card._elapsed = age
			card._fighter.rotation = age * 0.72
			card.queue_redraw()
		await process_frame
		await process_frame
		if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(capture_dir)
			_check(root.get_texture().get_image().save_png(capture_dir.path_join("gallery-%03d.png" % int(age * 100))) == OK, "图鉴截图保存")
		if age == 0.0:
			cache_count = Surface._textures.size()
		else:
			_check(Surface._textures.size() == cache_count, "动画不产生新的材质贴图")
	_check(cards.size() == BallRegistry.ids().size(), "全名册使用真实选球卡片绘制")
	gallery.queue_free()
	await process_frame
	if failures.is_empty():
		print("ABILITY_BALL_SURFACES_OK balls=%d cached_textures=%d" % [modules.size(), cache_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_materials() -> void:
	var base := Color("286ccb")
	var accent := Color("74efff")
	var images: Array[Image] = []
	for style in range(5):
		var texture := Surface.texture(base, accent, style)
		_check(texture == Surface.texture(base, accent, style), "材质纹理复用")
		var image := texture.diffuse_texture.get_image()
		images.append(image)
		_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(96, 96).a == 1.0, "球面圆形透明边界")
		_check(image.has_mipmaps(), "缩小显示使用 mipmaps")
		_check(texture.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "球面过滤独立于场景像素纹理")
	for left in range(images.size()):
		for right in range(left + 1, images.size()):
			_check(images[left].get_data() != images[right].get_data(), "各类材质具有独立的视觉表现")
	_check(images[Surface.Style.SOLID].get_pixel(112, 110).is_equal_approx(base), "纯色球保留均匀实色主体")
	for index in range(Surface.CACHE_LIMIT + 4):
		Surface.texture(Color.from_hsv(float(index) / 70.0, 0.7, 0.8), accent, Surface.Style.SOLID)
	_check(Surface._textures.size() <= Surface.CACHE_LIMIT, "材质缓存有上限")
	Surface._textures.clear()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
