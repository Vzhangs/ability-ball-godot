extends SceneTree

const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const BallSettingsDialogScript := preload("res://scripts/ui/ball_settings_dialog.gd")
const BallPickerDialogScript := preload("res://scripts/ui/ball_picker_dialog.gd")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")
const ModeRosterEditorScript := preload("res://scripts/ui/mode_roster_editor.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const GlobalSettingsDialogScript := preload("res://scripts/ui/global_settings_dialog.gd")
const InvulnerabilityStatusEffectScript := preload("res://scripts/balls/core/invulnerability_status_effect.gd")
const BurnStatusEffectScript := preload("res://scripts/balls/core/burn_status_effect.gd")
const IceSlowStatusEffectScript := preload("res://scripts/balls/core/ice_slow_status_effect.gd")

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
	await _check_damage_number_settings()
	await _check_fighter_death_result_sequence()
	await _check_vampire_view()
	_check_sonic_visual_policy()
	await _check_wind_swordsman_view()
	await _check_yuri_view()
	await _check_plant_view()
	await _check_wdc_view()
	await _check_spider_web_view()
	await _check_train_conductor_view()
	await _check_sniper_view()
	await _check_heavy_industry_view()
	await _check_garen_view()
	await _check_chess_view()
	await _check_ball_picker_dialog()
	await _check_mode_roster_editor()
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
		main_source.contains("RECORDING_LOGICAL_VIEWPORT_SIZE := Vector2i(720, 1280)"),
		"录制模式继续保持 720×1280 逻辑母版"
	)
	_check(
		main_source.contains("INTERACTIVE_LOGICAL_VIEWPORT_SIZE := Vector2i(1180, 1280)"),
		"交互窗口使用加宽逻辑画布为左侧配置栏预留空间"
	)
	_check(
		main_source.contains("ConfigSidebar") and main_source.contains("INTERACTIVE_BATTLE_CENTER_Y"),
		"交互配置栏和战斗内容区具有相互独立的布局锚点"
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
	view.start_battle(20260914, "splitter", "test_ball", 85.0, Vector2(900.0, 500.0))
	visible_world = view.visible_world_size()
	arena_rect = view.arena_screen_rect()
	_check(view.simulation.arena_size() == Vector2(900.0, 500.0), "自定义竞技场尺寸进入真实战斗视图")
	_check(is_equal_approx(visible_world.x / 900.0, 1.2), "自定义竞技场保持横向 120% 可视世界")
	_check(visible_world.y / 500.0 >= 1.2, "矩形外层允许在纵向保留更多展示空间")
	_check(is_equal_approx(arena_rect.size.x / arena_rect.size.y, 900.0 / 500.0), "碰撞白框按自定义宽高比绘制")
	view.start_battle(20270914, "spider_web", "test_ball", 85.0, Vector2(440.0, 440.0))
	var square_view_size := view.size
	var square_arena_rect := view.arena_screen_rect()
	var square_scale: float = view.call("_scale_factor")
	view.start_battle(20270915, "spider_web", "test_ball", 85.0, Vector2(440.0, 740.0))
	var tall_arena_rect := view.arena_screen_rect()
	_check(is_equal_approx(view.size.x, square_view_size.x), "竞技场增高时战斗外框视觉宽度保持不变")
	_check(view.size.y > square_view_size.y, "440×740 竞技场通过拉长外框而不是压缩内容来容纳高度")
	_check(is_equal_approx(float(view.call("_scale_factor")), square_scale), "相同竞技场宽度始终得到相同世界缩放与球体视觉大小")
	_check(is_equal_approx(tall_arena_rect.size.x, square_arena_rect.size.x), "440×440 与 440×740 的白框视觉宽度完全一致")
	_check(is_equal_approx(tall_arena_rect.size.y / square_arena_rect.size.y, 740.0 / 440.0), "竞技场增高只按真实高度比例延长白框")
	_check(tall_arena_rect.end.y < view.size.y, "增长后的竖屏外框仍保留白框底部展示余量")
	view.free()

func _check_health_hud_policy() -> void:
	var view_source := FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var clone_source := FileAccess.get_file_as_string("res://scripts/balls/splitter/clone_entity.gd")
	var render_source := FileAccess.get_file_as_string("res://tools/render_video.sh")
	_check(view_source.contains("simulation.fighter_for_side(simulation.teams[0].team_id).max_hp"), "左侧顶部血条标注当前与最大血量")
	_check(view_source.contains("simulation.fighter_for_side(simulation.teams[1].team_id).max_hp"), "右侧顶部血条标注当前与最大血量")
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
	_check(view_source.contains("if not result_reveal_ready():"), "获胜弹窗由死亡演出完成状态统一控制")
	_check(view_source.contains("if not simulation.is_draw():") and view_source.contains("\"平局\""), "同归于尽时结果卡显示平局而不读取不存在的胜者")
	_check(main_source.contains("if simulation.is_draw():") and main_source.contains("\"平局 · %s · 种子 %d\""), "主界面与录制流程显示平局结果")
	_check(not main_source.contains("status_label"), "战斗框下方不再重复标注双方血量")
	_check(main_source.contains("BallSettingsStoreScript.save_settings"), "球参数保存后由入口自动持久化")
	_check(main_source.contains("GlobalSettingsStoreScript.save_mode_settings"), "当前玩法的全局设置保存后由入口自动持久化")
	_check(not main_source.contains("time_limit_spin_box"), "对局时限只有全局设置一个界面事实源")
	_check(main_source.contains("OS.create_process"), "局内录制使用独立后台进程，不阻塞当前对局")
	_check(main_source.contains("if not recording_mode:"), "录制呈现模式不创建下方操作区")
	_check(render_source.contains("--resolution 1080x1920"), "录制进程显式请求 1080×1920 原生母版")
	_check(not render_source.contains("crop=1080:1200:0:0"), "视频不会用固定高度裁断响应式战斗视图")
	_check(not render_source.contains("pad=1080:1920:0:360:color=black"), "Godot 母版自身完成响应式竖屏排版，不再二次搬动画面")
	_check(not render_source.contains("scale=1080:1200"), "录制链路不再把低分辨率画面放大成 1080×1200")
	_check(render_source.contains('--fixed-fps "$recording_fps"'), "视频生成脚本使用用户选择的录制帧率")
	_check(render_source.contains('"--battle-mode=$battle_mode"'), "视频重演显式传递当前战斗模式")
	_check(render_source.contains('"--team-rosters=$team_rosters"'), "视频重演显式传递全部阵营阵容")
	_check(render_source.contains('-ss 6 -i "$pending_file"') and render_source.contains('"$output_file.cover.jpg"'), "录制为独立封面提取对局第六秒参考帧")
	_check(not render_source.contains("overlay=enable='eq(n,0)'"), "独立封面不替换视频首帧")

func _check_fighter_death_result_sequence() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	view.result_reveal_delay_seconds = 0.6
	get_root().add_child(view)
	view.start_battle(20261211, "vampire", "wdc")
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).hp = 5.0
	view.simulation.damage(view.simulation.fighter_for_side(view.simulation.teams[1].team_id), 10.0, view.simulation.fighter_for_side(view.simulation.teams[0].team_id).accent, view.simulation.fighter_for_side(view.simulation.teams[0].team_id))
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
	view.start_battle(20261207, "wdc", "test_ball")
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
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
	view.start_battle(20261215, "spider_web", "test_ball")
	var fighter = view.simulation.fighter_for_side(view.simulation.teams[0].team_id)
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
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = Vector2(180.0, 250.0)
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

func _check_train_conductor_view() -> void:
	var track_source := FileAccess.get_file_as_string("res://scripts/balls/train_conductor/track_entity.gd")
	var train_source := FileAccess.get_file_as_string("res://scripts/balls/train_conductor/train_car_entity.gd")
	_check(
		track_source.contains("RAIL_GAUGE := 14.0")
		and track_source.contains("func _draw_continuous_sleepers")
		and track_source.contains("func _draw_terminal"),
		"列车长使用宽轨、连续枕木与墙面终端组成清晰铁路，而不是逐采样段重复虚线"
	)
	_check(
		train_source.contains("ENGINE_RED")
		and train_source.contains("CARRIAGE_WOOD")
		and train_source.contains("cowcatcher_tip")
		and train_source.contains("func _draw_coupler"),
		"列车使用黑铁红铜车头、木质车厢、排障器和连接器建立独立火车轮廓"
	)
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20260824, "train_conductor", "test_ball")
	var simulation: BattleSimulation = view.simulation
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(simulation.fighter_for_side(simulation.teams[0].team_id).radius + 0.1, 240.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(-simulation.fighter_for_side(simulation.teams[0].team_id).minimum_speed, 0.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(470.0, 500.0)
	simulation.step(BattleSimulation.FIXED_STEP)
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(290.0, 260.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(simulation.fighter_for_side(simulation.teams[0].team_id).minimum_speed, 36.0)
	for _route_frame in range(4):
		simulation.step(0.05)
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(simulation.arena_size().x - simulation.fighter_for_side(simulation.teams[0].team_id).radius - 0.1, 330.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(simulation.fighter_for_side(simulation.teams[0].team_id).minimum_speed, 0.0)
	simulation.step(BattleSimulation.FIXED_STEP)
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(simulation.fighter_for_side(simulation.teams[0].team_id).radius + 0.1, 390.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(-simulation.fighter_for_side(simulation.teams[0].team_id).minimum_speed, 0.0)
	simulation.step(BattleSimulation.FIXED_STEP)
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(simulation.arena_size().x - simulation.fighter_for_side(simulation.teams[0].team_id).radius - 0.1, 450.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(simulation.fighter_for_side(simulation.teams[0].team_id).minimum_speed, 0.0)
	simulation.step(BattleSimulation.FIXED_STEP)
	for _entry_frame in range(22):
		simulation.step(BattleSimulation.FIXED_STEP)
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(simulation.count_entities(0, "train_track") == 1, "列车长视图只绘制当前发车周期的完整已结算线路")
	_check(simulation.count_entities(0, "train_engine") == 1, "列车长视图装载真实车头实体")
	_check(simulation.count_entities(0, "train_car") == 9, "列车长视图装载一车头加九车厢的完整列车")
	var engine_entities := simulation.entity_list(0, "train_engine")
	_check(
		not engine_entities.is_empty()
		and Vector2(engine_entities[0].call("heading")).x > 0.5,
		"列车车头从最早铺轨点沿固化折线路径正向驶出"
	)
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
	view.start_battle(20261220, "sniper", "test_ball")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos = Vector2(150.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = Vector2(500.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).velocity = Vector2.ZERO
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).velocity = Vector2.ZERO
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0
	)
	var indicators: Array[BallEntity] = view.simulation.entity_list(0, "sniper_aim_vfx")
	_check(indicators.size() == 1, "狙击球真实视图生成一条虚线和一个敌球缩圈瞄准标志")
	if not indicators.is_empty():
		var indicator: BallEntity = indicators[0]
		var initial_progress := float(indicator.call("animation_progress"))
		var initial_radius := float(indicator.call("reticle_radius", view.simulation.fighter_for_side(view.simulation.teams[1].team_id).radius))
		indicator.process_step(view.simulation.battle_context, 0.5)
		var middle_progress := float(indicator.call("animation_progress"))
		var middle_radius := float(indicator.call("reticle_radius", view.simulation.fighter_for_side(view.simulation.teams[1].team_id).radius))
		_check(middle_progress > initial_progress and middle_radius < initial_radius, "敌球瞄准环随 1.5 秒瞄准过程连续缩小")
		_check(indicator.draws_above_balls(), "瞄准虚线与准星绘制在双方球体上方")
	view.queue_redraw()
	await process_frame
	await process_frame
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		1.5
	)
	var rounds: Array[BallEntity] = view.simulation.entity_list(0, "sniper_round")
	_check(rounds.size() == 1, "狙击球真实视图在瞄准完成后生成一枚细锥形高速弹")
	if not rounds.is_empty():
		var round: BallEntity = rounds[0]
		var initial_position := round.pos
		round.process_step(view.simulation.battle_context, 0.02)
		_check(round.pos.distance_to(initial_position) > 8.0, "细锥形狙击弹在连续画面中向前移动")
		_check(round.draws_above_balls(), "狙击弹锥体和高速尾迹绘制在球体上方")
	var gun_direction: Vector2 = view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("gun_direction")
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
	view.start_battle(20261228, "heavy_industry", "test_ball")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos = Vector2(180.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = Vector2(500.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).velocity = Vector2.ZERO
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).velocity = Vector2.ZERO
	_check(
		float(view.left_visual.call("deployment_port_width_to_length_ratio")) > 1.0,
		"重工球外凸出仓口的横向宽度严格大于沿出仓方向的长度"
	)
	var initial_port_angle := float(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("port_angle"))
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).before_motion(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		0.35
	)
	var rotated_port_angle := float(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("port_angle"))
	_check(not is_equal_approx(initial_port_angle, rotated_port_angle), "重工球实际视图中的出仓口持续旋转")
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0
	)
	_check(
		bool(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("deployment_animation_active")),
		"重工球真实视图在坦克生产时启动出仓门动画"
	)
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).before_motion(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		view.simulation.module_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).settingf("deployment_animation_duration") * 0.45
	)
	_check(
		float(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("deployment_gate_open_amount")) > 0.99,
		"重工球真实绘制帧可进入双门全开和导轨灯运行状态"
	)
	var tanks: Array[BallEntity] = view.simulation.entity_list(0, "heavy_tank")
	_check(tanks.size() == 1, "重工球实际视图生成一辆独立坦克")
	if not tanks.is_empty():
		var tank: BallEntity = tanks[0]
		var initial_deployment := float(tank.call("deployment_progress"))
		var initial_turret_angle := float(tank.call("turret_angle"))
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = tank.pos + Vector2(0.0, -240.0)
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
	var visual_source := FileAccess.get_file_as_string("res://scripts/balls/garen/visual.gd")
	_check(not visual_source.contains("width * 1.85"), "盖伦球长剑不再使用会形成黄色长方框的粗直线泛光")
	_check(visual_source.contains("blade_glow"), "盖伦球长剑改用贴合剑刃轮廓的收尖泛光")
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20261229, "garen", "test_ball")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos = Vector2(220.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = Vector2(470.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).velocity = Vector2.ZERO
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).velocity = Vector2.ZERO
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		0.0
	)
	var idle_direction: Vector2 = view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("sword_direction")
	_check(idle_direction.dot(Vector2.RIGHT) > 0.9999, "盖伦球真实视图中的常驻长剑指向敌方球")
	view.queue_redraw()
	await process_frame
	await process_frame

	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0
	)
	var angle_before_spin := float(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("sword_angle"))
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		0.16
	)
	var angle_during_spin := float(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("sword_angle"))
	_check(not is_equal_approx(angle_before_spin, angle_during_spin), "盖伦球真实视图可进入剑刃旋转中间帧")
	_check(bool(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("spin_active")), "旋转残影只由盖伦球自己的能力状态驱动")
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
		battle_view_source.find("\t_draw_topmost_statuses()") > battle_view_source.find("\t\t\t_draw_center_value("),
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
	view.start_battle(20261007, "vampire", "test_ball")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos = Vector2(250.0, 360.0)
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = Vector2(430.0, 210.0)
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).before_motion(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		0.0
	)
	var expected_direction := (view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos - view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos).normalized()
	var facing_direction: Vector2 = view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("facing_direction")
	_check(facing_direction.dot(expected_direction) > 0.999, "吸血鬼口器在实际视图中始终朝向对方球心")
	_check(is_equal_approx(view.simulation.fighter_for_side(view.simulation.teams[0].team_id).radius, 28.0), "外凸尖牙不会改变吸血鬼配置碰撞半径")

	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0
	)
	var remote_drains: Array[BallEntity] = view.simulation.entity_list(0, "vampire_remote_drain")
	_check(remote_drains.size() == 1, "多股远程血线可通过实体绘制契约执行")
	if not remote_drains.is_empty():
		for _frame in range(24):
			remote_drains[0].process_step(view.simulation.battle_context, BattleSimulation.FIXED_STEP)
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).after_contact(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0.0
	)
	_check(view.simulation.count_entities(0, "vampire_latch_tether") == 1, "碰撞吸附血线可通过实体绘制契约执行")
	var found_shared_invulnerability := false
	for effect: BallStatusEffect in view.simulation.fighter_for_side(view.simulation.teams[0].team_id).status_effects:
		if effect.get_script().get_base_script() == InvulnerabilityStatusEffectScript:
			found_shared_invulnerability = true
	_check(found_shared_invulnerability, "吸血鬼贴身无敌复用公共无敌状态与统一金盾表现")
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
	var ball_index := battle_view_source.find("_draw_ball(fighter, fighter_visuals")
	var above_entities_index := battle_view_source.find("_draw_entities(true)")
	_check(
		below_entities_index >= 0 and below_entities_index < ball_index and ball_index < above_entities_index,
		"公共视图按低层实体、全部主球、高层实体的顺序分层绘制"
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
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos = Vector2(250.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = Vector2(350.0, 320.0)
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
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
		view.start_battle(20270110 + symbols.keys().find(skill), "chess", "test_ball")
		view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
			view.simulation.battle_context,
			view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
			view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
			0
		)
		view.queue_redraw()
		await process_frame
		await process_frame
		var icons: Array[BallEntity] = view.simulation.entity_list(0, "chess_cast_icon_vfx")
		_check(view.left_visual is BallVisual, "象棋球双环棋子本体真实绘制路径可执行")
		_check(icons.size() == 1 and icons[0].draw_layer >= 100, "%s 棋令文字在球体最上层执行放缩绘制" % symbols[skill])
		if skill == "cannon":
			view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
				view.simulation.battle_context,
				view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
				view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
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
			_check(view.simulation.has_status(view.simulation.fighter_for_side(view.simulation.teams[0].team_id), "chess_elephant_invulnerability"), "象发动时通用金色无敌盾顶层绘制路径可执行")
		elif skill == "marshal":
			_check(view.simulation.has_status(view.simulation.fighter_for_side(view.simulation.teams[0].team_id), "chess_marshal_regeneration"), "帅持续回复状态覆盖层真实绘制路径可执行")
		elif skill == "rook":
			_check(String(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("rook_phase")) == "windup", "車发动后先绘制棋令图标与目标指示并保持 0.3 秒前摇")
			view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
				view.simulation.battle_context,
				view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
				view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
				0,
				0.3
			)
			_check(String(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("rook_phase")) == "dash", "車前摇结束后的突进运动强调真实绘制路径可执行")
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
	_check(
		visual_source.contains("_draw_overload_feedback")
			and visual_source.contains("canvas.draw_polyline(points"),
		"尤里球心灵过载使用球内独立的短促电弧反馈"
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
	BallRegistry.configure_settings({
		"yuri": {
			"soft_controlled_total": 0,
			"control_overload_tick_interval": 1.0,
			"control_overload_damage_per_excess_per_second": 1.0,
			"control_overload_effect_duration": 0.5,
		},
	})
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20260926, "yuri", "replicator")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos = Vector2(250.0, 320.0)
	view.simulation.fighter_for_side(view.simulation.teams[1].team_id).pos = Vector2(520.0, 320.0)
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
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0
	)
	var overload_particle_count_before := view.simulation.particles.size()
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		1.0
	)
	var overload_flash_start := float(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("overload_flash_ratio"))
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
		controlled_target.absorption_visual_color() == view.simulation.fighter_for_side(view.simulation.teams[0].team_id).accent,
		"倒戈附属物的实际绘制色切换为尤里紫"
	)
	_check(int(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("controlled_count")) == 1, "尤里球本体视觉可读取自身受控物数量")
	_check(
		overload_flash_start > 0.0
			and view.simulation.particles.size() > overload_particle_count_before,
		"尤里球真实过载掉血进入电弧与粒子绘制路径"
	)
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).on_step(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		0.2
	)
	_check(
		float(view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).call("overload_flash_ratio")) < overload_flash_start,
		"尤里球过载电弧按配置时长衰减而不是常驻覆盖球体"
	)
	view.queue_free()
	await process_frame
	BallRegistry.configure_settings({})

func _check_plant_view() -> void:
	var ability_source := FileAccess.get_file_as_string("res://scripts/balls/plant/ability.gd")
	var growth_source := FileAccess.get_file_as_string("res://scripts/balls/plant/growth_entity.gd")
	var pickup_source := FileAccess.get_file_as_string("res://scripts/balls/plant/sun_pickup_entity.gd")
	var projectile_source := FileAccess.get_file_as_string("res://scripts/balls/plant/pea_projectile_entity.gd")
	var main_visual_source := FileAccess.get_file_as_string("res://scripts/balls/plant/visual.gd")
	var burn_source := FileAccess.get_file_as_string("res://scripts/balls/core/burn_status_effect.gd")
	var ice_slow_source := FileAccess.get_file_as_string("res://scripts/balls/core/ice_slow_status_effect.gd")
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
	sunflower_view.start_battle(20261106, "plant", "test_ball")
	sunflower_view.simulation._ability_for_fighter(sunflower_view.simulation.fighter_for_side(sunflower_view.simulation.teams[0].team_id)).activate(
		sunflower_view.simulation.battle_context,
		sunflower_view.simulation.fighter_for_side(sunflower_view.simulation.teams[0].team_id),
		sunflower_view.simulation.fighter_for_side(sunflower_view.simulation.teams[1].team_id),
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
	pea_view.start_battle(20261107, "plant", "splitter")
	pea_view.simulation._ability_for_fighter(pea_view.simulation.fighter_for_side(pea_view.simulation.teams[0].team_id)).activate(
		pea_view.simulation.battle_context,
		pea_view.simulation.fighter_for_side(pea_view.simulation.teams[0].team_id),
		pea_view.simulation.fighter_for_side(pea_view.simulation.teams[1].team_id),
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
	pea_view.simulation.apply_status(pea_view.simulation.fighter_for_side(pea_view.simulation.teams[1].team_id), burn_effect)
	var ice_slow_effect: BallStatusEffect = IceSlowStatusEffectScript.new(1.0, 0, 0.65)
	pea_view.simulation.apply_status(pea_view.simulation.fighter_for_side(pea_view.simulation.teams[1].team_id), ice_slow_effect)
	pea_view.simulation._ability_for_fighter(pea_view.simulation.fighter_for_side(pea_view.simulation.teams[1].team_id)).activate(
		pea_view.simulation.battle_context,
		pea_view.simulation.fighter_for_side(pea_view.simulation.teams[1].team_id),
		pea_view.simulation.fighter_for_side(pea_view.simulation.teams[0].team_id),
		1
	)
	var debuffed_clones: Array[BallEntity] = pea_view.simulation.entity_list(1, "splitter_clone")
	if not debuffed_clones.is_empty():
		pea_view.simulation.apply_status(debuffed_clones[0], BurnStatusEffectScript.new(
			1.0,
			0,
			1.0,
			1.0,
			"plant_attachment_view_fixture",
			Color("ff6724")
		))
		pea_view.simulation.apply_status(
			debuffed_clones[0],
			IceSlowStatusEffectScript.new(1.0, 0, 0.65)
		)
		_check(
			debuffed_clones[0].status_effects.size() == 2,
			"真实附属实体同时进入灼烧与雪花状态绘制路径"
		)
	else:
		_check(false, "植物真实视图可生成用于附属物减益绘制的分身")
	var particle_count_before := pea_view.simulation.particles.size()
	pea_view.simulation.step(0.05)
	_check(pea_view.simulation.particles.size() > particle_count_before, "真实视图中的燃烧状态持续释放火粒子")
	_check(
		pea_view.simulation.has_status(pea_view.simulation.fighter_for_side(pea_view.simulation.teams[1].team_id), IceSlowStatusEffectScript.KEY),
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
	_check(not dialog.wrap_controls, "球参数弹窗不会在首次生成长表单时被内容撑出窗口")
	var first_open_size := Vector2i(dialog.size)
	_check(dialog.get_ok_button().is_visible_in_tree(), "球参数弹窗首次打开即可看到保存并应用按钮")
	var settings_scroll := dialog.find_child("BallSettingsScroll", true, false) as ScrollContainer
	var settings_scroll_bar := settings_scroll.get_v_scroll_bar()
	_check(
		settings_scroll_bar.visible
			and settings_scroll_bar.max_value > settings_scroll_bar.page,
		"球参数弹窗首次打开就建立真实的纵向滚动范围并显示滚动条"
	)
	settings_scroll.scroll_vertical = 120
	await process_frame
	_check(settings_scroll.scroll_vertical > 0, "球参数弹窗首次打开即可实际滚动配置表单")
	var specs: Dictionary = BallRegistry.get_module("splitter").setting_specs()
	var numeric_spec_count := 0
	var text_spec_count := 0
	for key in specs:
		if String(specs[key].get("kind", "float")) == "text":
			text_spec_count += 1
		else:
			numeric_spec_count += 1
	var controls := dialog.find_children("*", "SpinBox", true, false)
	_check(
		controls.size() == numeric_spec_count,
		"弹窗按分身球 Schema 自动生成全部数值输入框"
	)
	var text_controls := dialog.find_children("*", "TextEdit", true, false)
	_check(text_controls.size() == text_spec_count, "弹窗按球 Schema 生成可编辑的简介文本框")
	_check(
		text_controls.size() == 1
			and (text_controls[0] as TextEdit).text == BallRegistry.get_module("splitter").ability_description,
		"球简介编辑框读取当前持久化配置"
	)
	_check(
		dialog.find_children("*", "OptionButton", true, false).is_empty(),
		"球参数页不再保留随球数增长的下拉选球框"
	)
	var picker_button := dialog.find_child("BallSettingsPickerButton", true, false) as Button
	_check(picker_button != null, "球参数页通过卡片式选球入口选择要配置的球")
	var picker_request := {"id": ""}
	dialog.ball_picker_requested.connect(func(ball_id: String) -> void:
		picker_request["id"] = ball_id
	)
	var custom_description := "分身球会不断制造能够独立受伤和撞击的小分身。\n\n• 分身能够挡住攻击，也会在生命耗尽后消失。"
	(text_controls[0] as TextEdit).text = custom_description
	picker_button.pressed.emit()
	await process_frame
	_check(String(picker_request["id"]) == "splitter", "点击配置页选球入口会请求同一个卡片式球库")
	_check(not dialog.visible, "打开卡片球库前收起球参数窗口，避免子窗口遮挡选球卡片")
	dialog.select_ball_and_reopen("black_hole")
	await process_frame
	_check(dialog.current_ball_id() == "black_hole", "卡片选择结果可以切换当前配置球并恢复参数窗口")
	dialog.select_ball_and_reopen("splitter")
	await process_frame
	var restored_description := dialog.find_child("BallDescriptionEditor", true, false) as TextEdit
	_check(
		restored_description != null and restored_description.text == custom_description,
		"切换配置球时尚未保存的简介编辑仍保留在工作副本中"
	)
	dialog.hide()
	dialog.open_settings(BallRegistry.settings_snapshot(), "splitter")
	await process_frame
	_check(dialog.size == first_open_size, "球参数弹窗第一次和后续打开尺寸一致")
	dialog.hide()
	dialog.queue_free()
	await process_frame

func _check_ball_picker_dialog() -> void:
	var dialog = BallPickerDialogScript.new()
	var ui_theme := Theme.new()
	ui_theme.default_font = CjkFontProviderScript.font()
	dialog.theme = ui_theme
	get_root().add_child(dialog)
	var picked := {"id": ""}
	dialog.ball_selected.connect(func(ball_id: String) -> void:
		picked["id"] = ball_id
	)
	dialog.open_picker("vampire", "左侧")
	await process_frame
	await process_frame
	_check(dialog.visible, "球库卡片弹窗可以正常打开")
	var picker_panel := dialog.find_child("BallPickerPanel", true, false) as PanelContainer
	var card_scroll := dialog.find_child("BallCardScroll", true, false) as ScrollContainer
	var card_grid := dialog.find_child("BallCardGrid", true, false) as GridContainer
	var ability_preview := dialog.find_child("BallAbilityPreview", true, false) as PanelContainer
	var ability_scroll := dialog.find_child("BallAbilityDescriptionScroll", true, false) as ScrollContainer
	_check(picker_panel != null and picker_panel.size == Vector2(660.0, 940.0), "选球弹窗完整限制在逻辑画布内")
	_check(
		card_scroll != null and card_grid != null and card_scroll.size.y < card_grid.size.y,
		"球种增加后卡片网格在固定视口内滚动而不撑高弹窗"
	)
	_check(
		picker_panel != null and ability_preview != null
			and ability_preview.position.y + ability_preview.size.y <= picker_panel.size.y,
		"悬浮能力说明始终保留在弹窗可视范围内"
	)
	_check(
		ability_preview != null and ability_preview.size.y >= 212.0 and ability_scroll != null,
		"能力说明区为完整机制文案保留足够高度，超长内容可以独立滚动"
	)
	var incomplete_descriptions: Array[String] = []
	var corrupted_descriptions: Array[String] = []
	var unstructured_descriptions: Array[String] = []
	var developer_facing_descriptions: Array[String] = []
	var tuning_descriptions: Array[String] = []
	var presentation_descriptions: Array[String] = []
	for module: BallModule in BallRegistry.modules():
		var description := module.ability_description.strip_edges()
		if description.length() < 60 or not description.contains("。"):
			incomplete_descriptions.append(module.id)
		if BallModule.ability_text_looks_corrupted(description):
			corrupted_descriptions.append(module.id)
		if BallModule.ability_text_contains_tuning_details(description):
			tuning_descriptions.append(module.id)
		if BallModule.ability_text_contains_presentation_details(description):
			presentation_descriptions.append(module.id)
		var formatted := module.formatted_ability_description()
		if not formatted.contains("\n\n") or not formatted.contains("\n• "):
			unstructured_descriptions.append(module.id)
		for backstage_term in ["可配置", "持久化", "参数", "判定", "权重", "通用规则", "契约", "实现原理", "默认"]:
			if description.contains(backstage_term):
				developer_facing_descriptions.append("%s:%s" % [module.id, backstage_term])
				break
	_check(
		incomplete_descriptions.is_empty(),
		"所有球都使用完整句说明触发、过程和结果，不再用关键词链代替介绍：%s"
			% ", ".join(incomplete_descriptions)
	)
	_check(
		corrupted_descriptions.is_empty(),
		"所有球的能力介绍都没有替换字符、双重编码或其他常见乱码：%s"
			% ", ".join(corrupted_descriptions)
	)
	_check(
		unstructured_descriptions.is_empty(),
		"所有长能力介绍都按摘要、空行和项目符号统一分段：%s"
			% ", ".join(unstructured_descriptions)
	)
	_check(
		developer_facing_descriptions.is_empty(),
		"所有球简介只向观众讲能力规则，不出现配置、实现或内部判定口吻：%s"
			% ", ".join(developer_facing_descriptions)
	)
	_check(
		tuning_descriptions.is_empty(),
		"所有球简介不写冷却、伤害、时长、范围、概率等可调数值：%s"
			% ", ".join(tuning_descriptions)
	)
	_check(
		presentation_descriptions.is_empty(),
		"所有球简介不代替画面讲特效、配色、动画、音效或语音：%s"
			% ", ".join(presentation_descriptions)
	)
	_check(
		BallModule.ability_text_looks_corrupted("bad%sencoding" % String.chr(0x0081)),
		"能力介绍乱码守卫可以识别常见 UTF-8 双重编码文本"
	)
	_check(
		BallModule.ability_text_looks_corrupted("敌%s方" % String.chr(0x200b)),
		"能力介绍乱码守卫可以识别会触发缺字框的零宽排版字符"
	)
	_check(
		BallModule.ability_text_contains_tuning_details("每 3 秒造成 8 点伤害"),
		"能力介绍守卫可以识别具体冷却与伤害数值"
	)
	_check(
		BallModule.ability_text_contains_presentation_details("发动时播放语音并出现发光动画"),
		"能力介绍守卫可以识别画面与声音表现说明"
	)
	var spider_description: String = BallRegistry.get_module("spider_web").formatted_ability_description()
	var ui_font := CjkFontProviderScript.font()
	var missing_font_characters := CjkFontProviderScript.missing_characters(
		CjkFontProviderScript.validation_source(BallRegistry.modules())
	)
	_check(ui_font is SystemFont, "项目 UI 使用可指定中文字体族的 SystemFont")
	_check(ui_font.has_char("敌".unicode_at(0)), "项目 UI 字体明确覆盖曾经显示成方框的‘敌’字")
	_check(
		missing_font_characters.is_empty(),
		"项目 UI 字体覆盖全部球名和能力简介字符：%s" % missing_font_characters
	)
	_check(
		BallModule.sanitize_ability_text(spider_description) == spider_description,
		"蜘蛛网原始文案不含零宽空格、字节序标记等不可见排版字符"
	)
	dialog.call("_show_detail", "spider_web")
	await process_frame
	var detail_label := dialog.find_child("BallAbilityDescription", true, false) as Label
	_check(
		dialog.current_description() == spider_description,
		"蜘蛛网能力详情逐字使用纯净观众文案，不再额外拼接字体运行"
	)
	_check(
		detail_label != null and detail_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"中文简介使用 Unicode 智能换行，不再修改文本内容来强制断行"
	)
	_check(
		detail_label != null
			and detail_label.get_theme_font("font") == ui_font
			and detail_label.get_theme_font("font").has_char("敌".unicode_at(0)),
		"蜘蛛网详情实际继承完整中文 UI 字体，不再依赖缺字的 Godot 默认字体"
	)
	_check(
		spider_description.contains("\n• 敌方")
			and spider_description.contains("\n• 黑洞"),
		"蜘蛛网简介保留清晰的项目符号分条"
	)
	_check(
		BallRegistry.get_module("spider_web").settings_snapshot()["ability_description"]
			== BallRegistry.get_module("spider_web").ability_description,
		"球参数快照持久化原始观众简介，不注入字体规避字符"
	)
	var repeated_switch_is_clean := true
	for _pass in range(4):
		for module: BallModule in BallRegistry.modules():
			dialog.call("_show_detail", module.id)
			var expected := module.formatted_ability_description()
			if dialog.current_description() != expected \
					or BallModule.sanitize_ability_text(dialog.current_description()) != dialog.current_description():
				repeated_switch_is_clean = false
				break
	_check(repeated_switch_is_clean, "同一进程反复切换全部球简介后文本仍逐字纯净")
	_check(dialog.card_count() == BallRegistry.ids().size(), "球库按注册表自动罗列全部球卡片")
	var selected_card = dialog.card_for_id("vampire")
	_check(selected_card != null and bool(selected_card.call("is_selected_card")), "当前球卡片具有明确选中态")
	_check(selected_card != null and selected_card.call("preview_visual") is BallVisual, "卡片直接装载球自己的 BallVisual 模型")
	if selected_card != null:
		var copy_button := selected_card.call("copy_button") as Button
		_check(
			copy_button != null and copy_button.size.x >= 34.0 and copy_button.size.y >= 34.0,
			"每张球卡片右下角提供可点击、可聚焦的简介复制按钮"
		)
		_check(
			copy_button != null
				and copy_button.position.x > selected_card.size.x * 0.5
				and copy_button.position.y > selected_card.size.y * 0.5,
			"简介复制按钮稳定放在卡片右下角"
		)
		_check(
			copy_button != null
				and copy_button.focus_mode == Control.FOCUS_ALL
				and copy_button.tooltip_text.contains("复制"),
			"图标复制按钮支持键盘焦点并有明确悬浮说明"
		)
		var copied := {"id": "", "description": ""}
		selected_card.connect("description_copied", func(ball_id: String, description: String) -> void:
			copied["id"] = ball_id
			copied["description"] = description
		)
		copy_button.pressed.emit()
		await process_frame
		_check(
			String(copied["id"]) == "vampire"
				and String(copied["description"]) == BallRegistry.get_module("vampire").formatted_ability_description(),
			"复制按钮复制当前持久化配置对应的完整分段简介"
		)
		_check(
			BallModule.sanitize_ability_text(String(copied["description"])) == String(copied["description"]),
			"复制内容不包含零宽空格、字节序标记等不可见排版字符"
		)
		_check(String(picked["id"]).is_empty() and dialog.visible, "复制简介不会误触卡片选球或关闭弹窗")
	else:
		_check(false, "吸血鬼卡片存在并可验证简介复制交互")

	var hovered_card = dialog.card_for_id("black_hole")
	if hovered_card != null:
		hovered_card.mouse_entered.emit()
		await process_frame
		_check(
			dialog.current_description()
				== BallRegistry.get_module("black_hole").formatted_ability_description(),
			"鼠标悬浮卡片时展示该球真实能力说明"
		)
	else:
		_check(false, "黑洞球卡片存在于完整球库")

	var search_input := dialog.find_child("BallSearchInput", true, false) as LineEdit
	search_input.text = "黑洞"
	search_input.text_changed.emit(search_input.text)
	await process_frame
	_check(dialog.visible_card_count() == 1, "球库支持按中文球名即时筛选")
	var filtered_card = dialog.card_for_id("black_hole")
	_check(filtered_card != null, "筛选结果保留匹配球的完整卡片")
	if filtered_card != null:
		filtered_card.call("activate")
	await process_frame
	_check(String(picked["id"]) == "black_hole", "点击卡片提交稳定球 ID")
	_check(not dialog.visible, "选中球后弹窗自动关闭")

	dialog.open_picker("black_hole", "右侧")
	await process_frame
	search_input.text = "没有这个球"
	search_input.text_changed.emit(search_input.text)
	await process_frame
	_check(dialog.visible_card_count() == 0, "无匹配搜索结果不会显示错误卡片")
	var empty_state := dialog.find_child("BallPickerEmptyState", true, false) as Label
	_check(empty_state.visible, "无匹配搜索结果显示明确空状态")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var settings_source := FileAccess.get_file_as_string("res://scripts/ui/ball_settings_dialog.gd")
	_check(main_source.contains("BallPickerDialogScript"), "主界面所有玩法通过通用卡片球库选择参战球")
	_check(main_source.contains("ball_picker_requested.connect"), "球参数页接入主界面已有的卡片式球库")
	_check(main_source.contains('"action": "settings"'), "卡片式球库能把选择结果路由回球参数页")
	_check(not settings_source.contains("OptionButton"), "球参数页源码不再维护独立下拉选球实现")
	_check(main_source.contains("ModeRosterEditorScript"), "本局阵容编辑器直接接入主界面")
	_check(main_source.contains("_on_roster_add_requested"), "多人玩法从主界面提供明确的加球入口")
	_check(not main_source.contains("BattleSetupDialogScript"), "主界面不再保留另一套设置阵容弹窗")
	_check(not main_source.contains("设置阵容"), "主界面不再要求进入额外阵容弹窗")
	var picker_entry_source := main_source.get_slice("func _open_roster_ball_picker", 1).get_slice("func _ensure_ball_picker_dialog", 0)
	_check(not picker_entry_source.contains("battle_mode != BattleSetupScript.MODE_DUEL"), "卡片球库不会在非单挑玩法被入口短路")
	_check(main_source.contains("_store_current_mode_rosters()"), "切走玩法前保留该玩法当前阵容")
	_check(main_source.contains("_load_current_mode_rosters()"), "切回玩法时恢复该玩法自己的阵容")
	_check(not main_source.contains("_reset_default_rosters"), "切换玩法不再无条件销毁已编辑阵容")
	_check(main_source.contains("_current_roster_limit()"), "主界面加球遵守当前玩法可生成的合法阵容上限")
	_check(not main_source.contains("func _make_selector"), "主界面不再使用随球数增长的长下拉选择器")
	var cancelled := {"value": false}
	dialog.picker_cancelled.connect(func() -> void:
		cancelled["value"] = true
	)
	var close_button := dialog.find_child("BallPickerCloseButton", true, false) as Button
	close_button.pressed.emit()
	await process_frame
	_check(bool(cancelled["value"]), "取消卡片选择会通知调用页恢复原有配置窗口")
	_check(not dialog.visible, "取消卡片选择后球库关闭")
	dialog.queue_free()
	await process_frame

func _check_mode_roster_editor() -> void:
	var editor = ModeRosterEditorScript.new()
	editor.size = Vector2(388.0, 659.0)
	get_root().add_child(editor)
	await process_frame
	_check(editor.size.x <= 388.0, "阵容编辑器可收缩到左侧配置栏宽度，不再写死 650 px")
	var requested := {"action": "", "team": -1, "index": -1, "direction": 0}
	editor.add_ball_requested.connect(func(team_index: int) -> void:
		requested["action"] = "add"
		requested["team"] = team_index
		requested["index"] = -1
		requested["direction"] = 0
	)
	editor.replace_ball_requested.connect(func(team_index: int, roster_index: int) -> void:
		requested["action"] = "replace"
		requested["team"] = team_index
		requested["index"] = roster_index
		requested["direction"] = 0
	)
	editor.move_ball_requested.connect(func(team_index: int, roster_index: int, direction: int) -> void:
		requested["action"] = "move"
		requested["team"] = team_index
		requested["index"] = roster_index
		requested["direction"] = direction
	)
	editor.add_team_requested.connect(func() -> void:
		requested["action"] = "add_team"
		requested["team"] = -1
		requested["index"] = -1
		requested["direction"] = 0
	)
	editor.team_name_changed.connect(func(team_index: int, display_name: String) -> void:
		requested["action"] = "rename"
		requested["team"] = team_index
		requested["name"] = display_name
	)
	editor.configure(BattleSetup.MODE_RELAY, [["vampire", "black_hole"], ["wdc"]], ["先锋队", "守擂队"])
	await process_frame
	var red_team_name := editor.find_child("RosterTeamName_0", true, false) as LineEdit
	var blue_team_name := editor.find_child("RosterTeamName_1", true, false) as LineEdit
	_check(red_team_name != null and red_team_name.text == "先锋队" and red_team_name.get_theme_color("font_color") == BattleSetup.RELAY_RED_TEAM_COLOR, "擂台配置栏可编辑左队名称但仍使用红色标识")
	_check(blue_team_name != null and blue_team_name.text == "守擂队" and blue_team_name.get_theme_color("font_color") == BattleSetup.RELAY_BLUE_TEAM_COLOR, "擂台配置栏可编辑右队名称但仍使用蓝色标识")
	_check(red_team_name != null and red_team_name.max_length == BattleSetup.MAX_TEAM_NAME_LENGTH and red_team_name.tooltip_text.contains("留空"), "阵营名称输入提供长度边界和恢复默认提示")
	red_team_name.text = "疾风盟"
	red_team_name.text_submitted.emit(red_team_name.text)
	_check(requested.get("action") == "rename" and requested.get("team") == 0 and requested.get("name") == "疾风盟", "阵营名称提交稳定携带队伍索引与规范化名称")
	var roster_scroll := editor.find_child("ModeRosterScroll", true, false) as ScrollContainer
	_check(
		roster_scroll != null and roster_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"阵容区彻底禁用横向滚动"
	)
	var first_team_balls := editor.find_child("RosterBalls_0", true, false) as VBoxContainer
	_check(first_team_balls != null and first_team_balls.get_child_count() == 2, "同队球使用纵向列表承载")
	var first_ball_chip := editor.find_child("RosterChip_0_0", true, false) as Control
	var second_ball_chip := editor.find_child("RosterChip_0_1", true, false) as Control
	_check(
		first_ball_chip != null and second_ball_chip != null and second_ball_chip.position.y > first_ball_chip.position.y,
		"加球会向下撑开队伍分组，而不是向右延伸"
	)
	_check(editor.find_child("RosterTeamScroll_0", true, false) == null, "单队阵容不再创建横向滚动容器")
	var add_ball := editor.find_child("RosterAdd_0", true, false) as Button
	_check(add_ball != null and not add_ball.disabled, "擂台接力在队伍标题栏直接显示加球按钮")
	add_ball.pressed.emit()
	_check(requested["action"] == "add" and requested["team"] == 0, "加球按钮携带正确队伍上下文")
	var replace_ball := editor.find_child("RosterBall_0_1", true, false) as Button
	_check(replace_ball != null, "接力阵容中的每个球都可点击替换")
	replace_ball.pressed.emit()
	_check(requested["action"] == "replace" and requested["index"] == 1, "替换按钮携带正确阵容位置")
	var move_up := editor.find_child("RosterMoveUp_0_1", true, false) as Button
	_check(move_up != null and not move_up.disabled, "纵向有序阵容提供上移调整出场顺序的入口")
	move_up.pressed.emit()
	_check(requested["action"] == "move" and requested["direction"] == -1, "排序按钮发出稳定的移动方向")

	editor.configure(BattleSetup.MODE_FREE_FOR_ALL, [["vampire"], ["wdc"], ["test_ball"]], ["一队", "二队", "三队"])
	await process_frame
	var ffa_labels: Array[String] = []
	for team_index in range(3):
		var name_edit := editor.find_child("RosterTeamName_%d" % team_index, true, false) as LineEdit
		ffa_labels.append(name_edit.text if name_edit != null else "")
	_check(ffa_labels == ["一队", "二队", "三队"], "多方混战配置区为每个阵营提供独立名称输入")
	var add_team := editor.find_child("ModeAddTeamButton", true, false) as Button
	_check(add_team != null and add_team.visible and not add_team.disabled, "多方混战在主界面直接提供增加阵营入口")
	add_team.pressed.emit()
	_check(requested["action"] == "add_team", "新增阵营继续复用同一个卡片球库选择首球")

	editor.configure(BattleSetup.MODE_TEAM_BRAWL, [["vampire", "plant"], ["wdc", "garen"]], ["进攻方", "防守方"])
	await process_frame
	var brawl_red_header := editor.find_child("RosterTeamHeader_0", true, false) as HBoxContainer
	var brawl_blue_header := editor.find_child("RosterTeamHeader_1", true, false) as HBoxContainer
	_check(
		brawl_red_header != null and (brawl_red_header.get_child(0) as LineEdit).text == "进攻方"
		and brawl_blue_header != null and (brawl_blue_header.get_child(0) as LineEdit).text == "防守方",
		"双方大混战配置区与观众 HUD 共用自定义名称"
	)
	_check(editor.find_child("RosterAdd_1", true, false) != null, "双方大混战两边都能从主界面继续加球")
	var full_brawl_team: Array[String] = []
	for index in range(BattleSetup.MAX_ACTIVE_PER_TEAM):
		full_brawl_team.append("vampire" if index % 2 == 0 else "plant")
	editor.configure(BattleSetup.MODE_TEAM_BRAWL, [full_brawl_team, ["wdc"]])
	await process_frame
	var full_team_add := editor.find_child("RosterAdd_0", true, false) as Button
	_check(full_team_add != null and full_team_add.disabled, "双方大混战到同时上场上限后禁用加球，避免生成无效阵容")
	editor.configure(BattleSetup.MODE_DUEL, [["vampire"], ["wdc"]])
	await process_frame
	_check(editor.find_child("RosterBall_0_0", true, false) != null, "单挑也使用相同的外置阵容组件和卡片选球链路")
	_check(editor.find_child("RosterAdd_0", true, false) == null, "单挑固定每方一个球，不显示无意义的加球入口")
	_check(editor.find_child("RosterTeamName_0", true, false) == null, "单挑不提供阵营改名输入")
	var duel_header := editor.find_child("RosterTeamHeader_0", true, false) as HBoxContainer
	_check(duel_header != null and (duel_header.get_child(0) as Label).text == "左方", "单挑继续固定显示左右方")
	editor.queue_free()
	await process_frame

func _check_global_settings_dialog() -> void:
	var dialog = GlobalSettingsDialogScript.new()
	get_root().add_child(dialog)
	dialog.open_settings({
		"battle_time_seconds": 90,
		"arena_width": 10000,
		"arena_height": 10000,
		"recording_fps": 60,
	}, "多方混战", BattleSetup.MODE_FREE_FOR_ALL)
	await process_frame
	await process_frame
	_check(dialog.visible, "全局设置弹窗可以正常打开")
	_check(dialog.title.contains("多方混战") and dialog.title.contains("独立"), "全局设置弹窗明确标注当前玩法的独立配置档")
	var controls := dialog.find_children("*", "SpinBox", true, false)
	_check(controls.size() == GlobalGameSettingsScript.SETTING_SPECS.size(), "全局设置弹窗按 Schema 生成全部输入框")
	var scrolls := dialog.find_children("*", "ScrollContainer", true, false)
	var scroll := scrolls[0] as ScrollContainer if not scrolls.is_empty() else null
	var fields := scroll.get_child(0) as Control if scroll != null and scroll.get_child_count() > 0 else null
	_check(dialog.size.y < 900, "玩法配置首次打开不会被长表单撑成超高窗口")
	_check(
		scroll != null and fields != null and scroll.size.y < fields.size.y,
		"玩法配置首次打开就把长表单约束在滚动视口内"
	)
	_check(scroll != null and scroll.get_v_scroll_bar().visible, "玩法配置首次打开立即显示纵向滚动条")
	var arena_width := dialog.find_child("GlobalSetting_arena_width", true, false) as SpinBox
	var arena_height := dialog.find_child("GlobalSetting_arena_height", true, false) as SpinBox
	_check(arena_width != null and arena_width.value == 10000.0 and arena_width.max_value == 10000.0, "竞技场宽度按当前玩法配置")
	_check(arena_height != null and arena_height.value == 10000.0 and arena_height.max_value == 10000.0, "竞技场高度按当前玩法配置")

	dialog.hide()
	dialog.queue_free()
	await process_frame

func _check_damage_number_settings() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	view.damage_number_font_size = 38
	view.damage_number_duration_seconds = 1.8
	get_root().add_child(view)
	view.start_battle(20270134, "hero", "test_ball")
	view.simulation.damage(view.simulation.fighter_for_side(view.simulation.teams[1].team_id), 7.0, view.simulation.fighter_for_side(view.simulation.teams[0].team_id).accent, view.simulation.fighter_for_side(view.simulation.teams[0].team_id))
	var damage_text: Dictionary = view.simulation.floating_texts.back()
	_check(String(damage_text.get("kind", "")) == "damage", "本体伤害浮字具有稳定的伤害类型")
	_check(is_equal_approx(float(damage_text["duration"]), 1.8), "全局伤害数字停留时间进入本体伤害浮字")
	_check(view.call("_floating_text_font_size", damage_text) == 38, "全局伤害数字字号进入绘制参数")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).hp -= 10.0
	view.simulation.heal(view.simulation.fighter_for_side(view.simulation.teams[0].team_id), 5.0)
	var healing_text: Dictionary = view.simulation.floating_texts.back()
	_check(view.call("_floating_text_font_size", healing_text) == BattleViewScript.DEFAULT_FLOATING_TEXT_FONT_SIZE, "伤害数字配置不会误改治疗数字")
	view.queue_free()
	await process_frame

func _check_replicator_dual_ring_view() -> void:
	var view: BattleView = BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle(20260906, "replicator", "test_ball")
	for _activation in range(22):
		view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
			view.simulation.battle_context,
			view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
			view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
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
	view.start_battle(20260831, "splitter", "test_ball")
	for _activation in range(40):
		view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).activate(
			view.simulation.battle_context,
			view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
			view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
			0
		)
	view.simulation._ability_for_fighter(view.simulation.fighter_for_side(view.simulation.teams[0].team_id)).after_entities_step(
		view.simulation.battle_context,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id),
		view.simulation.fighter_for_side(view.simulation.teams[1].team_id),
		0,
		0.0
	)
	view.queue_redraw()
	await process_frame
	await process_frame
	_check(view.simulation.count_entities(0, "splitter_clone") == 66, "66 个分身与 66 条细血条的真实绘制路径可执行")
	var clones: Array[BallEntity] = view.simulation.entity_list(0, "splitter_clone")
	var main_health_bounds := view.health_hud_bounds(0)
	var arena_bounds := view.arena_screen_rect()
	if clones.size() == 66:
		var first_bounds: Rect2 = clones[0].call("mini_health_bar_bounds", main_health_bounds)
		var second_bounds: Rect2 = clones[1].call("mini_health_bar_bounds", main_health_bounds)
		var last_bounds: Rect2 = clones[65].call("mini_health_bar_bounds", main_health_bounds)
		_check(first_bounds.position.y > main_health_bounds.end.y, "分身细血条固定显示在主球顶部大血条下方")
		_check(first_bounds.end.x <= arena_bounds.position.x, "左侧单列细血条位于碰撞区外的展示留白")
		_check(second_bounds.position.y > first_bounds.position.y, "每行固定排列一个分身细血条")
		_check(is_equal_approx(second_bounds.position.x, first_bounds.position.x), "分身细血条保持单列纵向对齐")
		_check(last_bounds.end.y < arena_bounds.end.y, "66 条分身细血条不会超出侧边展示空间")
		var fixed_bounds := first_bounds
		clones[0].pos = Vector2(600.0, 600.0)
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos = Vector2(520.0, 100.0)
		_check(clones[0].call("mini_health_bar_bounds", main_health_bounds) == fixed_bounds, "分身细血条位置不跟随主球或分身移动")
	view.queue_free()
	await process_frame

	var right_view: BattleView = BattleViewScript.new()
	right_view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(right_view)
	right_view.start_battle(20260901, "test_ball", "splitter")
	for _activation in range(2):
		right_view.simulation._ability_for_fighter(right_view.simulation.fighter_for_side(right_view.simulation.teams[1].team_id)).activate(
			right_view.simulation.battle_context,
			right_view.simulation.fighter_for_side(right_view.simulation.teams[1].team_id),
			right_view.simulation.fighter_for_side(right_view.simulation.teams[0].team_id),
			1
		)
	right_view.simulation._ability_for_fighter(right_view.simulation.fighter_for_side(right_view.simulation.teams[1].team_id)).after_entities_step(
		right_view.simulation.battle_context,
		right_view.simulation.fighter_for_side(right_view.simulation.teams[1].team_id),
		right_view.simulation.fighter_for_side(right_view.simulation.teams[0].team_id),
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
