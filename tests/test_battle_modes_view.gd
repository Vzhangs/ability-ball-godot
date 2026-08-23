extends SceneTree

const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const BattleViewScript := preload("res://scripts/ui/battle_view.gd")

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	await _check_relay_visual_replacement()
	await _check_free_for_all_view()
	await _check_eight_team_hud_layout()
	await _check_team_brawl_view()
	if failures.is_empty():
		print("ABILITY_BALL_BATTLE_MODES_VIEW_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _check_relay_visual_replacement() -> void:
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	get_root().add_child(view)
	view.start_battle_setup(
		20270829,
		BattleSetupScript.relay(["test_ball", "laser"], ["test_ball", "wdc"]),
		60.0,
		Vector2(640.0, 640.0)
	)
	var old_uid: int = view.simulation.left.fighter_uid
	view.simulation.damage(view.simulation.left, view.simulation.left.hp, view.simulation.right.accent, view.simulation.right)
	view.simulation.call("_check_finish")
	view._process(0.0)
	_check(not view.fighter_visuals.has(old_uid), "擂台换人后旧主球视觉实例被精确移除")
	_check(view.fighter_visuals.has(view.simulation.left.fighter_uid), "擂台候补球按新球模块创建对应视觉")
	_check(view.left_visual == view.fighter_visuals[view.simulation.left.fighter_uid], "二队兼容视觉投影随候补球同步更新")
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
		BattleSetupScript.free_for_all([["vampire"], ["plant"], ["sniper"]]),
		60.0,
		Vector2(700.0, 620.0)
	)
	_check(view.fighter_visuals.size() == 3, "三方混战装载三个独立球体视觉")
	var first_bounds: Rect2 = view.call("_team_hud_bounds", 0, 3)
	var second_bounds: Rect2 = view.call("_team_hud_bounds", 1, 3)
	var third_bounds: Rect2 = view.call("_team_hud_bounds", 2, 3)
	_check(not first_bounds.intersects(second_bounds) and not second_bounds.intersects(third_bounds), "多方阵营 HUD 分区互不覆盖")
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
		BattleSetupScript.team_brawl(["wind_swordsman", "splitter"], ["heavy_industry", "chess"]),
		60.0,
		Vector2(720.0, 640.0)
	)
	_check(view.fighter_visuals.size() == 4, "双方大混战同帧绘制全部四个主球")
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
	for first_index in range(8):
		var first_bounds: Rect2 = view.call("_team_hud_bounds", first_index, 8)
		for second_index in range(first_index + 1, 8):
			var second_bounds: Rect2 = view.call("_team_hud_bounds", second_index, 8)
			_check(not first_bounds.intersects(second_bounds), "八方 HUD 的队伍 %d 与 %d 不重叠" % [first_index + 1, second_index + 1])
	_check(float(view.call("_origin").y) >= BattleViewScript.HEALTH_PANEL_BOTTOM + BattleViewScript.HUD_ARENA_GAP, "八方双排 HUD 与竞技场仍保留固定空隙")
	view.queue_redraw()
	await process_frame
	await process_frame
	view.queue_free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
