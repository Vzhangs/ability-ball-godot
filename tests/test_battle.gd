extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

var failures: Array[String] = []

func _init() -> void:
	var first := BattleSimulationScript.new(20260815, "vampire", "six_king")
	var replay := BattleSimulationScript.new(20260815, "vampire", "six_king")
	var divergent := BattleSimulationScript.new(20260816, "vampire", "six_king")

	for frame in range(int(ceil(first.max_battle_time / BattleSimulation.FIXED_STEP)) + 4):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
		divergent.step(BattleSimulation.FIXED_STEP)
		if frame % 600 == 0:
			_check(first.snapshot() == replay.snapshot(), "相同种子在第 %d 帧保持确定性" % frame)
			_check(_inside_arena(first.left), "吸血鬼始终留在竞技场")
			_check(_inside_arena(first.right), "六王球始终留在竞技场")
		if first.finished and replay.finished and divergent.finished:
			break

	var snapshot := first.snapshot()
	_check(first.finished, "默认对局在硬时限内结束")
	_check(first.scenario.id == "vampire_six_king_showcase", "默认组合自动装载完整 Boss 场景")
	_check(first.winner_id == "six_king", "默认种子由六王球获胜")
	_check(first.elapsed >= 72.0 and first.elapsed <= first.max_battle_time, "默认对局具有完整能力展开节奏")
	_check(first.right_ability.has_method("crown_level"), "六王球展示能力独立拥有王冠等级")
	_check(int(first.right_ability.call("crown_level")) == 3, "六王球自己的王冠能力成长到最高等级")
	_check(int(first.stats["crown_advances"]) == 2, "王冠升级只由六王球能力记录")
	_check(int(first.stats["anchors_spawned"]) >= 20, "边缘锚点能力充分展开")
	_check(int(first.stats["tracks_spawned"]) >= 8, "轨道王冠反复触发")
	_check(int(first.stats["checker_hits"]) >= 1, "棋盘审判至少命中一次")
	_check(int(first.stats["tether_hits"]) >= 1, "能量连线至少命中一次")
	_check(int(first.stats["track_hits"]) >= 1, "轨道武器至少命中一次")
	_check(int(first.stats["blood_bursts"]) >= 10, "吸血鬼血爆反复触发")
	_check(float(first.stats["healing"]) > 0.0, "吸血治疗真实增加生命")
	_check(float(first.stats["damage_to_right"]) > 0.0, "六王球真实受到伤害")
	_check(first.right.hp > 0.0 and first.right.hp < first.right.max_hp, "胜者保留可读的剩余生命")
	_check(snapshot == replay.snapshot(), "最终状态可重放")
	_check(snapshot != divergent.snapshot(), "不同种子产生不同战斗")
	_check(BattleSimulationScript.new(0, "vampire", "six_king").seed_value == 20260815, "非法零种子回退到默认值")

	print("ABILITY_BALL_TEST_SUMMARY ", JSON.stringify({
		"elapsed": first.elapsed,
		"winner": first.winner_id,
		"vampire_hp": first.left.hp,
		"six_king_hp": first.right.hp,
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
