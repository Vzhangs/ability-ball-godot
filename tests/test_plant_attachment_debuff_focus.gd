extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const PlantPeaProjectileEntity := preload("res://scripts/balls/plant/pea_projectile_entity.gd")
const IceSlowStatusEffectScript := preload("res://scripts/balls/core/ice_slow_status_effect.gd")

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({
		"plant": {"cooldown": 60.0},
		"splitter": {
			"cooldown": 60.0,
			"clone_max_hp": 20.0,
			"clone_min_speed": 120.0,
			"clone_max_speed": 120.0,
			"damage_split_chance": 0.0,
		},
	})
	_check_fire_debuff()
	_check_ice_debuff()
	_check_ice_slow_does_not_stack()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("PLANT_ATTACHMENT_DEBUFF_FOCUS_OK")
		quit(0)
		return
	for failure in failures:
		push_error("TEST FAILED: " + failure)
	quit(1)

func _check_fire_debuff() -> void:
	var simulation = _simulation_with_splitter_clones(20261237)
	var target: BallEntity = simulation.entity_list(1, "splitter_clone")[0]
	var hp_before := float(target.get("hp"))
	var projectile := _projectile("fire", 2.0, 1.0, 0.0, 1.0, 1.0, 4.0)
	simulation.add_entity(projectile)
	projectile.process_step(simulation.battle_context, 0.25)
	_check(projectile.removed, "火豌豆被分身阻挡后消除")
	_check(is_equal_approx(hp_before - float(target.get("hp")), 2.0), "火豌豆先结算直接伤害")
	_check(simulation.has_status(target, "burn_0_plant_fire_pea"), "火豌豆给分身施加灼烧")
	var hp_before_tick := float(target.get("hp"))
	for _frame in range(20):
		simulation.step(0.05)
	_check(is_equal_approx(hp_before_tick - float(target.get("hp")), 1.0), "分身按配置承受灼烧持续伤害")

func _check_ice_debuff() -> void:
	var simulation = _simulation_with_splitter_clones(20261238)
	var target: BallEntity = simulation.entity_list(1, "splitter_clone")[0]
	var projectile := _projectile("ice", 1.0, 0.5, 2.0, 0.0, 1.0, 0.0)
	simulation.add_entity(projectile)
	projectile.process_step(simulation.battle_context, 0.25)
	_check(simulation.has_status(target, IceSlowStatusEffectScript.KEY), "冰豌豆给分身施加通用寒冰减速")
	var refreshed_effect = simulation.apply_status(
		target,
		IceSlowStatusEffectScript.new(4.0, 2, 0.5)
	)
	_check(target.status_effects.size() == 1, "不同来源的寒冰命中在附属物上只保留一个状态")
	_check(is_equal_approx(refreshed_effect.entity_step_multiplier(), 0.5), "重复寒冰命中只刷新附属物的同一减速倍率")
	var start := target.pos
	target.process_step(simulation.battle_context, 0.2)
	_check(is_equal_approx(target.pos.distance_to(start), 12.0), "寒冰把分身行动步长降到 0.5 倍")

func _check_ice_slow_does_not_stack() -> void:
	var simulation := BattleSimulationScript.new(20261239, "plant", "test_ball")
	var target = simulation.fighter_for_side(simulation.teams[1].team_id)
	target.velocity = Vector2(200.0, 0.0)
	var effect: BallStatusEffect = simulation.apply_status(
		target,
		IceSlowStatusEffectScript.new(3.0, 0, 0.65)
	)
	effect.tick(simulation.battle_context, target, 0.01)
	_check(is_equal_approx(target.velocity.length(), 130.0), "首次寒冰按未减速速度应用倍率")
	var first_baseline := float(effect.call("baseline_speed"))
	var refreshed: BallStatusEffect = simulation.apply_status(
		target,
		IceSlowStatusEffectScript.new(5.0, 2, 0.65)
	)
	refreshed.tick(simulation.battle_context, target, 0.01)
	_check(refreshed == effect and target.status_effects.size() == 1, "同源和跨来源寒冰共享唯一状态实例")
	_check(is_equal_approx(target.velocity.length(), 130.0), "相同倍率寒冰重复命中不会从 65% 再乘到 42%")
	_check(is_equal_approx(float(refreshed.call("baseline_speed")), first_baseline), "刷新寒冰不会拿已减速速度覆盖原始基准")
	var stronger: BallStatusEffect = simulation.apply_status(
		target,
		IceSlowStatusEffectScript.new(4.0, 3, 0.5)
	)
	stronger.tick(simulation.battle_context, target, 0.01)
	_check(is_equal_approx(target.velocity.length(), 100.0), "更强寒冰只按原始基准采用一次最强倍率")
	var weaker: BallStatusEffect = simulation.apply_status(
		target,
		IceSlowStatusEffectScript.new(6.0, 4, 0.8)
	)
	weaker.tick(simulation.battle_context, target, 0.01)
	_check(is_equal_approx(target.velocity.length(), 100.0), "较弱寒冰刷新时间但不会覆盖或叠加当前最强减速")
	_check(weaker.remaining > 5.9, "重复寒冰命中会刷新同一状态的剩余时间")

func _simulation_with_splitter_clones(seed: int):
	var simulation := BattleSimulationScript.new(seed, "plant", "splitter")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[1].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[1].team_id),
		simulation.fighter_for_side(simulation.teams[0].team_id),
		1
	)
	var clones: Array[BallEntity] = simulation.entity_list(1, "splitter_clone")
	_check(clones.size() >= 2, "生成真实分身")
	if clones.size() < 2:
		return simulation
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(80.0, 500.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(560.0, 500.0)
	clones[0].pos = Vector2(320.0, 120.0)
	clones[0].velocity = Vector2(0.0, 120.0)
	clones[1].pos = Vector2(560.0, 80.0)
	return simulation

func _projectile(
	kind: String,
	damage: float,
	ice_multiplier: float,
	ice_duration: float,
	burn_damage: float,
	burn_interval: float,
	burn_duration: float
) -> BallEntity:
	return PlantPeaProjectileEntity.new(
		0,
		Vector2(260.0, 120.0),
		Vector2(300.0, 0.0),
		5.0,
		damage,
		Color("ff6724" if kind == "fire" else "73e9ff"),
		2.0,
		kind,
		ice_multiplier,
		ice_duration,
		burn_damage,
		burn_interval,
		burn_duration,
		20.0
	)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
