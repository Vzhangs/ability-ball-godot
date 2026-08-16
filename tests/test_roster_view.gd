extends SceneTree

const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const BallSettingsDialogScript := preload("res://scripts/ui/ball_settings_dialog.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const GlobalSettingsDialogScript := preload("res://scripts/ui/global_settings_dialog.gd")

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	_check_render_quality()
	_check_viewport_margin()
	_check_health_hud_policy()
	await _check_settings_dialog()
	await _check_global_settings_dialog()
	await _check_replicator_dual_ring_view()
	await _check_splitter_swarm_view()
	var ids := BallRegistry.ids()
	for index in range(0, ids.size(), 2):
		var view: BattleView = BattleViewScript.new()
		view.size = BattleViewScript.DEFAULT_VIEW_SIZE
		get_root().add_child(view)
		view.start_battle(20260815 + index, ids[index], ids[index + 1])
		view.simulation.step(BattleSimulation.FIXED_STEP)
		view.queue_redraw()
		await process_frame
		await process_frame
		_check(view.left_visual is BallVisual, "%s 视觉已装载" % ids[index])
		_check(view.right_visual is BallVisual, "%s 视觉已装载" % ids[index + 1])
		view.queue_free()
		await process_frame
	if failures.is_empty():
		print("ABILITY_BALL_ALL_VISUALS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _check_render_quality() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1080
			and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 1920,
		"Godot 母版使用原生 1080×1920 渲染目标"
	)
	_check(
		main_source.contains("content_scale_size = LOGICAL_VIEWPORT_SIZE"),
		"高清渲染保持原有 720×1280 逻辑布局并由 CanvasItems 原生栅格化"
	)
	_check(
		ProjectSettings.get_setting("rendering/renderer/rendering_method", "") == "mobile",
		"程序化 2D 图形使用支持 MSAA 的 Mobile 渲染器"
	)
	_check(
		int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) >= 2,
		"竞技场程序化图形启用至少 4x 2D MSAA"
	)

func _check_viewport_margin() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	var visible_world := view.visible_world_size()
	var arena_rect := view.arena_screen_rect()
	var horizontal_visible_ratio := visible_world.x / BattleSimulation.DEFAULT_ARENA_SIZE.x
	var vertical_visible_ratio := visible_world.y / BattleSimulation.DEFAULT_ARENA_SIZE.y
	_check(not is_equal_approx(view.size.x, view.size.y), "战斗外层画布使用非正方形布局")
	_check(is_equal_approx(visible_world.x / BattleSimulation.DEFAULT_ARENA_SIZE.x, 1.2), "游戏世界视野宽度为碰撞场地的 120%")
	_check(horizontal_visible_ratio >= 1.2 and vertical_visible_ratio >= 1.2, "矩形画布在两个方向都保留至少 120% 可视世界")
	_check(arena_rect.position.x > 0.0 and arena_rect.position.y > 0.0, "碰撞盒四周保留可视窗口留白")
	_check(arena_rect.end.x < view.size.x and arena_rect.end.y < view.size.y, "碰撞盒边界与窗口裁切边界相互独立")
	_check(is_equal_approx(arena_rect.size.x / view.size.x, 1.0 / 1.2), "碰撞盒在窗口内按 1:1.2 比例显示")
	_check(
		arena_rect.position.y - BattleViewScript.HEALTH_PANEL_BOTTOM >= BattleViewScript.HUD_ARENA_GAP,
		"顶部血条面板和竞技场内容区之间保留固定空隙"
	)
	view.start_battle(20260914, "splitter", "heaven", 85.0, Vector2(900.0, 500.0))
	visible_world = view.visible_world_size()
	arena_rect = view.arena_screen_rect()
	_check(view.simulation.arena_size() == Vector2(900.0, 500.0), "自定义竞技场尺寸进入真实战斗视图")
	_check(is_equal_approx(visible_world.x / 900.0, 1.2), "自定义竞技场保持横向 120% 可视世界")
	_check(visible_world.y / 500.0 >= 1.2, "矩形外层允许在纵向保留更多展示空间")
	_check(is_equal_approx(arena_rect.size.x / arena_rect.size.y, 900.0 / 500.0), "碰撞白框按自定义宽高比绘制")
	view.free()

func _check_health_hud_policy() -> void:
	var view_source := FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var clone_source := FileAccess.get_file_as_string("res://scripts/balls/splitter/clone_entity.gd")
	var render_source := FileAccess.get_file_as_string("res://tools/render_video.sh")
	_check(view_source.contains("simulation.left.max_hp"), "左侧顶部血条标注当前与最大血量")
	_check(view_source.contains("simulation.right.max_hp"), "右侧顶部血条标注当前与最大血量")
	_check(BattleViewScript.HEALTH_BAR_HEIGHT >= 16.0, "顶部血条具有醒目的可视高度")
	_check(BattleViewScript.HEALTH_VALUE_FONT_SIZE >= 21, "顶部血量数字具有醒目的字号")
	_check(clone_source.contains("func draw_hud("), "分身细血条通过实体自己的 HUD 钩子绘制")
	_check(not clone_source.contains("context.point(fighter.pos)"), "分身细血条不再跟随场内主球位置")
	_check(not view_source.contains("simulation.phase"), "公共 HUD 不读取全局阶段")
	_check(not view_source.contains("phase_center"), "公共 HUD 不绘制三阶段指示器")
	_check(not main_source.contains("status_label"), "战斗框下方不再重复标注双方血量")
	_check(main_source.contains("BallSettingsStoreScript.save_settings"), "球参数保存后由入口自动持久化")
	_check(main_source.contains("GlobalSettingsStoreScript.save_settings"), "全局设置保存后由入口自动持久化")
	_check(not main_source.contains("time_limit_spin_box"), "对局时限只有全局设置一个界面事实源")
	_check(main_source.contains("OS.create_process"), "局内录制使用独立后台进程，不阻塞当前对局")
	_check(main_source.contains("if not recording_mode:"), "录制呈现模式不创建下方操作区")
	_check(render_source.contains("--resolution 1080x1920"), "录制进程显式请求 1080×1920 原生母版")
	_check(render_source.contains("crop=1080:1200:0:0"), "视频从原生母版裁取 1080×1200 标题与完整战斗视图")
	_check(not render_source.contains("scale=1080:1200"), "录制链路不再把低分辨率画面放大成 1080×1200")
	_check(render_source.contains('--fixed-fps "$recording_fps"'), "视频生成脚本使用用户选择的录制帧率")
	_check(render_source.contains("cover_frame=$(( recording_fps * 6 ))"), "自动封面固定取对局第 6 秒画面")
	_check(render_source.contains("colorkey=0x030405"), "封面标题抠除背景后作为透明前景覆盖内容区")
	_check(render_source.contains("overlay=0:${cover_title_y}"), "封面对决标题叠放在竞技场内容区中央")
	_check(render_source.contains("overlay=enable='eq(n,0)'"), "自动封面只替换最终视频第 1 帧")

func _check_settings_dialog() -> void:
	var dialog = BallSettingsDialogScript.new()
	get_root().add_child(dialog)
	dialog.open_settings(BallRegistry.settings_snapshot(), "splitter")
	await process_frame
	_check(dialog.visible, "球参数弹窗可以正常打开")
	var controls := dialog.find_children("*", "SpinBox", true, false)
	_check(
		controls.size() == BallRegistry.get_module("splitter").setting_specs().size(),
		"弹窗按分身球 Schema 自动生成全部数值输入框"
	)
	dialog.hide()
	dialog.queue_free()
	await process_frame

func _check_global_settings_dialog() -> void:
	var dialog = GlobalSettingsDialogScript.new()
	get_root().add_child(dialog)
	dialog.open_settings({
		"battle_time_seconds": 90,
		"arena_width": 900,
		"arena_height": 500,
		"recording_fps": 60,
	})
	await process_frame
	_check(dialog.visible, "全局设置弹窗可以正常打开")
	var controls := dialog.find_children("*", "SpinBox", true, false)
	_check(controls.size() == GlobalGameSettingsScript.SETTING_SPECS.size(), "全局设置弹窗按 Schema 生成全部输入框")
	dialog.hide()
	dialog.queue_free()
	await process_frame

func _check_replicator_dual_ring_view() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20260906, "replicator", "laser")
	for _activation in range(22):
		view.simulation.left_ability.activate(
			view.simulation.battle_context,
			view.simulation.left,
			view.simulation.right,
			0
		)
	view.queue_redraw()
	await process_frame
	await process_frame
	var cannons: Array[BallEntity] = view.simulation.entity_list(0, "clone")
	_check(cannons.size() == 22, "22 门双环浮游炮的真实实体绘制路径可执行")
	var inner_count := 0
	var outer_count := 0
	for cannon: BallEntity in cannons:
		if int(cannon.call("formation_ring")) == 0:
			inner_count += 1
		else:
			outer_count += 1
	_check(inner_count == 8 and outer_count == 14, "浮游炮实际画面保持 8+14 双层圆环")
	view.queue_free()
	await process_frame

func _check_splitter_swarm_view() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20260831, "splitter", "laser")
	for _activation in range(40):
		view.simulation.left_ability.activate(
			view.simulation.battle_context,
			view.simulation.left,
			view.simulation.right,
			0
		)
	view.simulation.left_ability.after_entities_step(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		0.0
	)
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(view.simulation.count_entities(0, "splitter_clone") == 100, "百球分身与 100 条细血条的真实绘制路径可执行")
	var clones: Array[BallEntity] = view.simulation.entity_list(0, "splitter_clone")
	var main_health_bounds := view.health_hud_bounds(0)
	var arena_bounds := view.arena_screen_rect()
	if clones.size() == 100:
		var first_bounds: Rect2 = clones[0].call("mini_health_bar_bounds", main_health_bounds)
		var second_bounds: Rect2 = clones[1].call("mini_health_bar_bounds", main_health_bounds)
		var last_bounds: Rect2 = clones[99].call("mini_health_bar_bounds", main_health_bounds)
		_check(first_bounds.position.y > main_health_bounds.end.y, "分身细血条固定显示在主球顶部大血条下方")
		_check(first_bounds.end.x <= arena_bounds.position.x, "左侧单列细血条位于碰撞区外的展示留白")
		_check(second_bounds.position.y > first_bounds.position.y, "每行固定排列一个分身细血条")
		_check(is_equal_approx(second_bounds.position.x, first_bounds.position.x), "分身细血条保持单列纵向对齐")
		_check(last_bounds.end.y < arena_bounds.end.y, "100 条分身细血条不会超出侧边展示空间")
		var fixed_bounds := first_bounds
		clones[0].pos = Vector2(600.0, 600.0)
		view.simulation.left.pos = Vector2(520.0, 100.0)
		_check(clones[0].call("mini_health_bar_bounds", main_health_bounds) == fixed_bounds, "分身细血条位置不跟随主球或分身移动")
	view.queue_free()
	await process_frame

	var right_view: BattleView = BattleViewScript.new()
	right_view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(right_view)
	right_view.start_battle(20260901, "laser", "splitter")
	for _activation in range(2):
		right_view.simulation.right_ability.activate(
			right_view.simulation.battle_context,
			right_view.simulation.right,
			right_view.simulation.left,
			1
		)
	right_view.simulation.right_ability.after_entities_step(
		right_view.simulation.battle_context,
		right_view.simulation.right,
		right_view.simulation.left,
		1,
		0.0
	)
	right_view.queue_redraw()
	await process_frame
	await process_frame
	var right_clones: Array[BallEntity] = right_view.simulation.entity_list(1, "splitter_clone")
	if right_clones.size() >= 3:
		var right_main_bounds := right_view.health_hud_bounds(1)
		var right_third_bounds: Rect2 = right_clones[2].call("mini_health_bar_bounds", right_main_bounds)
		_check(right_third_bounds.position.x >= right_view.arena_screen_rect().end.x, "右侧单列细血条镜像排列在碰撞区外的展示留白")
	else:
		_check(false, "右侧分身球能够生成用于 HUD 镜像检查的分身")
	right_view.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
