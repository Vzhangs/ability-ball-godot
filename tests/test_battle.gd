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
			_check(_inside_arena(first.left, first.arena_size()), "吸血鬼始终留在竞技场")
			_check(_inside_arena(first.right, first.arena_size()), "六王球始终留在竞技场")
		if first.finished and replay.finished and divergent.finished:
			break

	var snapshot := first.snapshot()
	_check(first.finished, "默认对局在硬时限内结束")
	_check(not snapshot.has("scenario_id"), "战斗快照不包含特殊场景身份")
	_check(is_equal_approx(first.damage_scale, 1.0), "所有组合使用统一伤害倍率")
	_check(is_equal_approx(first.recovery_scale, 1.0), "所有组合使用统一回复倍率")
	_check(is_equal_approx(first.left.max_hp, 100.0), "吸血鬼默认生命值为 100")
	_check(is_equal_approx(first.right.max_hp, 100.0), "六王球默认生命值为 100")
	_check(first.winner_id in ["vampire", "six_king"], "默认对局产生合法胜者")
	_check(first.elapsed > 0.0 and first.elapsed <= first.max_battle_time, "默认对局按当前持久化数值自然结束")
	var vampire_against_laser := BattleSimulationScript.new(20260815, "vampire", "laser")
	_check(first.left_module.fighter_spec() == vampire_against_laser.left_module.fighter_spec(), "吸血鬼面对不同对手始终使用唯一配置")
	_check(first.left_ability.get_script() == vampire_against_laser.left_ability.get_script(), "吸血鬼面对不同对手始终使用唯一能力脚本")
	var winner = first.winner()
	_check(winner.hp > 0.0 and winner.hp <= winner.max_hp, "胜者生命值保持在自身配置范围内")
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

func _inside_arena(fighter: BattleSimulation.FighterState, arena_size: Vector2) -> bool:
	return (
		fighter.pos.x >= fighter.radius - 0.01
		and fighter.pos.x <= arena_size.x - fighter.radius + 0.01
		and fighter.pos.y >= fighter.radius - 0.01
		and fighter.pos.y <= arena_size.y - fighter.radius + 0.01
	)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
