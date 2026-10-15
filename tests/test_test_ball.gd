extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_default_contract()
	_check_inert_battle_behavior()
	_check_persistent_base_settings()
	_check_determinism()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_TEST_BALL_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_TEST_BALL_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_default_contract() -> void:
	var module: BallModule = BallRegistry.get_module("test_ball")
	_check(module != null and module.display_name == "测试球", "测试球由注册表自动发现并使用独立公开名称")
	_check(module.setting_specs().size() == 5, "测试球只声明球简介与生命、速度、半径、冷却五项通用配置")
	_check(String(module.setting_specs()["ability_description"]["kind"]) == "text", "测试球简介使用通用可持久化文本配置")
	_check(is_equal_approx(module.max_hp, 1000.0), "测试球默认生命值为 1000")
	_check(is_equal_approx(module.speed, 180.0), "测试球默认速度为 180")
	_check(is_equal_approx(module.radius, 27.0), "测试球默认半径为 27")
	var ability: BallAbility = module.create_ability()
	_check(not ability.automatic_activation_enabled(), "测试球明确关闭自动技能调度")
	_check(is_zero_approx(ability.contact_damage(null, null, null)), "测试球普通本体碰撞伤害为零")
	_check(module.create_visual() is BallVisual, "测试球复用无技能装饰的基础球体视觉")

func _check_inert_battle_behavior() -> void:
	var simulation := BattleSimulationScript.new(20270120, "test_ball", "test_ball")
	for _frame in range(600):
		simulation.step(BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).hp, simulation.fighter_for_side(simulation.teams[0].team_id).max_hp), "测试球十秒自然运动不会对左侧本体造成伤害")
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).hp, simulation.fighter_for_side(simulation.teams[1].team_id).max_hp), "测试球十秒自然运动不会对右侧本体造成伤害")
	_check(int(simulation.stats["abilities"].get("test_ball", 0)) == 0, "测试球不会产生空技能触发统计")
	_check(simulation.entities.is_empty(), "测试球不会生成任何附属实体")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).status_effects.is_empty() and simulation.fighter_for_side(simulation.teams[1].team_id).status_effects.is_empty(), "测试球不会生成任何状态效果")

	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(300.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(350.0, 320.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(180.0, 0.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(-180.0, 0.0)
	simulation._contact_timers.clear()
	var left_hp_before := simulation.fighter_for_side(simulation.teams[0].team_id).hp
	var right_hp_before := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	simulation._resolve_fighter_pair(simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id))
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).hp, left_hp_before) and is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).hp, right_hp_before), "两个测试球真实碰撞只改变运动轨迹而不扣血")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).velocity.x < 0.0 and simulation.fighter_for_side(simulation.teams[1].team_id).velocity.x > 0.0, "测试球仍参与通用物理反弹")

func _check_persistent_base_settings() -> void:
	BallRegistry.configure_settings({
		"test_ball": {
			"max_hp": 175.0,
			"speed": 321.0,
			"radius": 42.0,
			"cooldown": 0.25,
		},
	})
	var wdc_match := BattleSimulationScript.new(20270121, "test_ball", "wdc")
	var plant_match := BattleSimulationScript.new(20270122, "test_ball", "plant")
	for simulation in [wdc_match, plant_match]:
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).max_hp, 175.0), "测试球自定义生命值跨对手持续生效")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).base_speed, 321.0), "测试球自定义速度跨对手持续生效")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).radius, 42.0), "测试球自定义大小跨对手持续生效")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).cooldown, 0.25), "测试球基础配置经通用持久化 Schema 进入新对局")
		_check(not simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).automatic_activation_enabled(), "修改基础参数不会给测试球引入技能")
	_check(is_equal_approx(wdc_match.fighter_for_side(wdc_match.teams[1].team_id).max_hp, 100.0), "测试球配置不会串改 WDC")
	_check(is_equal_approx(plant_match.fighter_for_side(plant_match.teams[1].team_id).max_hp, 100.0), "测试球配置不会串改植物球")

func _check_determinism() -> void:
	BallRegistry.configure_settings({})
	var first := BattleSimulationScript.new(20270123, "test_ball", "test_ball")
	var replay := BattleSimulationScript.new(20270123, "test_ball", "test_ball")
	for _frame in range(900):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
	_check(first.snapshot() == replay.snapshot(), "测试球相同种子和基础配置可完全重放")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
