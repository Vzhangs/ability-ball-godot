extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const HardFreezeStatus := preload("res://scripts/balls/frost/hard_freeze_status.gd")
const IceSlowStatusEffectScript := preload("res://scripts/balls/core/ice_slow_status_effect.gd")
const SettingsStore := preload("res://scripts/settings/ball_settings_store.gd")

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_default_contract()
	_check_trail_freezes_main_ball()
	_check_trail_contact_reset()
	_check_trail_attachment_delay()
	_check_same_team_trail_isolation()
	_check_body_contact_has_no_direct_damage()
	_check_damageable_attachment_support()
	_check_persistent_settings_isolation()
	_check_determinism()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_FROST_TESTS_OK")
		quit(0)
		return
	for failure in failures:
		push_error("TEST FAILED: " + failure)
	quit(1)

func _check_default_contract() -> void:
	var module: BallModule = BallRegistry.get_module("frost")
	_check(module != null and module.display_name == "寒冰球", "寒冰球由注册表自动发现")
	_check(module.validation_errors().is_empty(), "寒冰球模块配置与观众简介合法")
	_check(is_equal_approx(module.max_hp, 100.0), "寒冰球默认生命值为 100")
	_check(is_equal_approx(module.settingf("trail_freeze_delay"), 1.0), "轨迹默认连续接触满 1 秒才冰冻")
	_check(is_equal_approx(module.settingf("freeze_duration"), 2.0), "完全冰冻默认持续 2 秒")
	_check(is_equal_approx(module.settingf("freeze_damage"), 2.0), "冰冻默认每次造成 2 点伤害")
	_check(is_equal_approx(module.settingf("freeze_damage_interval"), 1.0), "冰冻伤害默认每秒结算")
	_check(is_equal_approx(module.settingf("slow_duration"), 4.0), "寒冰减速默认持续 4 秒")
	var ability: BallAbility = module.create_ability()
	_check(not ability.automatic_activation_enabled(), "寒冰球使用持续被动而不产生空冷却触发")
	_check(is_zero_approx(ability.contact_damage(null, null, null)), "寒冰球本体碰撞没有瞬时直伤")
	_check(module.create_visual(ability) is BallVisual, "寒冰球拥有独立视觉入口")

func _check_trail_freezes_main_ball() -> void:
	var simulation := BattleSimulationScript.new(20300101, "frost", "test_ball")
	var zones: Array[BallEntity] = simulation.entity_list(0, "frost_ice_trail")
	_check(zones.size() == 1, "寒冰球开局在身下生成第一段轨迹")
	if zones.is_empty():
		return
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(520.0, 520.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = zones[0].pos
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(200.0, 0.0)
	_observe_trail(simulation, 0.0)
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "轨迹初次接触不能直接冰冻")
	_check(simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), IceSlowStatusEffectScript.KEY), "轨迹初次接触立刻获得非叠加减速")
	simulation._update_status_effects(simulation.fighter_for_side(simulation.teams[1].team_id), BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).velocity.length(), 110.0), "冰封准备期间仍可按减速速度移动")
	var hp_on_entry := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	for _frame in range(59):
		_observe_trail(simulation, BattleSimulation.FIXED_STEP)
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "连续接触未满一秒不能提前冰冻")
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).hp, hp_on_entry), "接触准备阶段不结算冰封伤害")
	_observe_trail(simulation, BattleSimulation.FIXED_STEP)
	_check(simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "连续接触满一秒进入完全冰冻")
	for zone: BallEntity in simulation.entity_list(0, "frost_ice_trail"):
		zone.removed = true
	var hp_before := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	for _frame in range(61):
		simulation._update_status_effects(simulation.fighter_for_side(simulation.teams[1].team_id), BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(hp_before - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 2.0), "冰冻一秒后结算一次 2 点伤害")
	_check(simulation.fighter_for_side(simulation.teams[1].team_id).velocity.length() < 0.1, "完全冰冻期间主球保持原地")
	for _frame in range(61):
		simulation._update_status_effects(simulation.fighter_for_side(simulation.teams[1].team_id), BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(hp_before - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 4.0), "完全冰冻两秒共结算两次伤害")
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "完全冰冻在配置时间结束后清理")
	_check(simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), IceSlowStatusEffectScript.KEY), "完全冰冻结束后寒冰减速仍然存在")
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).velocity.length(), 110.0), "解冻后按配置倍率恢复到减速速度")
	for _frame in range(122):
		simulation._update_status_effects(simulation.fighter_for_side(simulation.teams[1].team_id), BattleSimulation.FIXED_STEP)
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), IceSlowStatusEffectScript.KEY), "寒冰减速在总持续时间结束后清理")

func _check_trail_contact_reset() -> void:
	var simulation := BattleSimulationScript.new(20300107, "frost", "test_ball")
	var zone: BallEntity = simulation.entity_list(0, "frost_ice_trail")[0]
	var trail_position := zone.pos
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(520.0, 520.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = trail_position
	# Many intersecting patches form one contact, not many independent clocks.
	for _index in range(4):
		simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id))._spawn_ice_zone(simulation.battle_context, trail_position, simulation.fighter_for_side(simulation.teams[0].team_id), Vector2.RIGHT)
	_observe_trail(simulation, 0.0)
	_observe_trail(simulation, 0.6)
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "重叠冰迹不会叠加接触计时")
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(80.0, 80.0)
	_observe_trail(simulation, BattleSimulation.FIXED_STEP)
	_check(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id))._trail_contact_seconds.is_empty(), "离开一帧即清空接触进度")
	_check(simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), IceSlowStatusEffectScript.KEY), "离开轨迹后仍保留有限时长的减速")
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = trail_position
	_observe_trail(simulation, 0.0)
	_observe_trail(simulation, 0.6)
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "再次进入不能继承离开前的进度")
	for ice: BallEntity in simulation.entity_list(0, "frost_ice_trail"):
		ice.disable_for_capture()
	_observe_trail(simulation, 0.4)
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "冰迹被捕获后不再累计或触发冰冻")
	_check(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id))._trail_contact_seconds.is_empty(), "冰迹全部消失时清理接触名单")
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[0].team_id), IceSlowStatusEffectScript.KEY), "己方主球不会被自己的轨迹减速")

func _check_trail_attachment_delay() -> void:
	BallRegistry.configure_settings({"splitter": {"cooldown": 60.0, "damage_split_chance": 0.0}})
	var simulation := BattleSimulationScript.new(20300108, "frost", "splitter")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[1].team_id)).activate(simulation.battle_context, simulation.fighter_for_side(simulation.teams[1].team_id), simulation.fighter_for_side(simulation.teams[0].team_id), 1)
	var clones: Array[BallEntity] = simulation.entity_list(1, "splitter_clone")
	_check(clones.size() >= 2, "附属物延迟测试创建两只真实分身")
	if clones.size() < 2:
		return
	var trail_position: Vector2 = simulation.entity_list(0, "frost_ice_trail")[0].pos
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(520.0, 520.0)
	clones[0].pos = trail_position
	clones[1].pos = Vector2(80.0, 80.0)
	_observe_trail(simulation, 0.0)
	_check(is_equal_approx(clones[0].status_step_multiplier(), 0.55), "附属物初触冰迹立即减速但不停止")
	_observe_trail(simulation, 0.6)
	clones[1].pos = trail_position
	_observe_trail(simulation, 0.0)
	_observe_trail(simulation, 0.4)
	_check(simulation.has_status(clones[0], HardFreezeStatus.KEY), "附属物连续接触满一秒也会冰冻")
	_check(not simulation.has_status(clones[1], HardFreezeStatus.KEY), "后进入的目标独立计时，不继承另一目标的进度")
	_check(is_zero_approx(clones[0].status_step_multiplier()), "达到冰冻阈值后附属物才停止行动")
	clones[1].disable_for_capture()
	_observe_trail(simulation, 0.6)
	_check(not simulation.has_status(clones[1], HardFreezeStatus.KEY), "附属物被捕获后不再累计冰迹接触")
	BallRegistry.configure_settings({})

func _observe_trail(simulation, delta: float) -> void:
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_entities_step(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, delta
	)

func _check_same_team_trail_isolation() -> void:
	BallRegistry.configure_settings({"frost": {"max_ice_zones": 1}})
	var setup: BattleSetup = BattleSetup.team_brawl(["frost", "frost"], ["test_ball"])
	var simulation := BattleSimulationScript.new(20300109, setup)
	var first = simulation.fighters[0]
	var second = simulation.fighters[1]
	var enemy = simulation.fighters[2]
	var first_ability = simulation.ability_for_fighter(first)
	var second_ability = simulation.ability_for_fighter(second)
	var second_zone: BallEntity = second_ability._owned_ice_zones(simulation.battle_context, second)[0]
	first_ability._spawn_ice_zone(simulation.battle_context, Vector2(320.0, 320.0), first, Vector2.RIGHT)
	_check(not second_zone.removed, "同队寒冰球各自维护轨迹数量上限，不会删除队友轨迹")
	_check(simulation.entity_list(0, "frost_ice_trail").size() == 2, "同队两个寒冰球分别保留自己的轨迹")
	enemy.pos = Vector2(320.0, 320.0)
	first_ability.after_entities_step(simulation.battle_context, first, enemy, 0, 0.0)
	second_ability.after_entities_step(simulation.battle_context, second, enemy, 0, 0.0)
	first_ability.after_entities_step(simulation.battle_context, first, enemy, 0, 0.6)
	second_ability.after_entities_step(simulation.battle_context, second, enemy, 0, 0.6)
	_check(not simulation.has_status(enemy, HardFreezeStatus.KEY), "同队多寒冰球不会合并或加速同一个接触计时")
	_check(second_ability._trail_contact_seconds.is_empty(), "未接触到的队友轨迹不会错误获得接触进度")
	BallRegistry.configure_settings({})

func _check_body_contact_has_no_direct_damage() -> void:
	var simulation := BattleSimulationScript.new(20300102, "frost", "test_ball")
	for zone: BallEntity in simulation.entity_list(0, "frost_ice_trail"):
		zone.removed = true
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(300.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(350.0, 320.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(196.0, 0.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(-180.0, 0.0)
	var hp_before := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	simulation._contact_timers.clear()
	simulation._resolve_fighter_pair(simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id))
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).hp, hp_before), "寒冰球撞击瞬间不重复结算直接伤害")
	_check(simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), HardFreezeStatus.KEY), "寒冰球本体撞击会施加完全冰冻")
	_check(simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), IceSlowStatusEffectScript.KEY), "寒冰球本体撞击会施加寒冰减速")

func _check_damageable_attachment_support() -> void:
	BallRegistry.configure_settings({
		"splitter": {
			"cooldown": 60.0,
			"clone_max_hp": 20.0,
			"clone_min_speed": 120.0,
			"clone_max_speed": 120.0,
			"damage_split_chance": 0.0,
		},
	})
	var simulation := BattleSimulationScript.new(20300103, "frost", "splitter")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[1].team_id)).activate(simulation.battle_context, simulation.fighter_for_side(simulation.teams[1].team_id), simulation.fighter_for_side(simulation.teams[0].team_id), 1)
	var clones: Array[BallEntity] = simulation.entity_list(1, "splitter_clone")
	_check(not clones.is_empty(), "分身球生成真实可受击附属物")
	if clones.is_empty():
		return
	for zone: BallEntity in simulation.entity_list(0, "frost_ice_trail"):
		zone.removed = true
	var clone: BallEntity = clones[0]
	clone.pos = simulation.fighter_for_side(simulation.teams[0].team_id).pos
	clone.velocity = Vector2(120.0, 0.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		0.2
	)
	_check(simulation.has_status(clone, HardFreezeStatus.KEY), "寒冰球与物理附属物接触时按通用能力施加冰冻")
	_check(simulation.has_status(clone, IceSlowStatusEffectScript.KEY), "可受击附属物也获得寒冰减速")
	var status_count := clone.status_effects.size()
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		0.2
	)
	_check(clone.status_effects.size() == status_count, "持续接触只刷新状态而不创建重复层")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(520.0, 520.0)
	var start := clone.pos
	clone.process_step(simulation.battle_context, 0.5)
	_check(clone.pos.is_equal_approx(start), "完全冰冻把附属物的行动步长降为零")
	var hp_before := float(clone.get("hp"))
	simulation._update_status_effects(clone, 1.01)
	_check(is_equal_approx(hp_before - float(clone.get("hp")), 2.0), "附属物按同一冰冻配置承受持续伤害")

func _check_persistent_settings_isolation() -> void:
	BallRegistry.configure_settings({
		"frost": {
			"max_hp": 177.0,
			"trail_freeze_delay": 1.7,
			"freeze_duration": 3.5,
			"freeze_damage": 7.0,
			"slow_multiplier": 0.4,
		},
	})
	var settings_path := "user://frost-delay-test-%s.json" % OS.get_process_id()
	_check(SettingsStore.save_settings(BallRegistry.settings_snapshot(), settings_path) == OK, "接触阈值可以写入持久化配置")
	BallRegistry.configure_settings(SettingsStore.load_settings(settings_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	var flame_match := BattleSimulationScript.new(20300104, "frost", "flame")
	var plant_match := BattleSimulationScript.new(20300105, "frost", "plant")
	for simulation in [flame_match, plant_match]:
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).max_hp, 177.0), "寒冰球生命配置跨对手保持生效")
		_check(is_equal_approx(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("trail_freeze_delay"), 1.7), "接触阈值保存重载后跨对手保持生效")
		_check(is_equal_approx(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("freeze_duration"), 3.5), "寒冰球冰冻配置跨对手保持生效")
		_check(is_equal_approx(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("freeze_damage"), 7.0), "寒冰球伤害配置跨对手保持生效")
	_check(is_equal_approx(flame_match.fighter_for_side(flame_match.teams[1].team_id).max_hp, 100.0), "寒冰球配置不会串改火焰球")
	_check(is_equal_approx(plant_match.fighter_for_side(plant_match.teams[1].team_id).max_hp, 100.0), "寒冰球配置不会串改植物球")
	var zone: BallEntity = flame_match.entity_list(0, "frost_ice_trail")[0]
	flame_match.fighter_for_side(flame_match.teams[0].team_id).pos = Vector2(520.0, 520.0)
	flame_match.fighter_for_side(flame_match.teams[1].team_id).pos = zone.pos
	_observe_trail(flame_match, 0.0)
	_observe_trail(flame_match, 1.6)
	_check(not flame_match.has_status(flame_match.fighter_for_side(flame_match.teams[1].team_id), HardFreezeStatus.KEY), "自定义接触时间前不会提前冰冻")
	_observe_trail(flame_match, 0.1)
	_check(flame_match.has_status(flame_match.fighter_for_side(flame_match.teams[1].team_id), HardFreezeStatus.KEY), "按保存的自定义接触时间触发冰冻")

func _check_determinism() -> void:
	BallRegistry.configure_settings({})
	var first := BattleSimulationScript.new(20300106, "frost", "test_ball")
	var replay := BattleSimulationScript.new(20300106, "frost", "test_ball")
	for _frame in range(480):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
	_check(first.snapshot() == replay.snapshot(), "寒冰球在相同配置和种子下可完全重放")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
