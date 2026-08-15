extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

var failures: Array[String] = []

func _init() -> void:
	var first := BattleSimulationScript.new(20260815)
	var replay := BattleSimulationScript.new(20260815)
	var divergent := BattleSimulationScript.new(20260816)

	for frame in range(int(ceil(BattleSimulation.MAX_BATTLE_TIME / BattleSimulation.FIXED_STEP)) + 4):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
		divergent.step(BattleSimulation.FIXED_STEP)
		if frame % 600 == 0:
			_check(first.snapshot() == replay.snapshot(), "相同种子在第 %d 帧保持确定性" % frame)
			_check(_inside_arena(first.vampire), "吸血鬼始终留在竞技场")
			_check(_inside_arena(first.six_king), "六王球始终留在竞技场")
		if first.finished and replay.finished and divergent.finished:
			break

	var snapshot := first.snapshot()
	_check(first.finished, "默认对局在硬时限内结束")
	_check(first.winner_id == "six_king", "默认种子由六王球获胜")
	_check(first.elapsed >= 72.0 and first.elapsed <= BattleSimulation.MAX_BATTLE_TIME, "默认对局具有完整三阶段节奏")
	_check(first.phase == 3, "默认对局进入第三阶段")
	_check(int(first.stats["phase_changes"]) == 2, "阶段恰好升级两次")
	_check(int(first.stats["anchors_spawned"]) >= 20, "边缘锚点能力充分展开")
	_check(int(first.stats["tracks_spawned"]) >= 8, "轨道王冠反复触发")
	_check(int(first.stats["checker_hits"]) >= 1, "棋盘审判至少命中一次")
	_check(int(first.stats["tether_hits"]) >= 1, "能量连线至少命中一次")
	_check(int(first.stats["track_hits"]) >= 1, "轨道武器至少命中一次")
	_check(int(first.stats["blood_bursts"]) >= 10, "吸血鬼血爆反复触发")
	_check(float(first.stats["vampire_healing"]) > 0.0, "吸血治疗真实增加生命")
	_check(float(first.stats["damage_to_six_king"]) > 0.0, "六王球真实受到伤害")
	_check(first.six_king.hp > 0.0 and first.six_king.hp < first.six_king.max_hp, "胜者保留可读的剩余生命")
	_check(snapshot == replay.snapshot(), "最终状态可重放")
	_check(snapshot != divergent.snapshot(), "不同种子产生不同战斗")
	_check(BattleSimulationScript.new(0).seed_value == 20260815, "非法零种子回退到默认值")

	print("ABILITY_BALL_TEST_SUMMARY ", JSON.stringify({
		"elapsed": first.elapsed,
		"winner": first.winner_id,
		"vampire_hp": first.vampire.hp,
		"six_king_hp": first.six_king.hp,
		"stats": first.stats,
	}))

	if failures.is_empty():
		print("ABILITY_BALL_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_TESTS_FAILED count=", failures.size())
		quit(1)

func _inside_arena(fighter: BattleSimulation.FighterState) -> bool:
	return (
		fighter.pos.x >= fighter.radius - 0.01
		and fighter.pos.x <= BattleSimulation.ARENA_SIZE.x - fighter.radius + 0.01
		and fighter.pos.y >= fighter.radius - 0.01
		and fighter.pos.y <= BattleSimulation.ARENA_SIZE.y - fighter.radius + 0.01
	)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

