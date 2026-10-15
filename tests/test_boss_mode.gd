extends SceneTree

const Setup := preload("res://scripts/simulation/battle_setup.gd")
const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
const View := preload("res://scripts/ui/battle_view.gd")
const Store := preload("res://scripts/settings/ball_settings_store.gd")
const GlobalStore := preload("res://scripts/settings/global_settings_store.gd")

class TestMain extends "res://scripts/main.gd":
	var settings_directory := ""
	func _ball_settings_path() -> String:
		return settings_directory.path_join("boss.json" if battle_mode == "boss" else "shared.json")

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	_check_matching_gameplay()
	await _check_isolated_settings_and_ui()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_BOSS_MODE_TESTS_OK")
		quit(0)
	else:
		for failure in failures: push_error("TEST FAILED: " + failure)
		quit(1)

func _check_matching_gameplay() -> void:
	var rosters := [["plant", "sonic"], ["yuri"], ["splitter"], ["sniper"]]
	var names := ["花园", "心灵", "双生", "猎手"]
	var standard = Setup.free_for_all(rosters, names)
	var boss = Setup.boss(rosters, names)
	_check(boss.is_valid() and boss.mode == Setup.MODE_BOSS, "BOSS 战有独立玩法 ID")
	_check(standard.teams == boss.teams, "BOSS 战完全复用多方混战的阵营、同时上场数和候补")
	_check(not Setup.boss([["plant"], ["yuri"]]).is_valid(), "BOSS 战沿用至少三个阵营的规则")
	var first := Simulation.new(920, standard, 12.0, Vector2(440.0, 740.0))
	var second := Simulation.new(920, boss, 12.0, Vector2(440.0, 740.0))
	for _frame in range(740):
		first.step(Simulation.FIXED_STEP)
		second.step(Simulation.FIXED_STEP)
	var second_snapshot := second.snapshot()
	second_snapshot["setup"]["mode"] = Setup.MODE_FREE_FOR_ALL
	_check(first.snapshot() == second_snapshot, "同配置同种子下 BOSS 与多方混战运动、伤害、结果和战报完全一致")
	_check(View.view_size_for_arena(Vector2(440, 740), 650.0, Setup.MODE_BOSS, [1, 1, 1, 1]) == View.view_size_for_arena(Vector2(440, 740), 650.0, Setup.MODE_FREE_FOR_ALL, [1, 1, 1, 1]), "BOSS 战沿用相同的响应式多方 HUD")
	_check(Store.settings_path_for_mode(Setup.MODE_BOSS) != Store.SETTINGS_PATH, "BOSS 球参数存储路径独立")
	for mode in Setup.SUPPORTED_MODES:
		if mode != Setup.MODE_BOSS:
			_check(Store.settings_path_for_mode(mode) == Store.SETTINGS_PATH, "其他玩法保留原通用球参数文件")

func _check_isolated_settings_and_ui() -> void:
	var directory := "user://boss_mode_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var shared_path := directory.path_join("shared.json")
	var boss_path := directory.path_join("boss.json")
	var global_path := directory.path_join("global.json")
	_check(Store.load_settings(boss_path).is_empty(), "BOSS 首次进入未保存时使用各球 Schema 默认值")
	_check(Store.save_settings({"plant": {"max_hp": 131.0}}, shared_path) == OK, "通用配置测试文件保存成功")
	_check(Store.save_settings({"plant": {"max_hp": 733.0}}, boss_path) == OK, "BOSS 配置测试文件保存成功")
	GlobalStore.save_mode_settings(Setup.MODE_FREE_FOR_ALL, {"arena_height": 440}, global_path)
	GlobalStore.save_mode_settings(Setup.MODE_BOSS, {"arena_height": 740}, global_path)
	_check(GlobalStore.load_mode_settings(Setup.MODE_FREE_FOR_ALL, global_path)["arena_height"] == 440 and GlobalStore.load_mode_settings(Setup.MODE_BOSS, global_path)["arena_height"] == 740, "BOSS 玩法设置也有独立持久化档案")
	var main := TestMain.new()
	main.settings_directory = directory
	root.add_child(main)
	main.battle_logger = null
	await process_frame
	_check(BallRegistry.get_module("plant").max_hp == 131.0, "普通启动加载通用球配置")
	_select_mode(main, Setup.MODE_BOSS)
	await process_frame
	_check(main.battle_view == null, "切换到 BOSS 不会自动开局")
	_check(BallRegistry.get_module("plant").max_hp == 733.0, "切换 BOSS 加载独立球参数")
	_check(main.mode_title_label.text == "BOSS 战", "BOSS 标题正确")
	_check(main.mode_roster_editor.find_child("ModeAddTeamButton", true, false).visible, "BOSS 阵容可添加阵营")
	main._ball_picker_request = {"action": "add_team"}
	main._on_ball_picker_selected("test_ball")
	_check(main.team_rosters.size() == 4, "BOSS 复用卡片选球后的添加阵营流程")
	main._on_remove_team_requested(3)
	_check(main.team_rosters.size() == 3, "BOSS 支持移除阵营并守住最少三队")
	main._on_ball_settings_submitted({"plant": {"max_hp": 919.0}})
	_check(Store.load_settings(shared_path)["plant"]["max_hp"] == 131.0, "保存 BOSS 配置不覆盖通用配置")
	_check(Store.load_settings(boss_path)["plant"]["max_hp"] == 919.0, "保存 BOSS 配置写入独立文件")
	main._open_ball_settings()
	_check(main.settings_dialog.title.contains("BOSS"), "球参数弹窗明确标识 BOSS 专用")
	main.settings_dialog.hide()
	_select_mode(main, Setup.MODE_FREE_FOR_ALL)
	_check(BallRegistry.get_module("plant").max_hp == 131.0, "退出 BOSS 恢复通用球参数")
	main._on_ball_settings_submitted({"plant": {"max_hp": 147.0}})
	_check(Store.load_settings(boss_path)["plant"]["max_hp"] == 919.0, "反向修改通用参数也不污染 BOSS")
	_select_mode(main, Setup.MODE_BOSS)
	_check(BallRegistry.get_module("plant").max_hp == 919.0, "返回 BOSS 恢复之前持久化的值")
	main.team_rosters = [["plant"], ["test_ball"], ["sonic"]]
	main._commit_roster_edit()
	main._start_selected_match()
	main.battle_view.paused = true
	_check(main.battle_view.simulation.battle_setup.mode == Setup.MODE_BOSS and main.battle_view.simulation.fighter_for_side(main.battle_view.simulation.teams[0].team_id).max_hp == 919.0, "真实 BOSS 开局注入隔离配置")
	_check(main.battle_view.result_auto_scroll, "BOSS 普通对局也启用自动战报")
	_check(main.battle_view.team_marker_presentations().size() == 3, "BOSS 主球都有多方阵营标识")
	main.queue_free()
	await process_frame
	var restarted := TestMain.new()
	restarted.settings_directory = directory
	restarted.battle_mode = Setup.MODE_BOSS
	root.add_child(restarted)
	restarted.battle_logger = null
	await process_frame
	_check(BallRegistry.get_module("plant").max_hp == 919.0, "重新启动 BOSS 时直接读取专用配置")
	restarted.queue_free()
	await process_frame
	for path in [shared_path, boss_path, global_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

func _select_mode(main, mode: String) -> void:
	for index in range(main.mode_selector.item_count):
		if String(main.mode_selector.get_item_metadata(index)) == mode:
			main.mode_selector.select(index)
			main._on_battle_mode_selected(index)
			return
	_check(false, "玩法列表中存在 " + mode)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
