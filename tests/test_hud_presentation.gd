extends SceneTree

const Hud := preload("res://scripts/ui/hud_presentation.gd")
const View := preload("res://scripts/ui/battle_view.gd")
var failures: Array[String] = []
var capture_dir := ""

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	_check_feedback()
	var view := View.new()
	view.start_battle(732, "flame", "frost", 120.0)
	view.paused = true
	root.add_child(view)
	root.size = Vector2i(1080, 1200)
	root.content_scale_size = Vector2i(view.size)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await _capture(view, "duel-full")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).hp = 18
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).hp = 58
	view._sync_hud_feedback()
	for age in [0.0, 0.08, 0.20, 0.40, 0.80]:
		view.simulation.elapsed = age
		await _capture(view, "damage-%03d" % int(age * 1000))
	view.simulation.elapsed = 0.24
	await _capture(view, "damage-trail")
	_check(view._hud_glass_layer.panes.size() == 2, "单挑只复用两块血条玻璃")
	var frozen: Dictionary = view._hud_feedback(view.simulation.fighter_for_side(view.simulation.teams[0].team_id))
	view._process(0.4)
	_check(view._hud_feedback(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)) == frozen, "暂停冻结血条动画")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).hp = 68
	view._sync_hud_feedback()
	await _capture(view, "healing")
	view.simulation.elapsed = 111.0
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).hp = 12
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).hp = 140
	view._sync_hud_feedback()
	view.simulation.elapsed += 1.0
	await _capture(view, "critical-overheal")
	root.size = Vector2i(540, 600)
	await _capture(view, "critical-540")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).display_name = "超长名称的能力球测试"
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).max_hp = 10000
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).hp = 10000
	view._sync_hud_feedback()
	await _capture(view, "wide-values-540")
	view.start_battle(733, "flame", "frost", 120.0)
	for pane in view._hud_glass_layer.panes:
		_check(not pane.visible, "重开隐藏上一局玻璃区域")
	_check(view._hud_presentation.health_states.size() == 2, "重开清除旧血条状态")
	_check(float(view._hud_feedback(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).damage) == 0.0, "新局不继承受伤闪光")
	view.queue_free()
	await process_frame
	if failures.is_empty():
		print("ABILITY_BALL_HUD_PRESENTATION_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_feedback() -> void:
	var hud := Hud.new()
	hud.observe(1, 100, 100, 0.0)
	hud.observe(2, 100, 100, 0.0)
	hud.observe(1, 40, 100, 1.0)
	_check(float(hud.feedback(1, 1.1).fill) < 1.0 and float(hud.feedback(1, 1.1).fill) > 0.4, "真实血量填充具有短促平滑过渡")
	_check(float(hud.feedback(1, 1.21).fill) == 0.4, "填充及时收敛到真实血量")
	_check(is_equal_approx(float(hud.feedback(1, 1.1).lost), 0.6), "受伤粒子强度来自本次可见损失")
	_check(is_equal_approx(float(hud.feedback(1, 1.1).trail), 1.0), "伤害残影短暂停留在原血量")
	var mid := float(hud.feedback(1, 1.4).trail)
	_check(mid > 0.4 and mid < 1.0, "伤害残影平滑收缩")
	hud.observe(1, 20, 100, 1.4)
	_check(float(hud.feedback(1, 1.4).trail) >= mid, "连续伤害延续当前残影")
	_check(is_equal_approx(float(hud.feedback(1, 2.4).trail), 0.2), "伤害残影最终收敛")
	_check(float(hud.feedback(2, 1.4).damage) == 0.0, "不同战斗单位独立反馈")
	hud.observe(1, 70, 100, 2.5)
	_check(float(hud.feedback(1, 2.5).heal) == 1.0 and is_equal_approx(float(hud.feedback(1, 2.5).trail), 0.7), "回血立即填充并亮起治疗反馈")
	_check(float(hud.feedback(1, 3.2).heal) == 0.0, "回血闪光自动结束")
	hud.observe(1, 140, 100, 3.3)
	_check(float(hud.feedback(1, 3.3).trail) == 1.0, "超额生命不越过血条边界")
	hud.observe(1, 140, 200, 3.4)
	_check(float(hud.feedback(1, 3.4).damage) == 0.0, "生命上限变化不伪装成受伤")
	hud.observe(1, 0, 200, 4.0)
	_check(float(hud.feedback(1, 5.0).trail) == 0.0, "阵亡后血条完全清空")
	hud.reset()
	_check(hud.health_states.is_empty(), "状态可完整清理")

func _capture(view: Control, label: String) -> void:
	view.queue_redraw()
	await process_frame
	await process_frame
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var screenshot := root.get_texture().get_image()
	_check(screenshot.save_png(capture_dir.path_join(label + ".png")) == OK, "HUD 截图保存")
	var strip := screenshot.get_region(Rect2i(0, 0, screenshot.get_width(), int(screenshot.get_width() * 0.13)))
	_check(strip.save_png(capture_dir.path_join(label + "-hud.png")) == OK, "HUD 细节截图保存")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
