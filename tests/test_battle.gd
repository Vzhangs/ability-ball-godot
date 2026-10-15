extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

var failures: Array[String] = []

func _init() -> void:
	var first := BattleSimulationScript.new(20260815, "vampire", "wdc")
	var replay := BattleSimulationScript.new(20260815, "vampire", "wdc")
	var divergent := BattleSimulationScript.new(20260816, "vampire", "wdc")

	# 战斗时间会在世界停止等通用演出暂停期间冻结；物理步数上限必须给这些暂停留出余量。
	var max_frames := int(ceil(first.max_battle_time / BattleSimulation.FIXED_STEP)) * 2 + 4
	for frame in range(max_frames):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
		divergent.step(BattleSimulation.FIXED_STEP)
		if frame % 600 == 0:
			_check(first.snapshot() == replay.snapshot(), "相同种子在第 %d 帧保持确定性" % frame)
			_check(_inside_arena(first.fighter_for_side(first.teams[0].team_id), first.arena_size()), "吸血鬼始终留在竞技场")
			_check(_inside_arena(first.fighter_for_side(first.teams[1].team_id), first.arena_size()), "WDC 始终留在竞技场")
		if first.finished and replay.finished and divergent.finished:
			break

	var snapshot := first.snapshot()
	_check(first.finished, "默认对局在硬时限内结束")
	_check(not snapshot.has("scenario_id"), "战斗快照不包含特殊场景身份")
	_check(is_equal_approx(first.damage_scale, 1.0), "所有组合使用统一伤害倍率")
	_check(is_equal_approx(first.recovery_scale, 1.0), "所有组合使用统一回复倍率")
	_check(is_equal_approx(first.fighter_for_side(first.teams[0].team_id).max_hp, 100.0), "吸血鬼默认生命值为 100")
	_check(is_equal_approx(first.fighter_for_side(first.teams[1].team_id).max_hp, 100.0), "WDC 默认生命值为 100")
	_check(first.winner_id in ["vampire", "wdc"], "默认对局产生合法胜者")
	_check(first.elapsed > 0.0 and first.elapsed <= first.max_battle_time, "默认对局按当前持久化数值自然结束")
	var vampire_against_test_ball := BattleSimulationScript.new(20260815, "vampire", "test_ball")
	_check(first.module_for_fighter(first.fighter_for_side(first.teams[0].team_id)).fighter_spec() == vampire_against_test_ball.module_for_fighter(vampire_against_test_ball.fighter_for_side(vampire_against_test_ball.teams[0].team_id)).fighter_spec(), "吸血鬼面对不同对手始终使用唯一配置")
	_check(first._ability_for_fighter(first.fighter_for_side(first.teams[0].team_id)).get_script() == vampire_against_test_ball._ability_for_fighter(vampire_against_test_ball.fighter_for_side(vampire_against_test_ball.teams[0].team_id)).get_script(), "吸血鬼面对不同对手始终使用唯一能力脚本")
	var winner = first.winner()
	_check(winner.hp > 0.0, "胜者保留正生命值")
	_check(winner.id == "vampire" or winner.hp <= winner.max_hp, "只有明确支持超上限治疗的吸血鬼可以突破配置生命上限")
	_check(snapshot == replay.snapshot(), "最终状态可重放")
	_check(snapshot != divergent.snapshot(), "不同种子产生不同战斗")
	_check(BattleSimulationScript.new(0, "vampire", "wdc").seed_value == 20260815, "非法零种子回退到默认值")

	print("ABILITY_BALL_TEST_SUMMARY ", JSON.stringify({
		"elapsed": first.elapsed,
		"winner": first.winner_id,
		"vampire_hp": first.fighter_for_side(first.teams[0].team_id).hp,
		"wdc_hp": first.fighter_for_side(first.teams[1].team_id).hp,
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
