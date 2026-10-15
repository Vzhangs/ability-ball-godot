extends SceneTree

const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const BattleViewScript := preload("res://scripts/ui/battle_view.gd")

class TeamMarkerAttachment:
	extends BallEntity

	func _init(spawn_owner_side: int, spawn_position: Vector2, spawn_radius: float) -> void:
		owner_side = spawn_owner_side
		pos = spawn_position
		radius = spawn_radius
		tags = PackedStringArray(["team_marker_test_attachment"])

	func team_marker_world_height() -> float:
		return radius

	func is_absorbable() -> bool:
		return true

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	await _check_duel_hides_team_markers()
	await _check_relay_visual_replacement()
	await _check_free_for_all_view()
	await _check_eight_team_hud_layout()
	await _check_team_brawl_view()
	await _check_team_brawl_capacity_layout()
	await _check_attachment_team_markers()
	if failures.is_empty():
		print("ABILITY_BALL_BATTLE_MODES_VIEW_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _check_duel_hides_team_markers() -> void:
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle_setup(
		20270828,
		BattleSetupScript.duel("test_ball", "sonic"),
		60.0,
		Vector2(640.0, 640.0)
	)
	_check(view.team_marker_presentations().is_empty(), "单挑保持无阵营三角的干净画面")
	view.queue_free()
	await process_frame

func _check_relay_visual_replacement() -> void:
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	view.result_reveal_delay_seconds = 0.1
	view.relay_handoff_pause_seconds = 0.2
	view.relay_defeat_text_font_size = 41
	get_root().add_child(view)
	view.start_battle_setup(
		20270829,
		BattleSetupScript.relay(
			["test_ball", "sonic", "plant"],
			["test_ball", "wdc", "black_hole"],
			["先锋队", "守擂队"]
		),
		60.0,
		Vector2(640.0, 640.0)
	)
	var duel_size := BattleViewScript.view_size_for_arena(Vector2(640.0, 640.0), BattleViewScript.DEFAULT_VIEW_SIZE.x)
	_check(view.size.y > duel_size.y, "擂台观众 HUD 为出阵队列增加独立顶部高度")
	_check(not view.health_hud_bounds(0).intersects(view.relay_timer_bounds()), "左方当前球血条不再挤占中央时间")
	_check(not view.health_hud_bounds(1).intersects(view.relay_timer_bounds()), "右方当前球血条不再挤占中央时间")
	_check(float(view.call("_origin").y) >= BattleViewScript.RELAY_HUD_BOTTOM + BattleViewScript.HUD_ARENA_GAP, "擂台顶部 HUD 与竞技场之间保留空隙")
	_check(view._roster_preview_visuals.size() == 6, "擂台观众 HUD 为双方完整出阵顺序创建缩小球模型")
	var relay_markers := view.team_marker_presentations()
	_check(relay_markers.size() == 2, "擂台为双方当前主球各显示一个阵营三角")
	if relay_markers.size() == 2:
		var relay_red: Color = relay_markers[0]["color"]
		var relay_blue: Color = relay_markers[1]["color"]
		_check(relay_red.is_equal_approx(BattleSetupScript.RELAY_RED_TEAM_COLOR), "擂台红队主球使用红色阵营标识")
		_check(relay_blue.is_equal_approx(BattleSetupScript.RELAY_BLUE_TEAM_COLOR), "擂台蓝队主球使用蓝色阵营标识")
	_check(view.relay_roster_slot_state(0, 0) == "active" and view.relay_roster_slot_state(0, 1) == "next", "初始出阵队列高亮当前球和下一位")
	var red_first := view.relay_roster_slot_bounds(0, 0).get_center()
	var red_second := view.relay_roster_slot_bounds(0, 1).get_center()
	var red_third := view.relay_roster_slot_bounds(0, 2).get_center()
	var blue_first := view.relay_roster_slot_bounds(1, 0).get_center()
	var blue_second := view.relay_roster_slot_bounds(1, 1).get_center()
	var blue_third := view.relay_roster_slot_bounds(1, 2).get_center()
	var red_area: Rect2 = view.call("_relay_roster_area", 0)
	var blue_area: Rect2 = view.call("_relay_roster_area", 1)
	_check(red_first.x < red_second.x and red_second.x < red_third.x, "红队出阵模型从左侧向中央依次排列")
	_check(blue_first.x > blue_second.x and blue_second.x > blue_third.x, "蓝队出阵模型从右侧向中央依次排列")
	_check(
		red_second.x - red_first.x >= BattleViewScript.RELAY_ROSTER_MAX_PITCH - 0.01
		and blue_first.x - blue_second.x >= BattleViewScript.RELAY_ROSTER_MAX_PITCH - 0.01,
		"擂台小球列表为相邻模型增加清晰间距"
	)
	_check(
		view.relay_timer_bounds().position.x - red_area.end.x >= BattleViewScript.RELAY_ROSTER_CENTER_GAP * 0.5 - 0.01
		and blue_area.position.x - view.relay_timer_bounds().end.x >= BattleViewScript.RELAY_ROSTER_CENTER_GAP * 0.5 - 0.01,
		"红蓝出阵列表与中央计时器之间保留额外空隙"
	)
	_check(
		is_equal_approx(view.relay_roster_model_radius(0, 0), 11.5 * BattleViewScript.RELAY_ROSTER_MODEL_SCALE),
		"常规擂台阵容的缩小球模型按 15% 放大"
	)
	var first_name_bounds := view.relay_roster_slot_name_bounds(0, 0)
	var first_model_radius := view.relay_roster_model_radius(0, 0)
	var first_model_center_y := view.relay_roster_slot_bounds(0, 0).position.y + first_model_radius + 3.0
	_check(
		view.relay_roster_slot_display_name(0, 0) == "测试球"
		and first_name_bounds.position.y > first_model_center_y + first_model_radius,
		"擂台候选球在模型正下方显示真实球名"
	)
	_check(red_third.x < red_area.get_center().x and blue_third.x > blue_area.get_center().x, "少量出阵球保持两侧紧凑，不再平均铺满各自半区")
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).hp = 73.0
	var current_left = view.relay_current_hud_fighter(0)
	_check(current_left == view.simulation.fighter_for_side(view.simulation.teams[0].team_id) and is_equal_approx(current_left.hp, 73.0), "擂台血条读取当前上场球而非整队累计生命")
	_check(view.simulation.team_remaining_hp(view.simulation.teams[0]) > current_left.hp, "测试阵容确实还含候补生命，防止总血量伪装成当前血量")
	var old_uid: int = view.simulation.fighter_for_side(view.simulation.teams[0].team_id).fighter_uid
	var survivor = view.simulation.fighter_for_side(view.simulation.teams[1].team_id)
	var survivor_visual = view.fighter_visuals[survivor.fighter_uid]
	view.simulation.damage(view.simulation.fighter_for_side(view.simulation.teams[0].team_id), view.simulation.fighter_for_side(view.simulation.teams[0].team_id).hp, view.simulation.fighter_for_side(view.simulation.teams[1].team_id).accent, view.simulation.fighter_for_side(view.simulation.teams[1].team_id))
	view.simulation.call("_check_finish")
	view._process(0.0)
	_check(view.relay_roster_slot_state(0, 0) == "defeated" and view.relay_roster_slot_state(0, 1) == "next", "落败后观众队列把旧球标为失败并保留下一位提示")
	var notices: Array[Dictionary] = view.call("_relay_notice_entries")
	_check(notices.size() == 1 and String(notices[0].get("next_ball_id", "")) == "sonic", "落败停顿生成落败球与下一位的文字提示数据")
	_check(notices.size() == 1 and view.relay_defeat_notice_text(notices[0]) == "先锋队·测试球落败", "场内落败提示使用当前自定义阵营名")
	var initial_presentation: Dictionary = view.relay_defeat_notice_presentation()
	_check(int(initial_presentation["font_size"]) == 41 and is_equal_approx(float(initial_presentation["alpha"]), 1.0), "擂台落败悬浮文字使用玩法配置字号并以不透明状态弹出")
	_check(is_equal_approx(view.simulation.replacement_pause_remaining(), 0.2), "视图把当前玩法的擂台停顿配置注入模拟器")
	var paused_hud_fighter = view.relay_current_hud_fighter(0)
	_check(paused_hud_fighter != null and is_equal_approx(paused_hud_fighter.hp, 0.0), "换人停顿时血条仍只呈现刚落败的当前球，不合并候补血量")
	_check(not view.fighter_visuals.has(old_uid), "擂台换人后旧主球视觉实例被精确移除")
	_check(view.fighter_visuals.size() == 1 and view.fighter_visuals.has(survivor.fighter_uid), "败者演出期间场上只绘制原幸存球")
	var death_effects := view.simulation.entity_list(0, "fighter_death_vfx")
	_check(death_effects.size() == 1 and not death_effects[0].draws_above_balls(), "擂台败者演出固定在幸存敌球下方")
	for _frame in range(3):
		view.simulation.step(0.05)
	var fading_presentation: Dictionary = view.relay_defeat_notice_presentation()
	_check(float(fading_presentation["alpha"]) > 0.0 and float(fading_presentation["alpha"]) < 1.0 and float(fading_presentation["rise"]) > 0.0, "落败文字在停顿后段一边上浮一边渐隐")
	var handoff_frames := 0
	while not view.simulation.snapshot()["pending_replacements"].is_empty() and handoff_frames < 30:
		view.simulation.step(BattleSimulation.FIXED_STEP)
		handoff_frames += 1
	view._process(0.0)
	_check(handoff_frames < 30, "擂台视觉在死亡演出时限内切换到候补")
	_check(view.fighter_visuals.has(view.simulation.fighter_for_side(view.simulation.teams[0].team_id).fighter_uid), "擂台候补球按新球模块创建对应视觉")
	_check(view.relay_roster_slot_state(0, 0) == "defeated" and view.relay_roster_slot_state(0, 1) == "active", "候补登场后观众队列切换当前高亮并保留落败叉号")
	_check(view.left_visual == view.fighter_visuals[view.simulation.fighter_for_side(view.simulation.teams[0].team_id).fighter_uid], "二队兼容视觉投影随候补球同步更新")
	_check(view.simulation.fighter_for_side(view.simulation.teams[1].team_id) == survivor and view.fighter_visuals[survivor.fighter_uid] == survivor_visual, "擂台换人保留敌方主球及其原视觉实例")
	_check(view.simulation.entity_list(0, "fighter_death_vfx").is_empty(), "死亡演出结束后才显示候补球")
	view.queue_redraw()
	await process_frame
	await process_frame
	view.queue_free()
	await process_frame

func _check_free_for_all_view() -> void:
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle_setup(
		20270830,
		BattleSetupScript.free_for_all([["vampire"], ["plant"], ["sniper"]], ["血族", "花园", "猎手"]),
		60.0,
		Vector2(700.0, 620.0)
	)
	_check(view.fighter_visuals.size() == 3, "三方混战装载三个独立球体视觉")
	var markers := view.team_marker_presentations()
	_check(markers.size() == 3, "三方混战为每个主球生成阵营标识")
	if markers.size() == 3:
		var first_color: Color = markers[0]["color"]
		var second_color: Color = markers[1]["color"]
		var third_color: Color = markers[2]["color"]
		_check(
			not first_color.is_equal_approx(second_color)
			and not first_color.is_equal_approx(third_color)
			and not second_color.is_equal_approx(third_color),
			"多方混战的前三个阵营使用互相可辨的颜色"
		)
	_check(
		view.simulation.teams[0].display_name == "血族"
		and view.simulation.teams[1].display_name == "花园"
		and view.simulation.teams[2].display_name == "猎手",
		"多方混战观众 HUD 使用每队自定义名称"
	)
	var row_bounds: Array[Rect2] = []
	for team_index in range(3):
		var fighters := view.compact_hud_fighters_for_team(team_index)
		_check(fighters.size() == 1, "多方混战每个阵营公开一颗独立 HUD 主球")
		var row := view.compact_hud_row_bounds(team_index, 0)
		var bar := view.compact_hud_health_bar_bounds(team_index, 0)
		row_bounds.append(row)
		_check(_rect_inside(row, Rect2(Vector2.ZERO, view.size)), "三方混战逐球 HUD 完整收在战斗视图内")
		_check(_rect_inside(bar, row), "三方混战细血条与球名共用同一水平行")
		_check(is_equal_approx(bar.size.y, BattleViewScript.MULTI_HUD_BAR_HEIGHT) and bar.size.y < BattleViewScript.HEALTH_BAR_HEIGHT, "混战逐球血条比单挑血条更细更小")
		_check(row.end.y < view.arena_screen_rect().position.y, "三方混战逐球 HUD 不侵入竞技场")
	for first_index in range(row_bounds.size()):
		for second_index in range(first_index + 1, row_bounds.size()):
			_check(not row_bounds[first_index].intersects(row_bounds[second_index]), "三方混战每颗球独占一行且互不覆盖")
	_check(not view.multi_timer_bounds().intersects(row_bounds[0]), "多方混战时间区与逐球血条分离")
	view.simulation.step(BattleSimulation.FIXED_STEP)
	view.queue_redraw()
	await process_frame
	await process_frame
	view.queue_free()
	await process_frame

func _check_team_brawl_view() -> void:
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle_setup(
		20270831,
		BattleSetupScript.team_brawl(["wind_swordsman", "splitter"], ["heavy_industry", "chess"], ["疾风队", "重装队"]),
		60.0,
		Vector2(720.0, 640.0)
	)
	_check(view.fighter_visuals.size() == 4, "双方大混战同帧绘制全部四个主球")
	var markers := view.team_marker_presentations()
	_check(markers.size() == 4, "双方大混战为全部四个主球生成阵营标识")
	if markers.size() == 4:
		var red_count := 0
		var blue_count := 0
		for marker in markers:
			var marker_color: Color = marker["color"]
			if marker_color.is_equal_approx(BattleSetupScript.RELAY_RED_TEAM_COLOR):
				red_count += 1
			elif marker_color.is_equal_approx(BattleSetupScript.RELAY_BLUE_TEAM_COLOR):
				blue_count += 1
		_check(red_count == 2 and blue_count == 2, "双方大混战同队主球共享红蓝阵营色")
	_check(view.simulation.teams[0].display_name == "疾风队" and view.simulation.teams[1].display_name == "重装队", "双方大混战观众 HUD 使用当前自定义阵营名")
	for team_index in range(2):
		var fighters := view.compact_hud_fighters_for_team(team_index)
		_check(fighters.size() == 2, "双方大混战每颗参战球保留独立 HUD 数据")
		for fighter_index in range(fighters.size()):
			var row := view.compact_hud_row_bounds(team_index, fighter_index)
			var bar := view.compact_hud_health_bar_bounds(team_index, fighter_index)
			_check(_rect_inside(row, Rect2(Vector2.ZERO, view.size)), "双方大混战逐球行完整收在战斗视图内")
			_check(_rect_inside(bar, row), "双方大混战球名与细血条位于同一行")
			_check(row.end.y < view.arena_screen_rect().position.y, "双方大混战顶部 HUD 与竞技场保留间距")
	view.simulation.step(BattleSimulation.FIXED_STEP)
	view.queue_redraw()
	await process_frame
	await process_frame
	view.queue_free()
	await process_frame

func _check_eight_team_hud_layout() -> void:
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle_setup(
		20270833,
		BattleSetupScript.free_for_all([
			["test_ball"], ["test_ball"], ["test_ball"], ["test_ball"],
			["test_ball"], ["test_ball"], ["test_ball"], ["test_ball"],
		]),
		60.0,
		Vector2(760.0, 660.0)
	)
	_check(view.fighter_visuals.size() == 8, "八方上限仍为每个阵营创建独立主球视觉")
	var view_bounds := Rect2(Vector2.ZERO, view.size)
	for first_index in range(8):
		var first_bounds := view.compact_hud_row_bounds(first_index, 0)
		_check(_rect_inside(first_bounds, view_bounds), "八方 HUD 的队伍 %d 完整位于战斗视图内" % (first_index + 1))
		for second_index in range(first_index + 1, 8):
			var second_bounds := view.compact_hud_row_bounds(second_index, 0)
			_check(not first_bounds.intersects(second_bounds), "八方 HUD 的队伍 %d 与 %d 不重叠" % [first_index + 1, second_index + 1])
	var expected_hud_bottom := BattleViewScript.hud_panel_bottom_for_mode(BattleSetupScript.MODE_FREE_FOR_ALL, [1, 1, 1, 1, 1, 1, 1, 1])
	_check(float(view.call("_origin").y) >= expected_hud_bottom + BattleViewScript.HUD_ARENA_GAP, "八方四排逐球 HUD 与竞技场仍保留固定空隙")
	view.queue_redraw()
	await process_frame
	await process_frame
	view.queue_free()
	await process_frame

func _check_team_brawl_capacity_layout() -> void:
	var full_roster: Array[String] = []
	for _index in range(BattleSetupScript.MAX_ACTIVE_PER_TEAM):
		full_roster.append("test_ball")
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle_setup(
		20270835,
		BattleSetupScript.team_brawl(full_roster, full_roster),
		60.0,
		Vector2(440.0, 440.0)
	)
	var all_rows: Array[Rect2] = []
	var view_bounds := Rect2(Vector2.ZERO, view.size)
	for team_index in range(2):
		var fighters := view.compact_hud_fighters_for_team(team_index)
		_check(fighters.size() == BattleSetupScript.MAX_ACTIVE_PER_TEAM, "双方大混战上限阵容仍为每颗主球创建独立 HUD 行")
		for fighter_index in range(fighters.size()):
			var row := view.compact_hud_row_bounds(team_index, fighter_index)
			var bar := view.compact_hud_health_bar_bounds(team_index, fighter_index)
			all_rows.append(row)
			_check(_rect_inside(row, view_bounds), "双方各 16 球时逐球 HUD 不越出战斗视图")
			_check(_rect_inside(bar, row), "双方各 16 球时细血条仍留在所属球名行内")
			_check(row.end.y <= view.arena_screen_rect().position.y - BattleViewScript.HUD_ARENA_GAP, "双方各 16 球时 HUD 不压住竞技场")
	for first_index in range(all_rows.size()):
		for second_index in range(first_index + 1, all_rows.size()):
			_check(not all_rows[first_index].intersects(all_rows[second_index]), "双方各 16 球时所有逐球行互不覆盖")
	view.queue_free()
	await process_frame

func _check_attachment_team_markers() -> void:
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle_setup(
		20270834,
		BattleSetupScript.team_brawl(["test_ball"], ["sonic"]),
		60.0,
		Vector2(640.0, 640.0)
	)
	var attachment := TeamMarkerAttachment.new(
		0,
		view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos + Vector2(0.0, 90.0),
		12.0
	)
	view.simulation.add_entity(attachment)
	var markers := view.team_marker_presentations()
	var attachment_marker := _find_marker(markers, "attachment", attachment.get_instance_id())
	var main_marker := _find_marker(markers, "fighter", view.simulation.fighter_for_side(view.simulation.teams[0].team_id).fighter_uid)
	_check(not attachment_marker.is_empty(), "可作战附属单位接入通用小型阵营标识")
	_check(not main_marker.is_empty(), "附属单位测试仍保留所属主球阵营标识")
	if not attachment_marker.is_empty() and not main_marker.is_empty():
		_check(
			float(attachment_marker["width"]) < float(main_marker["width"])
			and float(attachment_marker["height"]) < float(main_marker["height"]),
			"附属单位阵营三角明确小于主球三角"
		)
		var attachment_color: Color = attachment_marker["color"]
		var main_color: Color = main_marker["color"]
		_check(attachment_color.is_equal_approx(main_color), "附属单位与所属主球共享阵营颜色")
		var initial_tip: Vector2 = attachment_marker["tip"]
		view.simulation.elapsed += 0.18
		var moved_marker := _find_marker(
			view.team_marker_presentations(),
			"attachment",
			attachment.get_instance_id()
		)
		_check(
			not moved_marker.is_empty()
			and not is_equal_approx(initial_tip.y, (moved_marker["tip"] as Vector2).y),
			"阵营三角随对局时间持续上下浮动"
		)
	attachment.owner_side = 1
	var controlled_marker := _find_marker(
		view.team_marker_presentations(),
		"attachment",
		attachment.get_instance_id()
	)
	if not controlled_marker.is_empty():
		var controlled_color: Color = controlled_marker["color"]
		_check(controlled_color.is_equal_approx(BattleSetupScript.RELAY_BLUE_TEAM_COLOR), "附属单位转移阵营后标识立即切换为新阵营色")
	else:
		_check(false, "附属单位转移阵营后仍保留阵营标识")
	attachment.disable_for_capture()
	_check(
		_find_marker(
			view.team_marker_presentations(),
			"attachment",
			attachment.get_instance_id()
		).is_empty(),
		"被黑洞捕获并停用的附属单位隐藏阵营标识"
	)
	var triangle := BattleViewScript._team_marker_triangle_points(Vector2(20.0, 30.0), 12.0, 8.0)
	_check(
		triangle.size() == 3
		and triangle[2].y > triangle[0].y
		and triangle[2].y > triangle[1].y,
		"阵营标识三角尖端固定向下指向所属单位"
	)
	view.queue_free()
	await process_frame

func _find_marker(
	markers: Array[Dictionary],
	kind: String,
	subject_id: int
) -> Dictionary:
	for marker in markers:
		if String(marker.get("kind", "")) == kind and int(marker.get("subject_id", -1)) == subject_id:
			return marker
	return {}

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
