extends SceneTree

const BattleLoggerScript := preload("res://scripts/logging/battle_logger.gd")
const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	var test_root := "user://ability_ball_logger_test_%d" % Time.get_ticks_usec()
	var logger: BattleLogger = BattleLoggerScript.new(test_root)
	var simulation := BattleSimulationScript.new(
		20261001,
		BattleSetupScript.relay(["vampire", "wind_swordsman"], ["wdc", "plant"], ["先锋队", "守擂队"]),
		0.1,
		Vector2(440.0, 440.0)
	)
	var start_error := logger.begin(simulation, {
		"mode": "test",
		"global_settings": {"recording_fps": 60},
	})
	_check(start_error == OK, "对局开始日志写入成功")
	_check(FileAccess.file_exists(logger.log_path), "每局日志创建独立 JSONL 文件")
	simulation.damage(simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[0].team_id).hp, simulation.fighter_for_side(simulation.teams[1].team_id).accent, simulation.fighter_for_side(simulation.teams[1].team_id))
	simulation.call("_check_finish")
	while not simulation.finished:
		simulation.step(BattleSimulation.FIXED_STEP)
	var finish_error := logger.finish(simulation, "completed", simulation.finish_reason)
	_check(finish_error == OK, "对局结束日志追加成功")
	var lines := FileAccess.get_file_as_string(logger.log_path).split("\n", false)
	_check(lines.size() == 2, "每局日志严格包含开始与结束两条事件")
	if lines.size() == 2:
		var started = JSON.parse_string(lines[0])
		var finished = JSON.parse_string(lines[1])
		_check(started is Dictionary, "开始事件是有效 JSON")
		_check(finished is Dictionary, "结束事件是有效 JSON")
		if started is Dictionary and finished is Dictionary:
			_check(started.get("event") == "battle_started", "首条事件标识为 battle_started")
			_check(finished.get("event") == "battle_finished", "末条事件标识为 battle_finished")
			_check(started.get("battle_id") == finished.get("battle_id"), "开始与结束共享同一 battle_id")
			var start_battle: Dictionary = started.get("battle", {})
			var finish_battle: Dictionary = finished.get("battle", {})
			_check(start_battle.get("seed") == 20261001, "日志保存真实种子")
			_check(start_battle.get("arena_size") == {"x": 440.0, "y": 440.0}, "日志保存真实竞技场尺寸")
			_check(start_battle.has("participants") and start_battle.has("rules"), "开始日志包含双方配置与通用规则")
			_check(start_battle.get("setup", {}).get("mode") == BattleSetupScript.MODE_RELAY, "开始日志保存完整战斗模式与阵容设置")
			_check(start_battle.get("setup", {}).get("teams", [])[0].get("name") == "先锋队", "开始日志保存自定义阵营名称")
			_check(finish_battle.get("finished") == true, "结束日志保存最终完成状态")
			_check(finish_battle.has("statistics") and finish_battle.has("entities"), "结束日志包含完整统计与实体状态")
			_check(finish_battle.has("combat_report"), "结束日志持久保存逐球及附属物分类战报")
			_check(finish_battle.get("combat_report", {}) == finish_battle.get("snapshot", {}).get("combat_report", {}), "日志与模拟快照使用同一份战报")
			var report_row: Dictionary = finish_battle["snapshot"]["combat_report"]["fighters"][0]["rows"][0]
			_check(report_row["damage_taken"] is float and report_row["damage_taken"] > 0.0, "深层战报伤害值仍是数值而非序列化字符串")
			_check(finish_battle.get("team_events", []).size() >= 2, "结束日志保存换人、淘汰和胜负阵营事件")
			_check(finish_battle.get("participants", {}).get("fighters", []).size() == 3, "结束日志保留已阵亡与候补主球的 UID 级历史")
	var draw_simulation := BattleSimulationScript.new(20261002, "test_ball", "test_ball")
	draw_simulation.damage(draw_simulation.fighter_for_side(draw_simulation.teams[0].team_id), draw_simulation.fighter_for_side(draw_simulation.teams[0].team_id).hp, Color.WHITE, null)
	draw_simulation.damage(draw_simulation.fighter_for_side(draw_simulation.teams[1].team_id), draw_simulation.fighter_for_side(draw_simulation.teams[1].team_id).hp, Color.WHITE, null)
	draw_simulation.call("_check_finish")
	var draw_payload: Dictionary = logger.call("_battle_payload", draw_simulation)
	_check(draw_payload.get("result") == "draw" and draw_payload.get("is_draw") == true, "日志显式记录同归于尽的平局结果")
	_check(draw_payload.get("winner_team_id") == -1 and String(draw_payload.get("winner_id", "")).is_empty(), "平局日志不伪造胜者")
	_cleanup(logger.log_path, test_root)
	if failures.is_empty():
		print("ABILITY_BALL_LOGGER_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _cleanup(path: String, root: String) -> void:
	var absolute_root := ProjectSettings.globalize_path(root)
	var date_directory := path.get_base_dir()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(date_directory)
	DirAccess.remove_absolute(absolute_root)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
