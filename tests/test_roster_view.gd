extends SceneTree

const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const BallSettingsDialogScript := preload("res://scripts/ui/ball_settings_dialog.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const GlobalSettingsDialogScript := preload("res://scripts/ui/global_settings_dialog.gd")
const InvulnerabilityStatusEffectScript := preload("res://scripts/balls/core/invulnerability_status_effect.gd")
const BurnStatusEffectScript := preload("res://scripts/balls/core/burn_status_effect.gd")
const PlantIceSlowEffectScript := preload("res://scripts/balls/plant/ice_slow_effect.gd")

var failures: Array[String] = []

class TestControllableVisualEntity extends BallEntity:
	var _color := Color("43e0b4")

	func _init(spawn_owner: int, spawn_position: Vector2) -> void:
		owner_side = spawn_owner
		pos = spawn_position
		radius = 8.0
		tags = PackedStringArray(["yuri_visual_fixture"])

	func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
		canvas.draw_circle(screen_position(context), radius * context.scale_factor, absorption_visual_color())

	func is_absorbable() -> bool:
		return true

	func absorption_visual_color() -> Color:
		return ownership_visual_color(_color)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	_check_render_quality()
	_check_viewport_margin()
	_check_health_hud_policy()
	await _check_fighter_death_result_sequence()
	await _check_vampire_view()
	_check_sonic_visual_policy()
	await _check_wind_swordsman_view()
	await _check_yuri_view()
	await _check_plant_view()
	await _check_wdc_view()
	await _check_spider_web_view()
	await _check_sniper_view()
	await _check_heavy_industry_view()
	await _check_garen_view()
	await _check_chess_view()
	await _check_settings_dialog()
	await _check_global_settings_dialog()
	await _check_replicator_dual_ring_view()
	await _check_splitter_swarm_view()
	var ids := BallRegistry.ids()
	for index in range(ids.size()):
		var view: BattleView = BattleViewScript.new()
		view.size = BattleViewScript.DEFAULT_VIEW_SIZE
		get_root().add_child(view)
		view.start_battle(20260815 + index, ids[index], ids[(index + 1) % ids.size()])
		view.simulation.step(BattleSimulation.FIXED_STEP)
		view.queue_redraw()
		await process_frame
		await process_frame
		_check(view.left_visual is BallVisual, "%s 视觉已装载" % ids[index])
		_check(view.right_visual is BallVisual, "%s 视觉已装载" % ids[(index + 1) % ids.size()])
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
	_check(BattleViewScript.BALL_HEALTH_FONT_SCALE >= 0.75, "球内血量字号随球半径放大到醒目比例")
	_check(BattleViewScript.BALL_HEALTH_FONT_MIN_SIZE >= 15, "球内血量在默认画面下保持足够大的最小字号")
	_check(BattleViewScript.BALL_HEALTH_OUTLINE_WIDTH >= 1.5, "球内血量具有清晰的深色描边宽度")
	_check(
		BattleViewScript.BALL_HEALTH_TEXT_ALPHA < 0.85
			and BattleViewScript.BALL_HEALTH_TEXT_ALPHA >= 0.6,
		"球内血量文字保持清晰的同时允许球体特色透出"
	)
	_check(
		BattleViewScript.BALL_HEALTH_OUTLINE_ALPHA < BattleViewScript.BALL_HEALTH_TEXT_ALPHA,
		"球内血量描边比文字更透明，避免形成遮挡球体的黑块"
	)
	_check(view_source.contains("for outline_direction in ["), "球内血量使用完整八方向描边而非单侧阴影")
	_check(clone_source.contains("func draw_hud("), "分身细血条通过实体自己的 HUD 钩子绘制")
	_check(not clone_source.contains("context.point(fighter.pos)"), "分身细血条不再跟随场内主球位置")
	_check(not view_source.contains("simulation.phase"), "公共 HUD 不读取全局阶段")
	_check(not view_source.contains("phase_center"), "公共 HUD 不绘制三阶段指示器")
	_check(view_source.contains("if fighter.hp <= 0.0:"), "败方本体、拖尾和球种底图在死亡演出期间隐藏")
	_check(view_source.contains("if result_reveal_ready():"), "获胜弹窗由死亡演出完成状态统一控制")
	_check(not main_source.contains("status_label"), "战斗框下方不再重复标注双方血量")
	_check(main_source.contains("BallSettingsStoreScript.save_settings"), "球参数保存后由入口自动持久化")
	_check(main_source.contains("GlobalSettingsStoreScript.save_settings"), "全局设置保存后由入口自动持久化")
	_check(not main_source.contains("time_limit_spin_box"), "对局时限只有全局设置一个界面事实源")
	_check(main_source.contains("OS.create_process"), "局内录制使用独立后台进程，不阻塞当前对局")
	_check(main_source.contains("if not recording_mode:"), "录制呈现模式不创建下方操作区")
	_check(render_source.contains("--resolution 1080x1920"), "录制进程显式请求 1080×1920 原生母版")
	_check(render_source.contains("crop=1080:1200:0:0"), "视频从原生母版裁取 1080×1200 标题与完整战斗视图")
	_check(render_source.contains("pad=1080:1920:0:360:color=black"), "录制内容在 1080×1920 竖屏画布中上下等量补黑居中")
	_check(not render_source.contains("scale=1080:1200"), "录制链路不再把低分辨率画面放大成 1080×1200")
	_check(render_source.contains('--fixed-fps "$recording_fps"'), "视频生成脚本使用用户选择的录制帧率")
	_check(render_source.contains("cover_frame=$(( recording_fps * 6 ))"), "自动封面固定取对局第 6 秒画面")
	_check(render_source.contains("colorkey=0x030405"), "封面标题抠除背景后作为透明前景覆盖内容区")
	_check(render_source.contains("overlay=0:${cover_title_y}"), "封面对决标题叠放在竞技场内容区中央")
	_check(render_source.contains("overlay=enable='eq(n,0)'"), "自动封面只替换最终视频第 1 帧")

func _check_fighter_death_result_sequence() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	view.result_reveal_delay_seconds = 0.6
	get_root().add_child(view)
	view.start_battle(20261211, "vampire", "wdc")
	view.simulation.right.hp = 5.0
	view.simulation.damage(view.simulation.right, 10.0, view.simulation.left.accent, view.simulation.left)
	view.simulation.call("_check_finish")
	_check(view.simulation.finished, "致死后模拟器立即确定胜者")
	_check(not view.result_reveal_ready(), "确定胜者后不会立刻显示获胜弹窗")
	_check(view.simulation.count_entities(1, "fighter_death_vfx") == 1, "揭晓前保持败方死亡演出实体")
	for _frame in range(5):
		view._process(0.1)
	_check(not view.result_reveal_ready() and not view._finish_emitted, "死亡演出尚未结束时不发出对局完成信号")
	for _frame in range(2):
		view._process(0.1)
	_check(view.result_reveal_ready() and view._finish_emitted, "死亡演出结束后才揭晓获胜者并发出完成信号")
	_check(view.simulation.count_entities(1, "fighter_death_vfx") == 0, "获胜弹窗出现时死亡碎片已完整消散")
	view.queue_free()
	await process_frame

func _check_wdc_view() -> void:
	BallRegistry.configure_settings({
		"wdc": {
			"skill_duration": 1.0,
			"grid_fade_duration": 0.3,
			"cast_icon_duration": 0.72,
		}
	})
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20261207, "wdc", "laser")
	view.simulation.left_ability.activate(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0
	)
	var grids: Array[BallEntity] = view.simulation.entity_list(0, "wdc_grid")
	var icons: Array[BallEntity] = view.simulation.entity_list(0, "wdc_cast_icon_vfx")
	_check(grids.size() == 1 and icons.size() == 1, "WDC 实际视图包含地图九宫格与顶层施法图标")
	if not grids.is_empty():
		var grid: BallEntity = grids[0]
		grid.process_step(view.simulation.battle_context, 0.12)
		var fade_in_alpha := float(grid.call("animation_alpha"))
		grid.process_lifetime(0.2)
		grid.process_step(view.simulation.battle_context, 0.2)
		var peak_alpha := float(grid.call("animation_alpha"))
		_check(peak_alpha > fade_in_alpha, "WDC 九宫格从淡入帧过渡到清晰峰值帧")
	if not icons.is_empty():
		var icon: BallEntity = icons[0]
		var initial_scale := float(icon.call("animation_scale"))
		icon.process_lifetime(0.36)
		var peak_scale := float(icon.call("animation_scale"))
		_check(peak_scale > initial_scale, "WDC 顶层九宫格图标按小到大节奏发动")
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(view.left_visual is BallVisual, "WDC 球体、地图和格内数字真实绘制路径可执行")
	view.queue_free()
	await process_frame
	BallRegistry.configure_settings({})

func _check_spider_web_view() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20261215, "spider_web", "laser")
	var fighter = view.simulation.left
	var arena_size := view.simulation.arena_size()
	for wall_fixture in [
		{"position": Vector2(fighter.radius - 2.0, 170.0), "velocity": Vector2(-180.0, 40.0)},
		{"position": Vector2(320.0, fighter.radius - 2.0), "velocity": Vector2(60.0, -180.0)},
		{"position": Vector2(arena_size.x - fighter.radius + 2.0, 470.0), "velocity": Vector2(180.0, -30.0)},
	]:
		fighter.pos = wall_fixture["position"]
		fighter.velocity = wall_fixture["velocity"]
		view.simulation._resolve_wall(fighter)
	fighter.pos = Vector2(355.0, 330.0)
	var lines: Array[BallEntity] = view.simulation.entity_list(0, "spider_web_line")
	_check(lines.size() == 3, "蜘蛛网真实视图绘制三根独立墙锚蛛丝")
	if not lines.is_empty():
		var line: BallEntity = lines[0]
		view.simulation.right.pos = Vector2(180.0, 250.0)
		line.process_step(view.simulation.battle_context, BattleSimulation.FIXED_STEP)
		var initial_flash := float(line.call("trigger_flash"))
		var initial_age := float(line.call("visual_age"))
		line.process_step(view.simulation.battle_context, 0.14)
		_check(float(line.call("visual_age")) > initial_age, "永久蛛丝亮度脉冲拥有连续动画时间")
		_check(float(line.call("trigger_flash")) < initial_flash, "蛛丝触发光环会随时间衰减而非静止覆盖")
		_check(not line.draws_above_balls(), "蛛丝绘制在球体下方并自然连接到本体内部")
		_check(line.disable_for_capture(), "蛛丝真实绘制实体可进入通用黑洞捕获状态")
		line.process_step(view.simulation.battle_context, 0.17)
		_check(
			float(line.call("capture_fold_progress")) > 0.45,
			"捕获后的整根蛛丝连续折叠为可沿轨道吞噬的短束"
		)
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(view.left_visual is BallVisual, "蜘蛛网本体蛛网、墙锚、永久蛛丝和触发光环真实绘制路径可执行")
	view.queue_free()
	await process_frame

func _check_sniper_view() -> void:
	var sniper_visual_source := FileAccess.get_file_as_string("res://scripts/balls/sniper/visual.gd")
	_check(not sniper_visual_source.contains("bipod"), "狙击枪外观彻底移除两脚架")
	_check(
		not sniper_visual_source.contains("magazine")
			and not sniper_visual_source.contains("grip")
			and not sniper_visual_source.contains("bolt_"),
		"狙击枪剪影移除弹匣、握把扳机和枪机等写实小零件"
	)
	_check(sniper_visual_source.contains("muzzle_distance_multiplier - MUZZLE_LOCAL_FORWARD"), "枪托尾端按枪口配置外移到球心附近")
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20261220, "sniper", "laser")
	view.simulation.left.pos = Vector2(150.0, 320.0)
	view.simulation.right.pos = Vector2(500.0, 320.0)
	view.simulation.left.velocity = Vector2.ZERO
	view.simulation.right.velocity = Vector2.ZERO
	view.simulation.left_ability.activate(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0
	)
	var indicators: Array[BallEntity] = view.simulation.entity_list(0, "sniper_aim_vfx")
	_check(indicators.size() == 1, "狙击球真实视图生成一条虚线和一个敌球缩圈瞄准标志")
	if not indicators.is_empty():
		var indicator: BallEntity = indicators[0]
		var initial_progress := float(indicator.call("animation_progress"))
		var initial_radius := float(indicator.call("reticle_radius", view.simulation.right.radius))
		indicator.process_step(view.simulation.battle_context, 0.5)
		var middle_progress := float(indicator.call("animation_progress"))
		var middle_radius := float(indicator.call("reticle_radius", view.simulation.right.radius))
		_check(middle_progress > initial_progress and middle_radius < initial_radius, "敌球瞄准环随 1 秒瞄准过程连续缩小")
		_check(indicator.draws_above_balls(), "瞄准虚线与准星绘制在双方球体上方")
	view.queue_redraw()
	await process_frame
	await process_frame
	view.simulation.left_ability.on_step(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		1.0
	)
	var rounds: Array[BallEntity] = view.simulation.entity_list(0, "sniper_round")
	_check(rounds.size() == 1, "狙击球真实视图在瞄准完成后生成一枚细锥形高速弹")
	if not rounds.is_empty():
		var round: BallEntity = rounds[0]
		var initial_position := round.pos
		round.process_step(view.simulation.battle_context, 0.02)
		_check(round.pos.distance_to(initial_position) > 20.0, "细锥形狙击弹在连续画面中高速前进")
		_check(round.draws_above_balls(), "狙击弹锥体和高速尾迹绘制在球体上方")
	var gun_direction: Vector2 = view.simulation.left_ability.call("gun_direction")
	_check(gun_direction.dot(Vector2.RIGHT) > 0.999, "外置狙击枪在真实视图中朝向敌方球心")
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(view.left_visual is BallVisual, "狙击球本体、外置枪械、瞄准虚线、缩圈准星和锥形弹真实绘制路径可执行")
	view.queue_free()
	await process_frame

func _check_heavy_industry_view() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20261228, "heavy_industry", "laser")
	view.simulation.left.pos = Vector2(180.0, 320.0)
	view.simulation.right.pos = Vector2(500.0, 320.0)
	view.simulation.left.velocity = Vector2.ZERO
	view.simulation.right.velocity = Vector2.ZERO
	_check(
		float(view.left_visual.call("deployment_port_width_to_length_ratio")) > 1.0,
		"重工球外凸出仓口的横向宽度严格大于沿出仓方向的长度"
	)
	var initial_port_angle := float(view.simulation.left_ability.call("port_angle"))
	view.simulation.left_ability.before_motion(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		0.35
	)
	var rotated_port_angle := float(view.simulation.left_ability.call("port_angle"))
	_check(not is_equal_approx(initial_port_angle, rotated_port_angle), "重工球实际视图中的出仓口持续旋转")
	view.simulation.left_ability.activate(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0
	)
	_check(
		bool(view.simulation.left_ability.call("deployment_animation_active")),
		"重工球真实视图在坦克生产时启动出仓门动画"
	)
	view.simulation.left_ability.before_motion(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		view.simulation.left_module.settingf("deployment_animation_duration") * 0.45
	)
	_check(
		float(view.simulation.left_ability.call("deployment_gate_open_amount")) > 0.99,
		"重工球真实绘制帧可进入双门全开和导轨灯运行状态"
	)
	var tanks: Array[BallEntity] = view.simulation.entity_list(0, "heavy_tank")
	_check(tanks.size() == 1, "重工球实际视图生成一辆独立坦克")
	if not tanks.is_empty():
		var tank: BallEntity = tanks[0]
		var initial_deployment := float(tank.call("deployment_progress"))
		var initial_turret_angle := float(tank.call("turret_angle"))
		view.simulation.right.pos = tank.pos + Vector2(0.0, -240.0)
		tank.process_step(view.simulation.battle_context, 0.2)
		_check(float(tank.call("deployment_progress")) > initial_deployment, "坦克从出仓缩放帧连续展开到完整车体")
		_check(not is_equal_approx(float(tank.call("turret_angle")), initial_turret_angle), "坦克炮塔在真实画面中独立转向敌球")
		_check(tank.draws_above_balls(), "坦克履带、车身和炮塔绘制在主球上方保持辨识度")
		tank.set("_fire_timer", 0.0)
		tank.process_step(view.simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(view.simulation.count_entities(0, "projectile") == 1, "坦克真实绘制场景包含炮口开火与炮弹")
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(view.left_visual is BallVisual, "重工球本体、旋转出仓口、双履带坦克、独立炮塔与炮弹绘制路径可执行")
	view.queue_free()
	await process_frame

func _check_garen_view() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20261229, "garen", "laser")
	view.simulation.left.pos = Vector2(220.0, 320.0)
	view.simulation.right.pos = Vector2(470.0, 320.0)
	view.simulation.left.velocity = Vector2.ZERO
	view.simulation.right.velocity = Vector2.ZERO
	view.simulation.left_ability.on_step(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		0.0
	)
	var idle_direction: Vector2 = view.simulation.left_ability.call("sword_direction")
	_check(idle_direction.dot(Vector2.RIGHT) > 0.9999, "盖伦球真实视图中的常驻长剑指向敌方球")
	view.queue_redraw()
	await process_frame
	await process_frame

	view.simulation.left_ability.activate(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0
	)
	var angle_before_spin := float(view.simulation.left_ability.call("sword_angle"))
	view.simulation.left_ability.on_step(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		0.16
	)
	var angle_during_spin := float(view.simulation.left_ability.call("sword_angle"))
	_check(not is_equal_approx(angle_before_spin, angle_during_spin), "盖伦球真实视图可进入剑刃旋转中间帧")
	_check(bool(view.simulation.left_ability.call("spin_active")), "旋转残影只由盖伦球自己的能力状态驱动")
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(view.left_visual is BallVisual, "盖伦球本体、长剑、护手和旋转残影绘制路径可执行")
	view.queue_free()
	await process_frame

func _check_vampire_view() -> void:
	var visual_source := FileAccess.get_file_as_string("res://scripts/balls/vampire/visual.gd")
	var remote_source := FileAccess.get_file_as_string("res://scripts/balls/vampire/remote_drain_entity.gd")
	var module_source := FileAccess.get_file_as_string("res://scripts/balls/vampire/module.gd")
	var invulnerability_source := FileAccess.get_file_as_string("res://scripts/balls/core/invulnerability_status_effect.gd")
	var battle_view_source := FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	_check(visual_source.contains("FANG_SOCKET_RADIUS_SCALE := 0.84"), "吸血鬼口器根部进一步嵌入本体以保持连接感")
	_check(visual_source.contains("FANG_TIP_RADIUS_SCALE := 1.28"), "吸血鬼尖牙进一步内收后仍突出本体半径之外")
	_check(visual_source.contains("FANG_SOCKET_SEPARATION_SCALE := 0.34"), "吸血鬼两个外凸口器拥有清晰的横向间距")
	_check(visual_source.contains("ability.call(\"facing_direction\")"), "吸血鬼尖牙口器从自身能力读取实时敌方方向")
	_check(visual_source.contains("presentation-only body edge"), "吸血鬼外凸尖牙仅属于绘制而不扩张碰撞体")
	_check(not visual_source.contains("mouth_root") and not visual_source.contains("mouth_outer"), "吸血鬼口器删除两颗白牙之外的外凸红色结构")
	_check(not visual_source.contains("draw_circle(socket_center"), "两颗白牙根部不再附带红色凸起或红色牙槽")
	_check(remote_source.contains("var end_t := 1.0 if _elapsed >= _attach_time else growth"), "远程血线按进度从敌方身上逐段生长而非瞬时连线")
	_check(remote_source.contains("maxf(suction_progress, moving_tail_t)"), "血线附着后保留短段并继续向吸血鬼口器逐段回收")
	_check(remote_source.contains("MAX_VISIBLE_STRAND_WORLD_LENGTH := 118.0"), "远程血线以短血流段移动而不再整条横跨竞技场")
	_check(remote_source.contains("moving_tail_t"), "远程血线前端生长时尾端同步跟进以限制可见长度")
	_check(remote_source.contains("FLOW_BEAD_COUNT := 3"), "每股远程血线包含多颗连续回流血滴")
	_check(remote_source.contains("WHIP_FREQUENCY := 9.5"), "远程血线通过高频曲线摆动增强动感")
	_check(module_source.contains('"group": "血线抽取"'), "吸血鬼参数组使用可稳定渲染的血线抽取标题")
	_check(not module_source.contains('"group": "远程血线"'), "吸血鬼参数弹窗不再使用会乱码的远程血线标题")
	_check(invulnerability_source.contains("SHIELD_COLOR := Color(\"f6c945\")"), "所有无敌状态统一使用金色盾牌标识")
	_check(invulnerability_source.contains("SHIELD_RADIUS_SCALE := 0.62"), "无敌盾牌在球心使用更醒目的大尺寸")
	_check(invulnerability_source.contains("var center := position"), "无敌盾牌固定绘制在球体正中间")
	_check(invulnerability_source.contains("outer_glow") and invulnerability_source.contains("inner_glow"), "无敌盾牌使用双层金色柔光")
	_check(invulnerability_source.contains("func draw_topmost_overlay"), "无敌盾牌通过可复用的顶层状态绘制契约呈现")
	_check(
		battle_view_source.find("effect.draw_topmost_overlay") > battle_view_source.find("_draw_center_value(position"),
		"无敌盾牌在球体、状态覆盖和球内血量之后绘制到最上层"
	)
	var marker_effect: BallStatusEffect = InvulnerabilityStatusEffectScript.new(2.0, 0, "test_invulnerability")
	var first_small_scale: float = float(marker_effect.call("animation_scale"))
	var half_period := 1.0 / (2.0 * 1.5)
	marker_effect.tick(null, null, half_period)
	var first_large_scale: float = float(marker_effect.call("animation_scale"))
	marker_effect.tick(null, null, half_period)
	var second_small_scale: float = float(marker_effect.call("animation_scale"))
	marker_effect.tick(null, null, half_period)
	var second_large_scale: float = float(marker_effect.call("animation_scale"))
	_check(
		first_large_scale > first_small_scale
			and first_large_scale > second_small_scale
			and second_large_scale > second_small_scale,
		"无敌盾牌持续按缩小、放大、缩小、放大的节奏循环"
	)

	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20261007, "vampire", "laser")
	view.simulation.left.pos = Vector2(250.0, 360.0)
	view.simulation.right.pos = Vector2(430.0, 210.0)
	view.simulation.left_ability.before_motion(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		0.0
	)
	var expected_direction := (view.simulation.right.pos - view.simulation.left.pos).normalized()
	var facing_direction: Vector2 = view.simulation.left_ability.call("facing_direction")
	_check(facing_direction.dot(expected_direction) > 0.999, "吸血鬼口器在实际视图中始终朝向对方球心")
	_check(is_equal_approx(view.simulation.left.radius, 28.0), "外凸尖牙不会改变吸血鬼配置碰撞半径")

	view.simulation.left_ability.activate(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0
	)
	var remote_drains: Array[BallEntity] = view.simulation.entity_list(0, "vampire_remote_drain")
	_check(remote_drains.size() == 1, "多股远程血线可通过实体绘制契约执行")
	if not remote_drains.is_empty():
		for _frame in range(24):
			remote_drains[0].process_step(view.simulation.battle_context, BattleSimulation.FIXED_STEP)
	view.simulation.left_ability.after_contact(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0.0
	)
	_check(view.simulation.count_entities(0, "vampire_latch_tether") == 1, "碰撞吸附血线可通过实体绘制契约执行")
	var found_shared_invulnerability := false
	for effect: BallStatusEffect in view.simulation.left.status_effects:
		if effect.get_script().get_base_script() == InvulnerabilityStatusEffectScript:
			found_shared_invulnerability = true
	_check(found_shared_invulnerability, "吸血鬼贴身无敌复用公共无敌状态与统一金盾表现")
	var heaven_simulation := BattleSimulation.new(20261008, "heaven", "laser")
	heaven_simulation.left_ability.activate(
		heaven_simulation.battle_context,
		heaven_simulation.left,
		heaven_simulation.right,
		0
	)
	var heaven_uses_shared_invulnerability := false
	for effect: BallStatusEffect in heaven_simulation.left.status_effects:
		if effect.get_script().get_base_script() == InvulnerabilityStatusEffectScript:
			heaven_uses_shared_invulnerability = true
	_check(heaven_uses_shared_invulnerability, "天堂球无敌同步复用公共无敌状态与同一个金盾标识")
	view.queue_redraw()
	await process_frame
	await process_frame
	view.queue_free()
	await process_frame

func _check_sonic_visual_policy() -> void:
	var visual: BallVisual = BallRegistry.get_module("sonic").create_visual()
	var visual_source := FileAccess.get_file_as_string("res://scripts/balls/sonic/visual.gd")
	var ability_source := FileAccess.get_file_as_string("res://scripts/balls/sonic/ability.gd")
	_check(is_zero_approx(visual.trail_alpha()), "音速球不再绘制移动拖尾")
	_check(not visual_source.contains("draw_arc"), "音速球不再拖着额外的三段弧形尾巴")
	_check(ability_source.contains("WAVE_LAYER_COUNT := 4"), "音速球提速效果由四层音波组成")
	_check(ability_source.contains("_pending_waves"), "后续音波由音速球私有队列依次释放")
	_check(not ability_source.contains("spawn_particles"), "音速球提速表现不再混入爆炸粒子")

func _check_wind_swordsman_view() -> void:
	var battle_view_source := FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	var slash_source := FileAccess.get_file_as_string("res://scripts/balls/wind_swordsman/slash_effect_entity.gd")
	var crack_source := FileAccess.get_file_as_string("res://scripts/balls/wind_swordsman/ground_crack_entity.gd")
	var below_entities_index := battle_view_source.find("_draw_entities(false)")
	var ball_index := battle_view_source.find("_draw_ball(simulation.left")
	var above_entities_index := battle_view_source.find("_draw_entities(true)")
	_check(
		below_entities_index >= 0 and below_entities_index < ball_index and ball_index < above_entities_index,
		"公共视图按低层实体、球体、高层实体的顺序分层绘制"
	)
	_check(slash_source.contains("func _draw_lens("), "风剑球斩击使用两端尖、中间宽的果核形绘制器")
	_check(slash_source.contains("draw_colored_polygon"), "风剑球斩击通过多层填充轮廓形成实体光感")
	_check(not slash_source.contains("canvas.draw_line"), "风剑球斩击不退化成矩形光柱或普通亮线")
	_check(not slash_source.contains("for afterimage"), "风剑球斩击不再绘制会形成对称弓形的左右残影")
	_check(slash_source.contains("full_finish := center + _direction"), "风剑球斩击从自身朝敌球方向生长")
	_check(crack_source.contains("var trench := PackedVector2Array()"), "风剑球地裂拥有填充式中央沟槽")
	_check(crack_source.contains("var fragments := ["), "风剑球地裂拥有沟槽两侧的独立碎地块")
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20260920, "wind_swordsman", "replicator")
	view.simulation.left.pos = Vector2(250.0, 320.0)
	view.simulation.right.pos = Vector2(350.0, 320.0)
	view.simulation.left_ability.on_step(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	view.simulation.left_ability.activate(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0
	)
	view.queue_redraw()
	await process_frame
	await process_frame
	var slash_effects: Array[BallEntity] = view.simulation.entity_list(0, "wind_slash_vfx")
	var ground_cracks: Array[BallEntity] = view.simulation.entity_list(0, "wind_ground_crack")
	_check(slash_effects.size() == 1, "风剑球指向梭形刀光可通过实体绘制契约执行")
	_check(ground_cracks.size() == 1, "风剑球短期地面裂痕可通过实体绘制契约执行")
	if not slash_effects.is_empty():
		_check(slash_effects[0].draws_above_balls(), "风剑球刀痕固定绘制在双方球体上方")
	if not ground_cracks.is_empty():
		_check(not ground_cracks[0].draws_above_balls(), "风剑球地面裂痕固定绘制在双方球体下方")
	_check(view.simulation.count_entities(0, "wind_wall") == 1, "风剑球曲面风障可通过实体绘制契约执行")
	view.queue_free()
	await process_frame

func _check_chess_view() -> void:
	var symbols := {
		"rook": "車",
		"cannon": "炮",
		"elephant": "象",
		"marshal": "帅",
		"guard": "士",
	}
	for skill: String in symbols:
		var settings := {
			"rook_weight": 0.0,
			"cannon_weight": 0.0,
			"elephant_weight": 0.0,
			"marshal_weight": 0.0,
			"guard_weight": 0.0,
		}
		settings["%s_weight" % skill] = 1.0
		BallRegistry.configure_settings({"chess": settings})
		var view: BattleView = BattleViewScript.new()
		view.size = BattleViewScript.DEFAULT_VIEW_SIZE
		get_root().add_child(view)
		view.start_battle(20270110 + symbols.keys().find(skill), "chess", "heaven")
		view.simulation.left_ability.activate(
			view.simulation.battle_context,
			view.simulation.left,
			view.simulation.right,
			0
		)
		view.queue_redraw()
		await process_frame
		await process_frame
		var icons: Array[BallEntity] = view.simulation.entity_list(0, "chess_cast_icon_vfx")
		_check(view.left_visual is BallVisual, "象棋球双环棋子本体真实绘制路径可执行")
		_check(icons.size() == 1 and icons[0].draw_layer >= 100, "%s 棋令文字在球体最上层执行放缩绘制" % symbols[skill])
		if skill == "cannon":
			view.simulation.left_ability.on_step(
				view.simulation.battle_context,
				view.simulation.left,
				view.simulation.right,
				0,
				0.28
			)
			view.queue_redraw()
			await process_frame
			_check(view.simulation.count_entities(0, "chess_cannonball") == 2, "连续两枚高亮炮弹与分层尾焰真实绘制路径可执行")
			_check(view.simulation.count_entities(0, "chess_cannon_muzzle_vfx") == 2, "两次独立炮口闪光真实绘制路径可执行")
		elif skill == "guard":
			_check(view.simulation.count_entities(0, "chess_guard") == 2, "两枚士、独立血条与环绕光晕真实绘制路径可执行")
		elif skill == "elephant":
			_check(view.simulation.has_status(view.simulation.left, "chess_elephant_invulnerability"), "象发动时通用金色无敌盾顶层绘制路径可执行")
		elif skill == "marshal":
			_check(view.simulation.has_status(view.simulation.left, "chess_marshal_regeneration"), "帅持续回复状态覆盖层真实绘制路径可执行")
		elif skill == "rook":
			_check(String(view.simulation.left_ability.call("rook_phase")) == "windup", "車发动后先绘制棋令图标与目标指示并保持 0.3 秒前摇")
			view.simulation.left_ability.on_step(
				view.simulation.battle_context,
				view.simulation.left,
				view.simulation.right,
				0,
				0.3
			)
			_check(String(view.simulation.left_ability.call("rook_phase")) == "dash", "車前摇结束后的突进运动强调真实绘制路径可执行")
		view.queue_free()
		await process_frame
	BallRegistry.configure_settings({})

func _check_yuri_view() -> void:
	var pulse_source := FileAccess.get_file_as_string("res://scripts/balls/yuri/psychic_pulse_entity.gd")
	var link_source := FileAccess.get_file_as_string("res://scripts/balls/yuri/psychic_link_entity.gd")
	var eye_overlay_source := FileAccess.get_file_as_string("res://scripts/balls/yuri/psychic_eye_overlay_entity.gd")
	var eye_renderer_source := FileAccess.get_file_as_string("res://scripts/balls/yuri/eye_renderer.gd")
	var visual_source := FileAccess.get_file_as_string("res://scripts/balls/yuri/visual.gd")
	var projectile_source := FileAccess.get_file_as_string("res://scripts/balls/core/projectile_entity.gd")
	var replicator_source := FileAccess.get_file_as_string("res://scripts/balls/replicator/clone_entity.gd")
	_check(pulse_source.contains("for wave in range(4)"), "尤里球精神波使用多层扩散弧环")
	_check(link_source.contains("canvas.draw_polyline(points"), "尤里球控制链使用动态弯曲光束")
	_check(
		visual_source.contains("EyeRenderer.draw_eye") and eye_renderer_source.contains("eye_points"),
		"尤里球本体与技能覆盖层复用同一套精神瞳孔绘制器"
	)
	_check(eye_overlay_source.contains("draw_layer = 100"), "尤里技能眼睛使用高于其他技能实体的顶层图层")
	_check(
		projectile_source.contains("func can_transfer_ownership() -> bool:")
			and projectile_source.contains("return false"),
		"标准投射物明确拒绝所有阵营控制"
	)
	_check(
		replicator_source.contains("func on_ownership_transferred(")
			and replicator_source.contains("_owner = new_owner_anchor"),
		"依赖主人的浮游炮通过通用所有权回调切换环绕中心"
	)
	for entity_path in [
		"res://scripts/balls/splitter/clone_entity.gd",
		"res://scripts/balls/replicator/clone_entity.gd",
		"res://scripts/balls/flame/fire_zone_entity.gd",
		"res://scripts/balls/wind_swordsman/wind_wall_entity.gd",
	]:
		_check(
			FileAccess.get_file_as_string(entity_path).contains("ownership_visual_color("),
			"可控制附属物通过通用阵营色契约绘制：%s" % entity_path
		)
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20260926, "yuri", "replicator")
	view.simulation.left.pos = Vector2(250.0, 320.0)
	view.simulation.right.pos = Vector2(520.0, 320.0)
	view.simulation.add_projectile(
		1,
		Vector2(330.0, 320.0),
		Vector2(-180.0, 0.0),
		5.0,
		8.0,
		Color("ff8bd8"),
		3.0,
		"yuri_view_fixture"
	)
	var projectile: BallProjectileEntity = view.simulation.entity_list(1, "projectile")[0]
	var controlled_target := TestControllableVisualEntity.new(1, Vector2(350.0, 320.0))
	view.simulation.add_entity(controlled_target)
	view.simulation.left_ability.activate(
		view.simulation.battle_context,
		view.simulation.left,
		view.simulation.right,
		0
	)
	view.queue_redraw()
	await process_frame
	await process_frame
	var pulses: Array[BallEntity] = view.simulation.entity_list(0, "psychic_pulse_vfx")
	var links: Array[BallEntity] = view.simulation.entity_list(0, "psychic_link_vfx")
	var eye_overlays: Array[BallEntity] = view.simulation.entity_list(0, "psychic_eye_overlay_vfx")
	_check(pulses.size() == 1, "尤里球扩散精神波通过实体绘制契约执行")
	_check(links.size() == 1, "尤里球心灵控制链通过实体绘制契约执行")
	_check(eye_overlays.size() == 1, "尤里球施法时生成独立眼睛覆盖层")
	if not pulses.is_empty():
		_check(pulses[0].draws_above_balls(), "精神波固定绘制在双方球体上方")
	if not links.is_empty():
		_check(links[0].draws_above_balls(), "控制链固定绘制在双方球体上方")
	if not eye_overlays.is_empty():
		var eye_overlay: BallEntity = eye_overlays[0]
		_check(eye_overlay.draws_above_balls(), "技能眼睛固定绘制在球体和球内血量上方")
		_check(
			eye_overlay.draw_layer > links[0].draw_layer,
			"技能眼睛图层高于心灵控制链"
		)
		var start_scale: float = float(eye_overlay.call("animation_scale"))
		eye_overlay.process_lifetime(eye_overlay.remaining * 0.5)
		var peak_scale: float = float(eye_overlay.call("animation_scale"))
		eye_overlay.process_lifetime(eye_overlay.remaining)
		var end_scale: float = float(eye_overlay.call("animation_scale"))
		_check(peak_scale > start_scale and peak_scale > end_scale, "技能眼睛先放大再缩回原尺寸")
	_check(projectile.owner_side == 1, "尤里球视觉对局中的投射物未被控制")
	_check(controlled_target.owner_side == 0, "尤里球视觉对局中的非投射附属物成功倒戈")
	_check(
		controlled_target.absorption_visual_color() == view.simulation.left.accent,
		"倒戈附属物的实际绘制色切换为尤里紫"
	)
	_check(int(view.simulation.left_ability.call("controlled_count")) == 1, "尤里球本体视觉可读取自身受控物数量")
	view.queue_free()
	await process_frame

func _check_plant_view() -> void:
	var ability_source := FileAccess.get_file_as_string("res://scripts/balls/plant/ability.gd")
	var growth_source := FileAccess.get_file_as_string("res://scripts/balls/plant/growth_entity.gd")
	var pickup_source := FileAccess.get_file_as_string("res://scripts/balls/plant/sun_pickup_entity.gd")
	var projectile_source := FileAccess.get_file_as_string("res://scripts/balls/plant/pea_projectile_entity.gd")
	var main_visual_source := FileAccess.get_file_as_string("res://scripts/balls/plant/visual.gd")
	var burn_source := FileAccess.get_file_as_string("res://scripts/balls/core/burn_status_effect.gd")
	var ice_slow_source := FileAccess.get_file_as_string("res://scripts/balls/plant/ice_slow_effect.gd")
	var planting_icon_source := FileAccess.get_file_as_string("res://scripts/balls/plant/planting_icon_overlay_entity.gd")
	_check(growth_source.contains("enum GrowthForm"), "植物的成长形态全部归植物实体自身管理")
	_check(
		growth_source.contains("_draw_sunflower")
		and growth_source.contains("_draw_fire_pea")
		and growth_source.contains("_draw_ice_pea")
		and growth_source.contains("_draw_gatling_pea"),
		"向日葵、火豌豆、冰豌豆和机枪豌豆各有独立高辨识轮廓"
	)
	_check(growth_source.contains("_draw_single_barrel") and growth_source.contains("_draw_gatling_helmet"), "成熟豌豆具有炮口、眼睛和装备层次")
	_check(growth_source.contains("_draw_health_bar") and growth_source.contains("if _form == GrowthForm.SEED"), "只有成熟植物显示可受击细血条")
	_check(
		growth_source.contains("growth_animation_scale")
		and growth_source.contains("mature_position")
		and growth_source.contains("mature_radius"),
		"成熟植物的破土成长动画由植物实体自身绘制"
	)
	_check(pickup_source.contains("for ray in range(8)"), "可拾取阳光使用旋转八芒光效")
	_check(pickup_source.contains("_start_position.lerp(_landing_position"), "阳光拥有从向日葵飞向随机落点的抛物线动画")
	_check(projectile_source.contains("projectile_kind == \"fire\"") and projectile_source.contains("projectile_kind == \"ice\""), "火豌豆和冰豌豆弹丸具有独立视觉表现")
	_check(
		burn_source.contains("_draw_flame_tongue")
		and burn_source.contains("var travel := fposmod")
		and not burn_source.contains("Vector2.from_angle(flame_angle)"),
		"燃烧使用固定向上的不规则火舌与上升火星，不再沿球体圆周旋转"
	)
	_check(
		ice_slow_source.contains("SNOWFLAKE_COUNT := 7")
		and ice_slow_source.contains("func _draw_snowflake")
		and ice_slow_source.contains("var travel := fposmod")
		and ice_slow_source.contains("for arm_index in range(6)"),
		"冰冻减速状态使用七枚持续飘落和旋转的六枝雪花"
	)
	_check(
		ability_source.contains("var spawn_position: Vector2 = fighter.pos")
		and not ability_source.contains("_choose_planting_position"),
		"植物球只在自身脚下种植，不再随机选择地图位置"
	)
	_check(main_visual_source.contains("Color(\"39f05f\")") and main_visual_source.contains("Color(\"a9ff76\")"), "植物球本体使用明亮绿色分层配色")
	_check(
		planting_icon_source.contains("draw_layer = 110")
		and planting_icon_source.contains("_draw_sprout")
		and planting_icon_source.contains("animation_scale"),
		"种植嫩芽图标在最高实体层执行居中放大缩小动画"
	)

	BallRegistry.configure_settings({
		"plant": {
			"cooldown": 60.0,
			"max_plants": 1,
			"growth_delay": 0.1,
			"growth_animation_duration": 0.6,
			"sunflower_growth_weight": 1.0,
			"fire_pea_growth_weight": 0.0,
			"ice_pea_growth_weight": 0.0,
			"gatling_pea_growth_weight": 0.0,
			"sun_launch_interval": 0.1,
			"sun_travel_duration": 0.2,
			"sun_pickup_lifetime": 20.0,
		}
	})
	var sunflower_view: BattleView = BattleViewScript.new()
	sunflower_view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(sunflower_view)
	sunflower_view.start_battle(20261106, "plant", "laser")
	sunflower_view.simulation.left_ability.activate(
		sunflower_view.simulation.battle_context,
		sunflower_view.simulation.left,
		sunflower_view.simulation.right,
		0
	)
	for _frame in range(4):
		sunflower_view.simulation.step(0.05)
	var sunflower_plants: Array[BallEntity] = sunflower_view.simulation.entity_list(0, "plant_growth")
	_check(not sunflower_plants.is_empty() and String(sunflower_plants[0].call("form_name")) == "sunflower", "真实视图执行种子到向日葵的一次直接发育")
	_check(sunflower_view.simulation.count_entities(0, "plant_sun_pickup") == 1, "飞向随机点的阳光进入真实高层实体绘制路径")
	_check(sunflower_view.simulation.count_entities(0, "plant_projectile") == 0, "向日葵真实视图中不生成攻击弹丸")
	var planting_icons: Array[BallEntity] = sunflower_view.simulation.entity_list(0, "planting_icon_overlay_vfx")
	_check(planting_icons.size() == 1 and planting_icons[0].draws_above_balls(), "种植图标进入真实最高层实体绘制路径")
	if not sunflower_plants.is_empty():
		_check(not sunflower_plants[0].draws_above_balls(), "种植植物固定绘制在主球下方")
		var growth_progress: float = float(sunflower_plants[0].call("growth_animation_progress"))
		_check(growth_progress > 0.0 and growth_progress < 1.0, "真实视图推进中的成熟植物仍处于破土成长动画")
	var sun_pickups: Array[BallEntity] = sunflower_view.simulation.entity_list(0, "plant_sun_pickup")
	if not sun_pickups.is_empty():
		_check(sun_pickups[0].draws_above_balls(), "可拾取阳光固定绘制在球体上方")
	sunflower_view.queue_redraw()
	await process_frame
	await process_frame
	sunflower_view.queue_free()
	await process_frame

	BallRegistry.configure_settings({
		"plant": {
			"cooldown": 60.0,
			"max_plants": 1,
			"growth_delay": 0.1,
			"sunflower_growth_weight": 0.0,
			"fire_pea_growth_weight": 1.0,
			"ice_pea_growth_weight": 1.0,
			"gatling_pea_growth_weight": 1.0,
			"fire_fire_interval": 0.1,
			"ice_fire_interval": 0.1,
			"gatling_fire_interval": 0.1,
			"pea_projectile_speed": 20.0,
			"pea_projectile_lifetime": 5.0,
		}
	})
	var pea_view: BattleView = BattleViewScript.new()
	pea_view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(pea_view)
	pea_view.start_battle(20261107, "plant", "hammer")
	pea_view.simulation.left_ability.activate(
		pea_view.simulation.battle_context,
		pea_view.simulation.left,
		pea_view.simulation.right,
		0
	)
	for _frame in range(5):
		pea_view.simulation.step(0.05)
	var advanced_plants: Array[BallEntity] = pea_view.simulation.entity_list(0, "plant_growth")
	if not advanced_plants.is_empty():
		_check(
			String(advanced_plants[0].call("form_name")) in ["pea_fire", "pea_ice", "pea_gatling"],
			"真实视图执行种子到成熟豌豆的一次直接发育"
		)
	else:
		_check(false, "真实视图可生成高级豌豆射手")
	var burn_effect: BallStatusEffect = BurnStatusEffectScript.new(
		1.0,
		0,
		1.0,
		1.0,
		"plant_view_fixture",
		Color("ff6724")
	)
	pea_view.simulation.apply_status(pea_view.simulation.right, burn_effect)
	var ice_slow_effect: BallStatusEffect = PlantIceSlowEffectScript.new(1.0, 0, 0.65)
	pea_view.simulation.apply_status(pea_view.simulation.right, ice_slow_effect)
	var particle_count_before := pea_view.simulation.particles.size()
	pea_view.simulation.step(0.05)
	_check(pea_view.simulation.particles.size() > particle_count_before, "真实视图中的燃烧状态持续释放火粒子")
	_check(
		pea_view.simulation.has_status(pea_view.simulation.right, "plant_ice_slow_0"),
		"真实视图执行冰蓝光晕和雪花状态覆盖层"
	)
	pea_view.queue_redraw()
	await process_frame
	await process_frame
	pea_view.queue_free()
	await process_frame
	BallRegistry.configure_settings({})

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
