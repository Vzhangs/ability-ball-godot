extends SceneTree

const BattleLoggerScript := preload("res://scripts/logging/battle_logger.gd")
const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	var test_root := "user://ability_ball_logger_test_%d" % Time.get_ticks_usec()
	var logger: BattleLogger = BattleLoggerScript.new(test_root)
	var simulation := BattleSimulationScript.new(
		20261001,
		"vampire",
		"wdc",
		0.1,
		Vector2(440.0, 440.0)
	)
	var start_error := logger.begin(simulation, {
		"mode": "test",
		"global_settings": {"recording_fps": 60},
	})
	_check(start_error == OK, "对局开始日志写入成功")
	_check(FileAccess.file_exists(logger.log_path), "每局日志创建独立 JSONL 文件")
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
			_check(finish_battle.get("finished") == true, "结束日志保存最终完成状态")
			_check(finish_battle.has("statistics") and finish_battle.has("entities"), "结束日志包含完整统计与实体状态")
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
