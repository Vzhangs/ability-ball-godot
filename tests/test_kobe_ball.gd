extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

class DamageableFixtureEntity:
	extends BallEntity

	var hp := 30.0

	func _init(spawn_side: int, spawn_position: Vector2) -> void:
		owner_side = spawn_side
		pos = spawn_position
		radius = 8.0
		tags = PackedStringArray(["kobe_test_fixture"])

	func can_receive_attack(source_side: int) -> bool:
		return not removed and is_hostile_to(source_side)

	func receive_attack(
		_battle,
		amount: float,
		_source_side: int,
		_hit_color: Color
	) -> float:
		var applied := minf(hp, maxf(0.0, amount))
		hp -= applied
		if hp <= 0.0:
			removed = true
		return applied

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_module_contract()
	_check_alternating_named_moves_and_voice()
	_check_cyclone_and_elbow_gameplay()
	_check_persistent_settings_and_determinism()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_KOBE_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_KOBE_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_module_contract() -> void:
	var module: BallModule = BallRegistry.get_module("kobe")
	_check(module != null and module.display_name == "科比球", "科比球由目录模块自动发现")
	_check(is_equal_approx(module.max_hp, 100.0), "科比球默认生命为 100")
	_check(is_equal_approx(module.cooldown, 3.8), "科比球默认每 3.8 秒轮换一次玩梗招式")
	for key in [
		"cyclone_duration", "cyclone_speed", "cyclone_damage", "cyclone_reach",
		"cyclone_knockback", "elbow_windup_duration", "elbow_reach",
		"elbow_damage", "elbow_knockback", "cast_name_duration",
	]:
		_check(module.setting_specs().has(key), "科比球配置 Schema 包含 %s" % key)
	_check(module.audio_samples().has("kobe_cyclone_voice"), "闪电旋风劈声明曼巴 out 语音")
	_check(module.audio_samples().has("kobe_elbow_voice"), "肘击声明 man 语音")
	_check(module.ability_description.contains("闪电旋风劈") \
		and module.ability_description.contains("肘击") \
		and module.ability_description.contains("附属单位"),
		"公开简介面向观众讲清两招与有效目标")
	var ability: BallAbility = module.create_ability()
	_check(is_zero_approx(ability.contact_damage(null, null, null)), "科比球普通本体碰撞没有伤害")
	_check(module.create_visual(ability) is BallVisual, "科比球装载独立紫金视觉")

func _check_alternating_named_moves_and_voice() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270910, "kobe", "test_ball")
	simulation.take_combat_events()
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0
	)
	_check(String(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("active_move")) == "cyclone", "第一招固定为闪电旋风劈")
	_check(String(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("next_move")) == "elbow", "闪电旋风劈后轮到肘击")
	_check(simulation.count_entities(0, "named_cast_vfx") == 1, "闪电旋风劈显示招式名")
	_check(simulation.count_entities(0, "kobe_cyclone_vfx") == 1, "闪电旋风劈生成旋转闪电视觉")
	_check(
		_count_combat_events(simulation.take_combat_events(), "kobe_cyclone_voice") == 1,
		"闪电旋风劈播放一次曼巴 out"
	)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, 1.0
	)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0
	)
	_check(String(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("active_move")) == "elbow", "第二招固定为肘击")
	_check(String(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("next_move")) == "cyclone", "肘击后轮回闪电旋风劈")
	_check(simulation.count_entities(0, "named_cast_vfx") == 2, "肘击同样显示招式名")
	_check(simulation.count_entities(0, "kobe_elbow_vfx") == 1, "肘击生成前伸手肘视觉")
	_check(
		_count_combat_events(simulation.take_combat_events(), "kobe_elbow_voice") == 1,
		"肘击播放一次 man"
	)

func _check_cyclone_and_elbow_gameplay() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270911, "kobe", "test_ball")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(300.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(368.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2.ZERO
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0
	)
	var hp_before: float = simulation.fighter_for_side(simulation.teams[1].team_id).hp
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(hp_before - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 9.0), "闪电旋风劈扫到敌方主球造成 9 点伤害")
	_check(simulation.fighter_for_side(simulation.teams[1].team_id).velocity.x > 0.0, "闪电旋风劈把敌方主球向外掀开")
	var after_first_sweep: float = simulation.fighter_for_side(simulation.teams[1].team_id).hp
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).hp, after_first_sweep), "同一次旋风劈不会持续重复伤害同一目标")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, 1.0
	)

	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(300.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(378.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2.ZERO
	var fixture := DamageableFixtureEntity.new(1, Vector2(352.0, 320.0))
	fixture.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
	simulation.add_entity(fixture)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0
	)
	hp_before = simulation.fighter_for_side(simulation.teams[1].team_id).hp
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0,
		0.19
	)
	_check(is_equal_approx(hp_before - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 13.0), "肘击面前线段命中主球造成 13 点伤害")
	_check(is_equal_approx(fixture.hp, 17.0), "肘击也会命中挡在面前的敌方附属单位")
	_check(simulation.fighter_for_side(simulation.teams[1].team_id).velocity.x > 0.0 and fixture.velocity.x > 0.0, "肘击同时击退主球和附属单位")

func _check_persistent_settings_and_determinism() -> void:
	BallRegistry.configure_settings({
		"kobe": {
			"max_hp": 166.0,
			"speed": 286.0,
			"cyclone_damage": 21.0,
			"elbow_damage": 25.0,
		},
	})
	var configured := BattleSimulationScript.new(20270912, "kobe", "plant")
	_check(is_equal_approx(configured.fighter_for_side(configured.teams[0].team_id).max_hp, 166.0), "科比球生命配置跨对手保持一致")
	_check(is_equal_approx(configured.fighter_for_side(configured.teams[0].team_id).base_speed, 286.0), "科比球速度配置跨对手保持一致")
	_check(is_equal_approx(configured.module_for_fighter(configured.fighter_for_side(configured.teams[0].team_id)).settingf("cyclone_damage"), 21.0), "旋风劈伤害使用科比球自己的持久化配置")
	_check(is_equal_approx(configured.module_for_fighter(configured.fighter_for_side(configured.teams[0].team_id)).settingf("elbow_damage"), 25.0), "肘击伤害使用科比球自己的持久化配置")
	_check(is_equal_approx(configured.fighter_for_side(configured.teams[1].team_id).max_hp, 100.0), "科比球配置不会串改植物球")
	BallRegistry.configure_settings({})
	var first := BattleSimulationScript.new(20270913, "kobe", "gojo")
	var replay := BattleSimulationScript.new(20270913, "kobe", "gojo")
	for _frame in range(1200):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
		if first.finished and replay.finished:
			break
	_check(first.snapshot() == replay.snapshot(), "科比球相同种子与配置可完全重放")

func _count_combat_events(events: Array[Dictionary], kind: String) -> int:
	var count := 0
	for event: Dictionary in events:
		if String(event.get("kind", "")) == kind:
			count += 1
	return count

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
