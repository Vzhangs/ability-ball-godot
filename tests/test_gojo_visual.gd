extends SceneTree

const Card := preload("res://scripts/ui/ball_picker_card.gd")
const View := preload("res://scripts/ui/battle_view.gd")
const FontProvider := preload("res://scripts/ui/cjk_font_provider.gd")
var failures: Array[String] = []
var capture_dir := ""

class Portrait extends Control:
	var visual: BallVisual
	var fighter = Card.PreviewFighter.new()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 720, 390), Color("0b111a"))
		visual.draw_ball(self, fighter, {"position": Vector2(170, 205), "radius": 100.0, "elapsed": 0.0, "scale_factor": 1.0, "shake_offset": Vector2.ZERO})
		visual.draw_ball(self, fighter, {"position": Vector2(570, 173), "radius": 20.0, "elapsed": 0.0, "scale_factor": 1.0, "shake_offset": Vector2.ZERO})
		draw_string(FontProvider.font(), Vector2(63, 350), "五条悟 · 角色细节", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("dbe4ef"))
		draw_string(FontProvider.font(), Vector2(527, 231), "实战尺寸", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aebdcc"))

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	root.size = Vector2i(720, 390)
	root.content_scale_size = root.size
	var module: BallModule = BallRegistry.get_module("gojo")
	var portrait := Portrait.new()
	portrait.visual = module.create_visual()
	portrait.fighter.color = module.color
	portrait.fighter.accent = module.accent
	root.add_child(portrait)
	var card := Card.new()
	card.position = Vector2(340, 115)
	card.configure(module, false)
	portrait.add_child(card)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		_check(shot.get_pixel(135, 222).r > 0.5, "眼罩下方露出皮肤")
		_check(shot.get_pixel(195, 247).r > 0.5, "下半张脸没有面罩或衣领遮挡")
		_check(shot.get_pixel(132, 197).r < 0.3, "黑色眼罩只覆盖眼睛位置")
		_save(shot, "portrait")
	portrait.queue_free()
	await process_frame
	var view := View.new()
	view.start_battle(917, "gojo", "test_ball", 120)
	view.paused = true
	root.add_child(view)
	root.size = Vector2i(540, 600)
	root.content_scale_size = Vector2i(view.size)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for frame in range(121):
		view.simulation.step(BattleSimulation.FIXED_STEP)
		view._sync_hud_feedback()
		if frame in [0, 30, 75, 120]:
			view.queue_redraw()
			await process_frame
			await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				_save(root.get_texture().get_image(), "battle-%03d" % frame)
	view.queue_free()
	await process_frame
	if failures.is_empty():
		print("ABILITY_BALL_GOJO_VISUAL_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _save(shot: Image, label: String) -> void:
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		_check(shot.save_png(capture_dir.path_join(label + ".png")) == OK, "截图保存")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
