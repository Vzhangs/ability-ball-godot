extends SceneTree

const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
const Setup := preload("res://scripts/simulation/battle_setup.gd")
const Settings := preload("res://scripts/settings/ball_settings_store.gd")
const Shield := preload("res://scripts/balls/core/invulnerability_status_effect.gd")

class Unit extends BallEntity:
	var hp := 40.0
	func _init(side: int, at: Vector2) -> void:
		owner_side = side
		pos = at
		radius = 10.0
	func combat_category() -> Dictionary:
		return {"id": "prism_fixture", "name": "测试单位"}
	func is_absorbable() -> bool:
		return true
	func can_receive_attack(side: int) -> bool:
		return not removed and not is_captured() and side != owner_side and hp > 0.0
	func receive_attack(_battle, amount: float, _side: int, _color: Color) -> float:
		var applied := minf(hp, amount)
		hp -= applied
		removed = hp <= 0.0
		return applied

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_contract()
	_check_spawn_audio_lifecycle()
	_check_charge_and_single_target()
	_check_refraction_and_shield()
	_check_blockers_and_no_recursive_chain()
	_check_target_cancellation()
	_check_target_priority_and_parameter_edges()
	_check_real_attachments()
	_check_team_identity_and_report()
	_check_additional_modes()
	_check_settings_and_determinism()
	_check_representative_matches()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_PRISM_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _check_contract() -> void:
	var module: BallModule = BallRegistry.get_module("prism")
	_check(module != null and module.display_name == "光棱球", "球库自动发现光棱球")
	_check(module.validation_errors().is_empty(), "参数与观众简介符合模块约束")
	_eq(module.max_hp, 100.0, "默认本体生命")
	_eq(module.create_ability().contact_damage(null, null, null), 0.0, "普通本体接触无伤害")
	for key in ["opening_delay", "charge_duration", "attack_range", "main_damage", "beam_half_width", "refraction_count", "refraction_range", "refraction_damage", "beam_duration"]:
		_check(module.setting_specs().has(key), "可配置参数：" + key)
	var samples := module.audio_samples()
	_check(samples.size() == 4 and module.sound_kind.is_empty(), "出场、蓄能、放电、命中分别显式触发，不重复播自动技能声")
	var duration_ranges := {"prism_spawn": Vector2(1.30, 1.40), "prism_charge": Vector2(0.30, 0.34), "prism_fire": Vector2(1.80, 1.90), "prism_hit": Vector2(0.20, 0.24)}
	for event in duration_ranges:
		var stream := samples[event].stream as AudioStreamOggVorbis
		var bounds: Vector2 = duration_ranges[event]
		_check(stream != null and stream.get_length() >= bounds.x and stream.get_length() <= bounds.y and not stream.loop, event + " 使用对应时长的单次采样")

func _check_spawn_audio_lifecycle() -> void:
	var sim := _duel()
	_eq(_event_count(sim.take_combat_events(), "prism_spawn"), 1.0, "实际出场立即发送一次单位语音")
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_battle_started(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	_eq(_event_count(sim.take_combat_events(), "prism_spawn"), 0.0, "同一个本体重复初始化不会重播报到")
	_begin(sim)
	_finish_charge(sim)
	_eq(_event_count(sim.take_combat_events(), "prism_spawn"), 0.0, "开炮不会重播出场语音")
	sim.reset(45, "prism", "test_ball")
	_eq(_event_count(sim.take_combat_events(), "prism_spawn"), 1.0, "重开后的新本体正常报到")
	var module: BallModule = BallRegistry.get_module("prism")
	module.create_visual(module.create_ability())
	_eq(_event_count(sim.take_combat_events(), "prism_spawn"), 0.0, "创建选球预览不会发送出场语音")
	var relay_setup := Setup.new(Setup.MODE_RELAY, [Setup.team(0, "红队", ["test_ball", "prism"]), Setup.team(1, "蓝队", ["test_ball"])])
	var relay := Simulation.new(27, relay_setup, 120.0, Vector2(440.0, 740.0), {"relay_handoff_pause_seconds": 0.05})
	relay.death_effect_duration = 0.05
	relay.handoff_pause_duration_seconds = 0.05
	_eq(_event_count(relay.take_combat_events(), "prism_spawn"), 0.0, "候补光棱球未上场时不提前播语音")
	relay.damage(relay.fighter_for_side(relay.teams[0].team_id), 10000.0, Color.WHITE, relay.fighter_for_side(relay.teams[1].team_id))
	for tick in range(12):
		relay.step()
	_check(relay.fighter_for_side(relay.teams[0].team_id).id == "prism", "擂台替补已完成死亡停顿并正式上场")
	_eq(_event_count(relay.take_combat_events(), "prism_spawn"), 1.0, "擂台候补真正出场时才报到")
	for setup in [Setup.free_for_all([["prism"], ["test_ball"], ["test_ball"]]), Setup.boss([["prism"], ["test_ball"], ["test_ball"]])]:
		var other := Simulation.new(33, setup, 120.0, Vector2(440.0, 740.0))
		_eq(_event_count(other.take_combat_events(), "prism_spawn"), 1.0, setup.mode + " 正常上场报到")
	var team_setup := Setup.new(Setup.MODE_TEAM_BRAWL, [Setup.team(0, "红队", ["prism", "prism"], 2), Setup.team(1, "蓝队", ["test_ball"])])
	var team := Simulation.new(34, team_setup, 120.0, Vector2(640.0, 640.0))
	_eq(_event_count(team.take_combat_events(), "prism_spawn"), 2.0, "同队两颗光棱球分别具有独立的出场生命周期")

func _duel(opponent: String = "test_ball") -> BattleSimulation:
	var sim := Simulation.new(2026091401, "prism", opponent)
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(100.0, 320.0)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(320.0, 320.0)
	return sim

func _begin(sim: BattleSimulation, source = null) -> BallAbility:
	var fighter = sim.fighter_for_side(sim.teams[0].team_id) if source == null else source
	var ability: BallAbility = sim.ability_for_fighter(fighter)
	ability.activate(sim.battle_context, fighter, sim.nearest_hostile_fighter(fighter), fighter.team_id)
	return ability

func _finish_charge(sim: BattleSimulation, source = null) -> void:
	var fighter = sim.fighter_for_side(sim.teams[0].team_id) if source == null else source
	var ability: BallAbility = sim.ability_for_fighter(fighter)
	ability.on_step(sim.battle_context, fighter, sim.nearest_hostile_fighter(fighter), fighter.team_id, ability.settingf("charge_duration") + 0.001)

func _unit(sim: BattleSimulation, side: int, at: Vector2) -> Unit:
	var unit := Unit.new(side, at)
	sim.add_entity(unit)
	return unit

func _check_charge_and_single_target() -> void:
	var sim := _duel()
	var original_hp := sim.fighter_for_side(sim.teams[1].team_id).hp
	var ability := _begin(sim)
	_check(bool(ability.call("is_charging")), "先蓄能再攻击")
	_eq(sim.fighter_for_side(sim.teams[1].team_id).hp, original_hp, "蓄能开始不扣血")
	ability.on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.37)
	_eq(sim.fighter_for_side(sim.teams[1].team_id).hp, original_hp, "蓄能结束前仍不扣血")
	ability.on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	_eq(original_hp - sim.fighter_for_side(sim.teams[1].team_id).hp, 16.0, "主击伤害只结算一次")
	_eq(float(ability.call("shots_fired")), 1.0, "记录实际开炮")
	var effects := sim.entity_list(0, "prism_beam_vfx")
	_check(effects.size() == 1, "只有一个本轮光束表现实体")
	_check(not effects[0].is_absorbable() and not effects[0].can_transfer_ownership(), "瞬时攻击的余光不伪装为实体子弹或可控制附属物")
	sim.fighter_for_side(sim.teams[0].team_id).ability_timer = 999.0
	sim.fighter_for_side(sim.teams[1].team_id).ability_timer = 999.0
	for index in range(120):
		sim.step()
	_eq(original_hp - sim.fighter_for_side(sim.teams[1].team_id).hp, 16.0, "余光期间不持续扣血")
	_check(sim.entity_list(0, "prism_beam_vfx").is_empty(), "光束按期清理")
	_check(sim.entity_list(0, "prism_charge_vfx").is_empty(), "蓄能标志结束后清理")
	var events := sim.take_combat_events()
	for event in ["prism_charge", "prism_fire", "prism_hit"]:
		_eq(_event_count(events, event), 1.0, event + " 每轮只触发一次")

func _check_refraction_and_shield() -> void:
	var sim := _duel()
	var nearby := [
		_unit(sim, 1, Vector2(410.0, 320.0)),
		_unit(sim, 1, Vector2(375.0, 250.0)),
		_unit(sim, 1, Vector2(375.0, 390.0)),
	]
	var overflow := _unit(sim, 1, Vector2(450.0, 430.0))
	var friendly := _unit(sim, 0, Vector2(240.0, 320.0))
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), Shield.new(2.0, 1, "prism_test_shield"))
	_begin(sim)
	_finish_charge(sim)
	_eq(sim.fighter_for_side(sim.teams[1].team_id).hp, 1000.0, "无敌主球真实免伤")
	for unit in nearby:
		_eq(unit.hp, 33.0, "附近敌方附属物各受一次折射")
	_eq(overflow.hp, 40.0, "折射数量有上限且优先近处")
	_eq(friendly.hp, 40.0, "前方友军既不挡主击也不被折射误伤")
	_eq(float(sim.stats.get("prism_refraction_hits", 0)), 3.0, "折射不计入主击的同一目标")

func _check_blockers_and_no_recursive_chain() -> void:
	var sim := _duel()
	var blocker := _unit(sim, 1, Vector2(220.0, 320.0))
	blocker.hp = 10.0
	_begin(sim)
	_finish_charge(sim)
	_eq(blocker.hp, 0.0, "前方附属物承受主击而不是穿过后方主球")
	_eq(sim.fighter_for_side(sim.teams[1].team_id).hp, 993.0, "阻挡者被击毁后仍能从命中处折射到后方主球")
	var chain := _duel()
	var first := _unit(chain, 1, Vector2(480.0, 320.0))
	var second := _unit(chain, 1, Vector2(625.0, 320.0))
	_begin(chain)
	_finish_charge(chain)
	_eq(first.hp, 33.0, "主命中附近发生折射")
	_eq(second.hp, 40.0, "不会从折射目标继续递归连锁")

func _check_target_cancellation() -> void:
	for reason in ["captured", "transferred", "dead", "out_of_range", "caster_dead"]:
		var sim := _duel()
		sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(620.0, 320.0)
		var target := _unit(sim, 1, Vector2(260.0, 320.0))
		var ability := _begin(sim)
		_check(ability.get("_target") == target, "主球超出射程时主动选择附属物")
		match reason:
			"captured": target.disable_for_capture()
			"transferred": target.transfer_ownership(0, sim.fighter_for_side(sim.teams[0].team_id))
			"dead": target.hp = 0.0
			"out_of_range": target.pos = Vector2(590.0, 320.0)
			"caster_dead": sim.fighter_for_side(sim.teams[0].team_id).hp = 0.0
		_finish_charge(sim)
		_check(not bool(ability.call("is_charging")), reason + " 取消蓄能")
		_eq(float(ability.call("shots_fired")), 0.0, reason + " 不产生无效攻击")
		_eq(_event_count(sim.take_combat_events(), "prism_fire"), 0.0, reason + " 不播放放电声")

func _check_target_priority_and_parameter_edges() -> void:
	var sim := _duel()
	var closer := _unit(sim, 1, Vector2(150.0, 250.0))
	var ability := _begin(sim)
	_check(ability.get("_target") == sim.fighter_for_side(sim.teams[1].team_id), "更近的附属物不抢占射程内主球的瞄准优先级")
	_finish_charge(sim)
	_eq(sim.fighter_for_side(sim.teams[1].team_id).hp, 984.0, "主球承受主击")
	_eq(closer.hp, 40.0, "不在折射范围内的附属物不受伤")
	BallRegistry.configure_settings({"prism": {"refraction_count": 0, "charge_duration": 0.05}})
	var no_refraction := _duel()
	var nearby := _unit(no_refraction, 1, Vector2(360.0, 380.0))
	_begin(no_refraction)
	_finish_charge(no_refraction)
	_eq(no_refraction.fighter_for_side(no_refraction.teams[1].team_id).hp, 984.0, "最短蓄能仍正确结算主击")
	_eq(nearby.hp, 40.0, "折射上限为零时真正关闭折射")
	BallRegistry.configure_settings({"prism": {"charge_duration": 4.0, "cooldown": 0.1}})
	var long_charge := _duel()
	long_charge.fighter_for_side(long_charge.teams[0].team_id).ability_timer = 0.0
	long_charge.fighter_for_side(long_charge.teams[1].team_id).ability_timer = 999.0
	for fighter in long_charge.active_fighters():
		fighter.base_speed = 0.0
		fighter.minimum_speed = 0.0
		fighter.maximum_speed = 0.0
		fighter.velocity = Vector2.ZERO
	for tick in range(486):
		long_charge.step()
	_check(int(long_charge.stats.get("prism_shots", 0)) >= 2, "蓄能长于冷却时不会反复重置而永远无法开炮")
	BallRegistry.configure_settings({})

func _check_real_attachments() -> void:
	for opponent_id in ["splitter", "plant"]:
		var sim := _duel(opponent_id)
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[1].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[1].team_id), sim.fighter_for_side(sim.teams[0].team_id), 1)
		var units := sim.entity_list(1, "splitter_clone" if opponent_id == "splitter" else "plant_attachment")
		_check(not units.is_empty(), opponent_id + " 创建真实附属物")
		var target: BallEntity = units[0]
		if opponent_id == "plant":
			_check(not target.can_receive_attack(0), "种子不能被光棱攻击选为受击物")
			target.step(sim.battle_context, 10.0)
		target.pos = Vector2(230.0, 320.0)
		_begin(sim)
		_finish_charge(sim)
		_eq(float(target.get("hp")), 0.0, opponent_id + " 附属物能够阻挡主击并正常扣血死亡")

func _check_team_identity_and_report() -> void:
	var setup := Setup.new(Setup.MODE_TEAM_BRAWL, [Setup.team(0, "红队", ["prism", "prism"], 2), Setup.team(1, "蓝队", ["test_ball"])])
	var sim := Simulation.new(75, setup, 120.0, Vector2(440.0, 740.0))
	var allies: Array = []
	for fighter in sim.active_fighters():
		if fighter.team_id == 0:
			allies.append(fighter)
	allies[0].pos = Vector2(80.0, 600.0)
	allies[1].pos = Vector2(120.0, 600.0)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(380.0, 50.0)
	var target := _unit(sim, 1, Vector2(300.0, 600.0))
	_begin(sim, allies[1])
	_finish_charge(sim, allies[1])
	_eq(target.hp, 24.0, "非正方形混战里的同队第二个光棱球可以开炮")
	_eq(float(sim.ability_for_fighter(allies[0]).call("shots_fired")), 0.0, "同队能力状态互不串球")
	for record in sim.combat_report().fighters:
		if int(record.fighter_uid) == int(allies[1].fighter_uid):
			_eq(float(record.totals.damage_dealt), 16.0, "附属物受伤归实际开炮者而非同队第一个主球")
		if int(record.fighter_uid) == int(allies[0].fighter_uid):
			_eq(float(record.totals.damage_dealt), 0.0, "旁边的同队主球不冒领输出")

func _check_additional_modes() -> void:
	var rosters := [["test_ball"], ["test_ball"], ["prism"], ["test_ball"]]
	for setup in [Setup.free_for_all(rosters), Setup.boss(rosters)]:
		var sim := Simulation.new(571, setup, 120.0, Vector2(440.0, 740.0))
		var source = sim.fighter_for_side(2)
		source.pos = Vector2(100.0, 370.0)
		var primary = sim.fighter_for_side(0)
		var upper = sim.fighter_for_side(1)
		var lower = sim.fighter_for_side(3)
		primary.pos = Vector2(280.0, 370.0)
		upper.pos = Vector2(340.0, 300.0)
		lower.pos = Vector2(340.0, 440.0)
		var health := [primary.hp, upper.hp, lower.hp, source.hp]
		_begin(sim, source)
		_finish_charge(sim, source)
		_eq(health[0] - primary.hp, 16.0, setup.mode + " 第三阵营的主击")
		_eq(health[1] - upper.hp, 7.0, setup.mode + " 折射可命中另一阵营")
		_eq(health[2] - lower.hp, 7.0, setup.mode + " 折射可命中第四阵营")
		_eq(source.hp, health[3], setup.mode + " 不反伤自己")

func _check_settings_and_determinism() -> void:
	var path := "user://prism_settings_test_%d.json" % OS.get_process_id()
	var overrides := {"prism": {"max_hp": 230.0, "charge_duration": 0.2, "main_damage": 23.0, "refraction_count": 5, "refraction_damage": 4.0, "attack_range": 500.0}}
	_check(Settings.save_settings(overrides, path) == OK, "按球配置可以持久化")
	BallRegistry.configure_settings(Settings.load_settings(path))
	var sim := _duel()
	_eq(sim.fighter_for_side(sim.teams[0].team_id).max_hp, 230.0, "重载后使用自己的血量配置")
	_begin(sim)
	_finish_charge(sim)
	_eq(sim.fighter_for_side(sim.teams[1].team_id).hp, 977.0, "重载后主击使用自己的伤害配置")
	_eq(BallRegistry.get_module("vampire").max_hp, 100.0, "不覆盖其他球配置")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	BallRegistry.configure_settings({})
	var first := _duel("plant")
	var second := _duel("plant")
	for tick in range(1200):
		first.step()
		second.step()
	_check(first.snapshot() == second.snapshot(), "同种子重放完全一致")

func _check_representative_matches() -> void:
	for opponent in ["garen", "sniper", "plant"]:
		var sim := _duel(opponent)
		for tick in range(15000):
			if sim.finished:
				break
			sim.step()
		_check(sim.finished, "代表性对战正常结算：" + opponent)
		_check(int(sim.stats.get("prism_shots", 0)) > 0, "代表性对战真实开炮：" + opponent)

func _event_count(events: Array, kind: String) -> float:
	var count := 0.0
	for event in events:
		if String(event.kind) == kind:
			count += 1.0
	return count

func _eq(actual: float, expected: float, label: String) -> void:
	_check(is_equal_approx(actual, expected), "%s：实际 %s，预期 %s" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
