extends SceneTree

const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const BallSettingsDialogScript := preload("res://scripts/ui/ball_settings_dialog.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const GlobalSettingsDialogScript := preload("res://scripts/ui/global_settings_dialog.gd")

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
	_check_sonic_visual_policy()
	await _check_wind_swordsman_view()
	await _check_yuri_view()
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
		"res://scripts/balls/six_king/anchor_entity.gd",
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
