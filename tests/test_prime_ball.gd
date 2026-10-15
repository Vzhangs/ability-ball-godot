extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const PrimeTable := preload("res://scripts/balls/prime/prime_number_table.gd")

var failures: Array[String] = []

class TestContactEntity extends BallEntity:
	var hp := 100.0
	var _contact_ready := true

	func _init(spawn_owner: int, spawn_position: Vector2) -> void:
		owner_side = spawn_owner
		pos = spawn_position
		radius = 12.0
		tags = PackedStringArray(["prime_test_contact_entity"])

	func participates_in_fighter_collision() -> bool:
		return not removed

	func fighter_collision_inverse_mass() -> float:
		return 1.0

	func can_resolve_fighter_contact(fighter_side: int) -> bool:
		return _contact_ready and is_hostile_to(fighter_side)

	func begin_fighter_contact(_fighter_side: int) -> void:
		_contact_ready = false

	func can_receive_attack(source_side: int) -> bool:
		return not removed and is_hostile_to(source_side)

	func receive_attack(
		_battle,
		amount: float,
		source_side: int,
		_hit_color: Color
	) -> float:
		if not can_receive_attack(source_side):
			return 0.0
		var applied := minf(hp, maxf(0.0, amount))
		hp -= applied
		return applied

func _init() -> void:
	_check_prime_table()
	_check_module_contract()
	_check_main_body_sequence()
	_check_entity_contact_sequence()
	_check_table_exhaustion_policy()
	_check_persistent_settings_isolation()
	_check_determinism()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_PRIME_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_PRIME_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_prime_table() -> void:
	_check(PrimeTable.VALUES.size() == 10000, "哥德巴赫球预置恰好 10000 个素数")
	_check(PrimeTable.value_at(0) == 2, "素数表从第一个素数 2 开始")
	_check(PrimeTable.value_at(9999) == 104729, "第 10000 个预置素数为 104729")
	var previous := 1
	for index in range(PrimeTable.COUNT):
		var value := PrimeTable.value_at(index)
		if value <= previous or not _is_prime(value):
			_check(false, "素数表第 %d 项严格递增且确为素数" % (index + 1))
			break
		previous = value

func _check_module_contract() -> void:
	BallRegistry.configure_settings({})
	var module: BallModule = BallRegistry.get_module("prime")
	_check(module != null and module.display_name == "哥德巴赫球", "哥德巴赫球由注册表自动发现")
	_check(module.setting_specs().has("impact_flash_duration"), "撞击闪光时长由哥德巴赫球 Schema 配置")
	_check(is_equal_approx(module.max_hp, 100.0), "哥德巴赫球默认生命值为 100")
	var ability: BallAbility = module.create_ability()
	ability.on_battle_started(null, null, null, 0)
	_check(not ability.automatic_activation_enabled(), "哥德巴赫球是纯碰撞被动，不触发空自动技能")
	_check(is_equal_approx(ability.contact_damage(null, null, null), 2.0), "首次撞击伤害为素数 2")
	_check(is_equal_approx(ability.contact_damage(null, null, null), 2.0), "只查询伤害不会提前推进素数")
	_check(module.create_visual(ability) is BallVisual, "哥德巴赫球装载独立数学视觉")

func _check_main_body_sequence() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270824, "prime", "test_ball")
	simulation.fighter_for_side(simulation.teams[1].team_id).max_hp = 1000.0
	simulation.fighter_for_side(simulation.teams[1].team_id).hp = 1000.0
	var expected_primes := [2, 3, 5, 7, 11, 13]
	for expected_prime in expected_primes:
		_prepare_main_contact(simulation)
		var hp_before: float = simulation.fighter_for_side(simulation.teams[1].team_id).hp
		simulation._resolve_fighter_pair(simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id))
		_check(
			is_equal_approx(hp_before - simulation.fighter_for_side(simulation.teams[1].team_id).hp, float(expected_prime)),
			"第 %d 次真实主球撞击造成素数伤害 %d" % [
				int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("impact_count")), expected_prime,
			]
		)
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("impact_count")) == expected_primes.size(), "每次真实接触只推进一次素数")
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("current_prime")) == 17, "六次碰撞后下一次伤害推进到素数 17")
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).hp, simulation.fighter_for_side(simulation.teams[0].team_id).max_hp), "无碰撞伤害的对手不会反向伤害哥德巴赫球")
	_check(int(simulation.stats.get("prime_ball_impacts", 0)) == expected_primes.size(), "哥德巴赫球记录真实撞击次数")

func _check_entity_contact_sequence() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270825, "prime", "test_ball")
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(560.0, 560.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(240.0, 320.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(205.0, 0.0)
	var entity := TestContactEntity.new(1, simulation.fighter_for_side(simulation.teams[0].team_id).pos + Vector2(32.0, 0.0))
	entity.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
	simulation.add_entity(entity)
	simulation._resolve_fighter_entity_collisions()
	_check(is_equal_approx(entity.hp, 98.0), "哥德巴赫球撞到可碰撞附属物同样造成当前素数伤害 2")
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("current_prime")) == 3, "附属物碰撞与主球碰撞共用同一素数序列")
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("impact_count")) == 1, "一次附属物接触只推进一次素数")

func _check_table_exhaustion_policy() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270826, "prime", "test_ball")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).set("_prime_index", PrimeTable.COUNT - 2)
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("current_prime")) == 104723, "预置表倒数第二项可正常读取")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_contact(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		104723.0
	)
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("current_prime")) == 104729, "倒数第二次撞击推进到第 10000 个素数")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_contact(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		104729.0
	)
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("current_prime")) == 104729, "10000 项耗尽后稳定保持最后一个预置素数")

func _check_persistent_settings_isolation() -> void:
	BallRegistry.configure_settings({
		"prime": {
			"max_hp": 180.0,
			"speed": 333.0,
			"radius": 37.0,
			"cooldown": 0.25,
			"impact_flash_duration": 0.66,
		},
	})
	var wdc_match := BattleSimulationScript.new(20270827, "prime", "wdc")
	var plant_match := BattleSimulationScript.new(20270828, "prime", "plant")
	for simulation in [wdc_match, plant_match]:
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).max_hp, 180.0), "哥德巴赫球生命配置跨对手生效")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).base_speed, 333.0), "哥德巴赫球速度配置跨对手生效")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).radius, 37.0), "哥德巴赫球半径配置跨对手生效")
		_check(is_equal_approx(simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("impact_flash_duration"), 0.66), "哥德巴赫球视觉时长配置跨对手生效")
	_check(is_equal_approx(wdc_match.fighter_for_side(wdc_match.teams[1].team_id).max_hp, 100.0), "哥德巴赫球配置不会串改 WDC")
	_check(is_equal_approx(plant_match.fighter_for_side(plant_match.teams[1].team_id).max_hp, 100.0), "哥德巴赫球配置不会串改植物球")

func _check_determinism() -> void:
	BallRegistry.configure_settings({})
	var first := BattleSimulationScript.new(20270829, "prime", "flame")
	var replay := BattleSimulationScript.new(20270829, "prime", "flame")
	for _frame in range(1800):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
		if first.finished and replay.finished:
			break
	_check(first.snapshot() == replay.snapshot(), "哥德巴赫球相同种子和配置可完全重放")
	_check(
		int(first._ability_for_fighter(first.fighter_for_side(first.teams[0].team_id)).call("prime_index")) == int(replay._ability_for_fighter(replay.fighter_for_side(replay.teams[0].team_id)).call("prime_index")),
		"确定性重放包含一致的私有素数进度"
	)

func _prepare_main_contact(simulation) -> void:
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(300.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(350.0, 320.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(205.0, 0.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(-180.0, 0.0)
	simulation._contact_timers.clear()

func _is_prime(value: int) -> bool:
	if value < 2:
		return false
	var divisor := 2
	while divisor * divisor <= value:
		if value % divisor == 0:
			return false
		divisor += 1
	return true

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
