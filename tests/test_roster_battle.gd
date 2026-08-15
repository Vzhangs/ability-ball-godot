extends SceneTree

const RosterSimulationScript := preload("res://scripts/simulation/roster_battle_simulation.gd")

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.reload()
	_check(BallRegistry.is_valid(), "球模块注册表通过完整性校验")
	var ids := BallRegistry.ids()
	_check(ids.size() >= 10, "球库保留首批 10 个球")
	var unique := {}
	for ball_id in ids:
		unique[ball_id] = true
		var module: BallModule = BallRegistry.get_module(ball_id)
		_check(module.id == ball_id, "%s 的目录 ID 一致" % ball_id)
		_check(not module.display_name.is_empty(), "%s 有显示名称" % ball_id)
		_check(module.max_hp > 0.0, "%s 有有效生命值" % ball_id)
		_check(module.cooldown > 0.0, "%s 有有效能力冷却" % ball_id)
		_check(module.create_ability() is BallAbility, "%s 提供独立能力实现" % ball_id)
		_check(module.create_visual() is BallVisual, "%s 提供独立视觉实现" % ball_id)
	_check(unique.size() == ids.size(), "球 ID 不重复")
	_check(not BallRegistry.has_id("not-a-ball"), "未知球 ID 被注册表拒绝")

	var deterministic_a := RosterSimulationScript.new(20260815, "splitter", "black_hole")
	var deterministic_b := RosterSimulationScript.new(20260815, "splitter", "black_hole")
	_run_to_finish(deterministic_a, true)
	_run_to_finish(deterministic_b, false)
	_check(deterministic_a.snapshot() == deterministic_b.snapshot(), "相同球种和种子可完全重放")

	var ability_totals := {}
	var wins := {}
	var total_elapsed := 0.0
	var minimum_elapsed := 999.0
	var maximum_elapsed := 0.0
	var timeout_count := 0
	for ball_id in ids:
		ability_totals[ball_id] = 0
		wins[ball_id] = 0
	var matchup_count := 0
	for left_index in range(ids.size()):
		for right_index in range(left_index + 1, ids.size()):
			var simulation := RosterSimulationScript.new(20260815 + matchup_count, ids[left_index], ids[right_index])
			_run_to_finish(simulation, true)
			matchup_count += 1
			total_elapsed += simulation.elapsed
			minimum_elapsed = minf(minimum_elapsed, simulation.elapsed)
			maximum_elapsed = maxf(maximum_elapsed, simulation.elapsed)
			if simulation.finish_reason == "时限判定":
				timeout_count += 1
			_check(simulation.finished, "%s VS %s 能在时限内结束" % [simulation.left.display_name, simulation.right.display_name])
			_check(not simulation.winner_side.is_empty(), "%s VS %s 产生胜者" % [simulation.left.display_name, simulation.right.display_name])
			_check(float(simulation.stats["damage_to_left"]) + float(simulation.stats["damage_to_right"]) > 0.0, "%s VS %s 产生真实伤害" % [simulation.left.display_name, simulation.right.display_name])
			var abilities: Dictionary = simulation.stats["abilities"]
			ability_totals[simulation.left.id] = int(ability_totals[simulation.left.id]) + int(abilities[simulation.left.id])
			ability_totals[simulation.right.id] = int(ability_totals[simulation.right.id]) + int(abilities[simulation.right.id])
			wins[simulation.winner_id] = int(wins[simulation.winner_id]) + 1

	var expected_matchups := ids.size() * (ids.size() - 1) / 2
	_check(matchup_count == expected_matchups, "%d 个球的 %d 种异种组合全部覆盖" % [ids.size(), expected_matchups])
	_check(minimum_elapsed >= 12.0, "最快对局也保留首轮能力展开时间")
	_check(total_elapsed / matchup_count >= 30.0, "平均对局时长适合短视频叙事")
	for ball_id in ids:
		var module: BallModule = BallRegistry.get_module(ball_id)
		_check(int(ability_totals[ball_id]) > 0, "%s 的专属能力至少触发一次" % module.display_name)

	var zero_seed := RosterSimulationScript.new(0, "splitter", "black_hole")
	_check(zero_seed.seed_value == 20260815, "零种子回退到默认种子")

	print("ABILITY_BALL_ROSTER_TEST_SUMMARY ", JSON.stringify({
		"balls": ids.size(),
		"matchups": matchup_count,
		"minimum_elapsed": minimum_elapsed,
		"average_elapsed": total_elapsed / matchup_count,
		"maximum_elapsed": maximum_elapsed,
		"timeouts": timeout_count,
		"ability_totals": ability_totals,
		"wins": wins,
	}))
	if failures.is_empty():
		print("ABILITY_BALL_ROSTER_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_ROSTER_TESTS_FAILED count=", failures.size())
		quit(1)

func _run_to_finish(simulation: RosterBattleSimulation, check_bounds: bool) -> void:
	var max_frames := int(ceil(RosterBattleSimulation.MAX_BATTLE_TIME / RosterBattleSimulation.FIXED_STEP)) + 4
	for frame in range(max_frames):
		simulation.step(RosterBattleSimulation.FIXED_STEP)
		if check_bounds and frame % 300 == 0:
			_check(_inside_arena(simulation.left), "%s 始终留在竞技场" % simulation.left.display_name)
			_check(_inside_arena(simulation.right), "%s 始终留在竞技场" % simulation.right.display_name)
		if simulation.finished:
			break

func _inside_arena(fighter: RosterBattleSimulation.FighterState) -> bool:
	return (
		fighter.pos.x >= fighter.radius - 0.01
		and fighter.pos.x <= RosterBattleSimulation.ARENA_SIZE.x - fighter.radius + 0.01
		and fighter.pos.y >= fighter.radius - 0.01
		and fighter.pos.y <= RosterBattleSimulation.ARENA_SIZE.y - fighter.radius + 0.01
	)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
