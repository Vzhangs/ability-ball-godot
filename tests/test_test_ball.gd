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
	_check(module.setting_specs().size() == 4, "测试球只声明生命、速度、半径和冷却四项基础配置")
	_check(is_equal_approx(module.max_hp, 100.0), "测试球默认生命值为 100")
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
	_check(is_equal_approx(simulation.left.hp, simulation.left.max_hp), "测试球十秒自然运动不会对左侧本体造成伤害")
	_check(is_equal_approx(simulation.right.hp, simulation.right.max_hp), "测试球十秒自然运动不会对右侧本体造成伤害")
	_check(int(simulation.stats["abilities"].get("test_ball", 0)) == 0, "测试球不会产生空技能触发统计")
	_check(simulation.entities.is_empty(), "测试球不会生成任何附属实体")
	_check(simulation.left.status_effects.is_empty() and simulation.right.status_effects.is_empty(), "测试球不会生成任何状态效果")

	simulation.left.pos = Vector2(300.0, 320.0)
	simulation.right.pos = Vector2(350.0, 320.0)
	simulation.left.velocity = Vector2(180.0, 0.0)
	simulation.right.velocity = Vector2(-180.0, 0.0)
	simulation._contact_timer = 0.0
	var left_hp_before := simulation.left.hp
	var right_hp_before := simulation.right.hp
	simulation._resolve_collision()
	_check(is_equal_approx(simulation.left.hp, left_hp_before) and is_equal_approx(simulation.right.hp, right_hp_before), "两个测试球真实碰撞只改变运动轨迹而不扣血")
	_check(simulation.left.velocity.x < 0.0 and simulation.right.velocity.x > 0.0, "测试球仍参与通用物理反弹")

func _check_persistent_base_settings() -> void:
	BallRegistry.configure_settings({
		"test_ball": {
			"max_hp": 175.0,
			"speed": 321.0,
			"radius": 42.0,
			"cooldown": 0.25,
		},
	})
	var laser_match := BattleSimulationScript.new(20270121, "test_ball", "laser")
	var heaven_match := BattleSimulationScript.new(20270122, "test_ball", "heaven")
	for simulation in [laser_match, heaven_match]:
		_check(is_equal_approx(simulation.left.max_hp, 175.0), "测试球自定义生命值跨对手持续生效")
		_check(is_equal_approx(simulation.left.base_speed, 321.0), "测试球自定义速度跨对手持续生效")
		_check(is_equal_approx(simulation.left.radius, 42.0), "测试球自定义大小跨对手持续生效")
		_check(is_equal_approx(simulation.left.cooldown, 0.25), "测试球基础配置经通用持久化 Schema 进入新对局")
		_check(not simulation.left_ability.automatic_activation_enabled(), "修改基础参数不会给测试球引入技能")
	_check(is_equal_approx(laser_match.right.max_hp, 100.0), "测试球配置不会串改激光球")
	_check(is_equal_approx(heaven_match.right.max_hp, 100.0), "测试球配置不会串改天堂球")

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
