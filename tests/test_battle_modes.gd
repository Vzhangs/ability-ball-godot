extends SceneTree

const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

var failures: Array[String] = []

class OwnedFixtureEntity extends BallEntity:
	func _init(team_id: int, position: Vector2) -> void:
		owner_side = team_id
		pos = position
		radius = 4.0
		tags = PackedStringArray(["mode_owned_fixture"])

class PersistentFixtureStatus extends BallStatusEffect:
	func _init() -> void:
		key = "relay_opponent_state_fixture"
		remaining = 30.0

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_setup_contracts()
	_check_relay_replacement_is_local()
	_check_relay_simultaneous_deaths_wait_for_available_replacement()
	_check_simultaneous_total_elimination_is_draw()
	_check_free_for_all_targeting_and_result()
	_check_team_brawl_has_independent_fighters()
	_check_train_conductor_instances_are_local()
	_check_execution_scope_distinguishes_same_team_creators()
	_check_timeout_counts_queued_roster_hp()
	_check_multi_fighter_determinism()
	_check_real_ability_mode_smoke()
	if failures.is_empty():
		print("ABILITY_BALL_BATTLE_MODES_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_BATTLE_MODES_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_setup_contracts() -> void:
	var duel = BattleSetupScript.duel("test_ball", "wdc")
	var relay = BattleSetupScript.relay(["test_ball", "wdc"], ["test_ball", "sonic"])
	var free_for_all = BattleSetupScript.free_for_all([["test_ball"], ["wdc"], ["sonic"]])
	var team_brawl = BattleSetupScript.team_brawl(["test_ball", "wdc"], ["sonic", "plant"])
	_check(duel.is_valid() and duel.mode == BattleSetupScript.MODE_DUEL, "一对一预设生成合法统一设置")
	_check(relay.is_valid() and relay.teams[0]["active_count"] == 1, "擂台预设每方只启用一个阵容位")
	_check(relay.teams[0]["name"] == "红队" and relay.teams[1]["name"] == "蓝队", "擂台运行时统一使用红队与蓝队命名")
	_check(relay.teams[0]["color"] == BattleSetupScript.RELAY_RED_TEAM_COLOR and relay.teams[1]["color"] == BattleSetupScript.RELAY_BLUE_TEAM_COLOR, "擂台运行时携带固定红蓝队色")
	var named_relay = BattleSetupScript.relay(
		["test_ball", "wdc"],
		["test_ball", "sonic"],
		["先锋队", "守擂队"]
	)
	_check(named_relay.teams[0]["name"] == "先锋队" and named_relay.teams[1]["name"] == "守擂队", "擂台支持独立自定义双方阵营名")
	_check(named_relay.teams[0]["color"] == BattleSetupScript.RELAY_RED_TEAM_COLOR and named_relay.teams[1]["color"] == BattleSetupScript.RELAY_BLUE_TEAM_COLOR, "自定义阵营名不会改变默认红蓝阵营色")
	_check(free_for_all.is_valid() and free_for_all.teams.size() == 3, "多方混战预设支持三个阵营")
	_check(
		free_for_all.teams[0]["name"] == "红队"
		and free_for_all.teams[1]["name"] == "蓝队"
		and free_for_all.teams[2]["name"] == "黄队",
		"多方混战使用观众可辨识的颜色队名而非阵营编号"
	)
	_check(
		free_for_all.teams[0]["color"] == BattleSetupScript.competitive_team_color(0)
		and free_for_all.teams[2]["color"] == BattleSetupScript.competitive_team_color(2),
		"多方混战队名与阵营色来自同一稳定映射"
	)
	var named_free_for_all = BattleSetupScript.free_for_all(
		[["test_ball"], ["wdc"], ["sonic"]],
		["疾风盟", "钢铁军", "植物团"]
	)
	_check(named_free_for_all.teams.map(func(team_spec: Dictionary) -> String: return String(team_spec["name"])) == ["疾风盟", "钢铁军", "植物团"], "多方混战每个阵营均可使用观众向自定义名称")
	_check(named_free_for_all.teams[2]["color"] == BattleSetupScript.competitive_team_color(2), "多方自定义名称不改变对应阵营标识颜色")
	_check(team_brawl.is_valid() and team_brawl.teams[0]["active_count"] == 2, "双方大混战让同队多个主球同时上场")
	_check(team_brawl.teams[0]["name"] == "红队" and team_brawl.teams[1]["name"] == "蓝队", "双方大混战不再使用左方右方命名")
	_check(team_brawl.teams[0]["color"] == BattleSetupScript.RELAY_RED_TEAM_COLOR and team_brawl.teams[1]["color"] == BattleSetupScript.RELAY_BLUE_TEAM_COLOR, "双方大混战固定携带红蓝队色")
	var sanitized_relay = BattleSetupScript.relay(["test_ball"], ["wdc"], ["  ", "蓝|色\n联盟"])
	_check(sanitized_relay.teams[0]["name"] == "红队", "自定义名留空时恢复该位置默认阵营名")
	_check(sanitized_relay.teams[1]["name"] == "蓝 色 联盟", "自定义名会移除录制参数分隔符与换行")
	_check(duel.teams[0]["name"] == "左方" and duel.teams[1]["name"] == "右方", "单挑保持固定左右方语义且不开放阵营改名")
	var invalid = BattleSetupScript.new(BattleSetupScript.MODE_FREE_FOR_ALL, [
		BattleSetupScript.team(0, "A", ["test_ball"]),
		BattleSetupScript.team(1, "B", ["missing_ball"]),
	])
	_check(not invalid.is_valid(), "非法阵营数量和未注册球种会在开局前被拒绝")

func _check_relay_replacement_is_local() -> void:
	var setup = BattleSetupScript.relay(["test_ball", "wdc"], ["test_ball", "sonic"])
	var simulation := BattleSimulationScript.new(20270824, setup, 60.0, Vector2(640.0, 640.0))
	simulation.death_effect_duration = 0.2
	simulation.handoff_pause_duration_seconds = 0.25
	var defeated = simulation.fighter_for_side(simulation.teams[0].team_id)
	var untouched = simulation.fighter_for_side(simulation.teams[1].team_id)
	var defeated_position := Vector2(214.0, 327.0)
	defeated.pos = defeated_position
	untouched.pos = Vector2(491.0, 288.0)
	untouched.velocity = Vector2(-123.0, 87.0)
	untouched.hp = 73.0
	untouched.ability_timer = 2.75
	untouched.rotation = 1.75
	untouched.hit_flash = 0.42
	untouched.trail.clear()
	untouched.trail.append(Vector2(480.0, 280.0))
	untouched.trail.append(Vector2(470.0, 276.0))
	var untouched_status := PersistentFixtureStatus.new()
	untouched.status_effects.append(untouched_status)
	var untouched_position: Vector2 = untouched.pos
	var untouched_velocity: Vector2 = untouched.velocity
	var untouched_ability = simulation.ability_for_fighter(untouched)
	var untouched_trail: Array[Vector2] = untouched.trail.duplicate()
	var owned_fixture := OwnedFixtureEntity.new(defeated.team_id, defeated.pos)
	var previous_scope = simulation.call("_set_execution_fighter", defeated)
	simulation.add_entity(owned_fixture)
	simulation.call("_set_execution_fighter", previous_scope)
	var untouched_fixture := OwnedFixtureEntity.new(untouched.team_id, untouched.pos)
	previous_scope = simulation.call("_set_execution_fighter", untouched)
	simulation.add_entity(untouched_fixture)
	simulation.call("_set_execution_fighter", previous_scope)
	_check(owned_fixture.owner_fighter_uid == defeated.fighter_uid, "附属实体自动记录真实创建主球 UID")
	_check(untouched_fixture.owner_fighter_uid == untouched.fighter_uid, "敌方附属实体记录敌方真实创建主球 UID")
	var impact_ring_count := simulation.impact_rings.size()
	var particle_count := simulation.particles.size()
	simulation.damage(defeated, defeated.hp, untouched.accent, untouched)
	simulation.call("_check_finish")
	_check(not simulation.finished, "擂台当前主球死亡但仍有候补时对局继续")
	_check(simulation.active_fighters().size() == 1 and simulation.active_fighters()[0] == untouched, "败者退场后先只保留原敌球，不把候补塞进败者爆炸中")
	_check(simulation.snapshot()["pending_replacements"].size() == 1, "败者死亡演出期间只排队一个本方候补")
	var notices := simulation.pending_replacement_notices()
	_check(notices.size() == 1, "擂台排队换人时公开一条观众提示所需的只读通知")
	if not notices.is_empty():
		_check(String(notices[0].get("defeated_display_name", "")) == defeated.display_name, "换人通知带有落败球名称")
		_check(String(notices[0].get("next_ball_id", "")) == "wdc", "换人通知带有下一位球 ID")
	_check(is_equal_approx(simulation.replacement_pause_remaining(), 0.25), "擂台采用独立的可配置落败停顿时长")
	var paused_elapsed := simulation.elapsed
	simulation.step(0.05)
	_check(is_equal_approx(simulation.elapsed, paused_elapsed), "擂台落败停顿期间不推进战斗时间")
	_check(simulation.fighter_for_side(simulation.teams[1].team_id) == untouched and untouched.pos == untouched_position and untouched.velocity == untouched_velocity, "擂台落败停顿期间幸存球完全停住")
	var death_effects := simulation.entity_list(defeated.team_id, "fighter_death_vfx")
	_check(death_effects.size() == 1, "单个败者只生成一次死亡演出")
	if not death_effects.is_empty():
		_check(not death_effects[0].draws_above_balls(), "死亡演出位于活跃主球下方，不会把幸存敌球伪装成同时爆炸")
	_check(simulation.impact_rings.size() == impact_ring_count and simulation.particles.size() == particle_count, "死亡演出不再额外生成覆盖相邻活球的全局上层爆炸")
	_check(int(simulation.stats.get("fighter_deaths", 0)) == 1, "局部淘汰只统计一个败者")
	var handoff_frames := 0
	while not simulation.snapshot()["pending_replacements"].is_empty() and handoff_frames < 30:
		simulation.step(BattleSimulation.FIXED_STEP)
		handoff_frames += 1
	_check(handoff_frames < 30, "擂台候补在死亡演出时限内完成接替")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).id == "wdc" and simulation.fighter_for_side(simulation.teams[0].team_id).fighter_uid != defeated.fighter_uid, "擂台按阵容顺序换入全新主球实例")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).pos.is_equal_approx(defeated_position), "候补球在阵亡位置接替")
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).hp, simulation.fighter_for_side(simulation.teams[0].team_id).max_hp), "候补球以自身完整生命和新状态上场")
	_check(simulation.fighter_for_side(simulation.teams[1].team_id) == untouched, "敌方主球对象没有被重建")
	_check(untouched.pos == untouched_position and untouched.velocity == untouched_velocity, "接替不会修改敌方位置和速度")
	_check(is_equal_approx(untouched.hp, 73.0) and is_equal_approx(untouched.ability_timer, 2.75), "接替不会修改敌方生命或技能计时")
	_check(is_equal_approx(untouched.rotation, 1.75) and is_equal_approx(untouched.hit_flash, 0.42), "接替不会修改敌方旋转或受击表现状态")
	_check(untouched.trail == untouched_trail and untouched.status_effects.has(untouched_status), "接替不会修改敌方轨迹或状态效果")
	_check(simulation.ability_for_fighter(untouched) == untouched_ability, "接替不会重建敌方能力私有状态")
	_check(not simulation.entities.has(owned_fixture), "阵亡主球仍归属自己的附属物会被局部清理")
	_check(simulation.entities.has(untouched_fixture), "接替不会清理敌方附属物")
	_check(simulation.active_fighters().size() == 2 and simulation.active_fighters().has(untouched), "接替后场上仍严格保持双方各一个活跃主球")
	_check(simulation.entity_list(defeated.team_id, "fighter_death_vfx").is_empty(), "候补只在败者死亡演出完整结束后入场")

func _check_relay_simultaneous_deaths_wait_for_available_replacement() -> void:
	var setup = BattleSetupScript.relay(["test_ball"], ["test_ball", "wdc"])
	var simulation := BattleSimulationScript.new(20270841, setup, 60.0, Vector2(640.0, 640.0))
	simulation.death_effect_duration = 0.05
	simulation.handoff_pause_duration_seconds = 0.1
	var left_fighter = simulation.fighter_for_side(simulation.teams[0].team_id)
	var right_fighter = simulation.fighter_for_side(simulation.teams[1].team_id)
	simulation.damage(left_fighter, left_fighter.hp, right_fighter.accent, right_fighter)
	simulation.damage(right_fighter, right_fighter.hp, left_fighter.accent, left_fighter)
	simulation.call("_check_finish")
	_check(not simulation.finished, "同帧双方阵亡但一方有候补时先等待候补接替，不把死球判为胜者")
	_check(simulation.active_fighters().is_empty(), "同帧阵亡的两个旧主球都从活跃集合精确退场")
	_check(simulation.entity_list(-1, "fighter_death_vfx").size() == 2, "只有确实同时阵亡时才生成两份死亡演出")
	var handoff_frames := 0
	while not simulation.snapshot()["pending_replacements"].is_empty() and handoff_frames < 20:
		simulation.step(BattleSimulation.FIXED_STEP)
		handoff_frames += 1
	_check(simulation.finished and simulation.winner_team_id == 1, "候补入场后再以仍有阵容的一方结束擂台赛")
	_check(simulation.winner() != null and simulation.winner().id == "wdc", "擂台胜者指向真实入场候补而不是已阵亡旧球")

func _check_simultaneous_total_elimination_is_draw() -> void:
	var setups := [
		BattleSetupScript.duel("test_ball", "test_ball"),
		BattleSetupScript.relay(["test_ball"], ["test_ball"]),
		BattleSetupScript.free_for_all([["test_ball"], ["test_ball"], ["test_ball"]]),
		BattleSetupScript.team_brawl(["test_ball", "test_ball"], ["test_ball", "test_ball"]),
	]
	for setup in setups:
		var simulation := BattleSimulationScript.new(20270842, setup, 60.0, Vector2(640.0, 640.0))
		for fighter in simulation.active_fighters():
			simulation.damage(fighter, fighter.hp, Color.WHITE, null)
		simulation.call("_check_finish")
		_check(simulation.finished and simulation.is_draw(), "%s 同帧全灭正式判为平局" % setup.mode)
		_check(simulation.winner_team_id == -1 and simulation.winner_id.is_empty() and simulation.winner_side.is_empty(), "%s 平局不伪造胜方身份" % setup.mode)
		_check(simulation.winner() == null and simulation.finish_reason == "同归于尽", "%s 平局保留明确结算原因" % setup.mode)
		_check(bool(simulation.snapshot().get("is_draw", false)), "%s 快照显式记录平局" % setup.mode)
		var finish_event: Dictionary = simulation.team_events[-1]
		_check(finish_event.get("result") == "draw" and int(finish_event.get("winner_team_id", 0)) == -1, "%s 结束事件显式记录平局且没有胜者" % setup.mode)

func _check_free_for_all_targeting_and_result() -> void:
	var setup = BattleSetupScript.free_for_all([["test_ball"], ["test_ball"], ["test_ball"]])
	var simulation := BattleSimulationScript.new(20270825, setup, 60.0, Vector2(640.0, 640.0))
	var source = simulation.fighters_for_team(0)[0]
	var first_enemy = simulation.fighters_for_team(1)[0]
	var second_enemy = simulation.fighters_for_team(2)[0]
	source.pos = Vector2(320.0, 320.0)
	first_enemy.pos = Vector2(220.0, 320.0)
	second_enemy.pos = Vector2(420.0, 320.0)
	_check(simulation.nearest_hostile_fighter(source) == first_enemy, "等距离敌人按稳定 fighter UID 决定目标")
	simulation.damage(source, source.hp, first_enemy.accent, first_enemy)
	simulation.call("_check_finish")
	_check(not simulation.finished and simulation.team_for_id(0).eliminated, "多方混战淘汰一方后其余阵营继续战斗")
	simulation.damage(first_enemy, first_enemy.hp, second_enemy.accent, second_enemy)
	simulation.call("_check_finish")
	_check(simulation.finished and simulation.winner_team_id == 2, "多方混战以最后存活阵营为胜者")

func _check_team_brawl_has_independent_fighters() -> void:
	var setup = BattleSetupScript.team_brawl(["test_ball", "test_ball"], ["test_ball", "test_ball"])
	var simulation := BattleSimulationScript.new(20270826, setup, 60.0, Vector2(720.0, 620.0))
	var allies := simulation.fighters_for_team(0)
	var enemies := simulation.fighters_for_team(1)
	_check(simulation.active_fighters().size() == 4, "双方大混战同时创建四个独立主球")
	var unique_uids := {}
	for fighter in simulation.active_fighters():
		unique_uids[fighter.fighter_uid] = true
	_check(unique_uids.size() == 4, "同队相同球种也拥有互不混淆的 fighter UID")
	allies[0].pos = Vector2(300.0, 300.0)
	allies[1].pos = Vector2(340.0, 300.0)
	allies[0].velocity = Vector2(180.0, 0.0)
	allies[1].velocity = Vector2(-180.0, 0.0)
	var ally_hp := allies[0].hp + allies[1].hp
	simulation.call("_resolve_fighter_pair", allies[0], allies[1])
	_check(is_equal_approx(allies[0].hp + allies[1].hp, ally_hp), "同队主球参与实体物理但不会互相造成能力伤害")
	for pair_index in range(2):
		allies[pair_index].pos = Vector2(260.0 + pair_index * 180.0, 340.0)
		enemies[pair_index].pos = allies[pair_index].pos + Vector2(40.0, 0.0)
		allies[pair_index].velocity = Vector2(180.0, 0.0)
		enemies[pair_index].velocity = Vector2(-180.0, 0.0)
		simulation.call("_resolve_fighter_pair", allies[pair_index], enemies[pair_index])
	_check(int(simulation.stats["contact_hits"]) == 2, "不同敌对主球对拥有互不阻塞的接触冷却")

func _check_train_conductor_instances_are_local() -> void:
	BallRegistry.configure_settings({
		"train_conductor": {
			"wall_contacts_per_departure": 2,
			"track_minimum_length": 10.0,
			"train_entry_delay": 0.0,
			"train_carriage_count": 1,
			"max_active_train_units": 2,
		},
	})
	var setup = BattleSetupScript.team_brawl(
		["train_conductor", "train_conductor"],
		["test_ball"]
	)
	var simulation := BattleSimulationScript.new(20270843, setup, 30.0, Vector2(640.0, 640.0))
	var conductors := simulation.fighters_for_team(0)
	var enemy = simulation.fighters_for_team(1)[0]
	var abilities: Array = []
	for conductor in conductors:
		abilities.append(simulation.call("_ability_for_fighter", conductor))

	var both_started := true
	for index in range(conductors.size()):
		var conductor = conductors[index]
		var previous_scope = simulation.call("_set_execution_fighter", conductor)
		both_started = both_started and bool(abilities[index].after_wall_hit(
			simulation.battle_context,
			conductor,
			enemy,
			conductor.team_id,
			Vector2(0.0, 180.0 + float(index) * 220.0)
		))
		simulation.call("_set_execution_fighter", previous_scope)
	_check(
		both_started
		and bool(abilities[0].call("is_recording_route"))
		and bool(abilities[1].call("is_recording_route")),
		"双方大混战中同队多个列车长会各自开始铺轨"
	)
	_check(
		_count_owned_entities(simulation, 0, "train_track", conductors[0].fighter_uid) == 1
		and _count_owned_entities(simulation, 0, "train_track", conductors[1].fighter_uid) == 1,
		"同队列车长的轨道按创建主球 UID 独立归属"
	)

	for index in range(conductors.size()):
		var conductor = conductors[index]
		var previous_scope = simulation.call("_set_execution_fighter", conductor)
		abilities[index].after_wall_hit(
			simulation.battle_context,
			conductor,
			enemy,
			conductor.team_id,
			Vector2(640.0, 180.0 + float(index) * 220.0)
		)
		abilities[index].on_step(
			simulation.battle_context,
			conductor,
			enemy,
			conductor.team_id,
			BattleSimulation.FIXED_STEP
		)
		simulation.call("_set_execution_fighter", previous_scope)
	_check(
		_count_owned_entities(simulation, 0, "train_convoy", conductors[0].fighter_uid) == 2
		and _count_owned_entities(simulation, 0, "train_convoy", conductors[1].fighter_uid) == 2,
		"每个列车长的车厢上限独立结算，不会删除同队列车长的车队"
	)
	BallRegistry.configure_settings({})

func _check_timeout_counts_queued_roster_hp() -> void:
	var setup = BattleSetupScript.relay(["test_ball", "test_ball"], ["test_ball"])
	var simulation := BattleSimulationScript.new(20270827, setup, 10.0, Vector2(640.0, 640.0))
	simulation.fighter_for_side(simulation.teams[0].team_id).hp = 10.0
	simulation.fighter_for_side(simulation.teams[1].team_id).hp = 50.0
	simulation.elapsed = simulation.max_battle_time
	simulation.call("_check_finish")
	_check(simulation.winner_team_id == 0, "时限判定把尚未登场候补的满生命计入整队剩余比例")

func _check_execution_scope_distinguishes_same_team_creators() -> void:
	var setup = BattleSetupScript.team_brawl(["test_ball", "test_ball"], ["test_ball", "test_ball"])
	var simulation := BattleSimulationScript.new(20270832, setup, 20.0, Vector2(700.0, 560.0))
	var allies := simulation.fighters_for_team(0)
	var previous_scope = simulation.call("_set_execution_fighter", allies[1])
	_check(simulation.battle_context.fighter_for_side(0) == allies[1], "同队能力执行作用域能取回真正的创建主球")
	var entity := OwnedFixtureEntity.new(0, allies[1].pos)
	simulation.battle_context.add_entity(entity)
	simulation.call("_set_execution_fighter", previous_scope)
	_check(entity.owner_fighter_uid == allies[1].fighter_uid, "同队第二主球生成的实体不会错误归到队伍首球")

func _check_multi_fighter_determinism() -> void:
	var setup = BattleSetupScript.team_brawl(["test_ball", "test_ball"], ["test_ball", "test_ball"])
	var first := BattleSimulationScript.new(20270828, setup, 20.0, Vector2(700.0, 560.0))
	var replay := BattleSimulationScript.new(20270828, setup, 20.0, Vector2(700.0, 560.0))
	for _frame in range(480):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
	_check(first.snapshot() == replay.snapshot(), "多主球同设置同种子可逐帧确定性重放")

func _check_real_ability_mode_smoke() -> void:
	var setups := [
		BattleSetupScript.relay(["vampire", "wind_swordsman"], ["wdc", "plant"]),
		BattleSetupScript.free_for_all([["black_hole"], ["plant"], ["sniper"], ["vampire"]]),
		BattleSetupScript.team_brawl(["wind_swordsman", "splitter", "sonic"], ["yuri", "replicator", "heavy_industry"]),
	]
	for setup in setups:
		var simulation := BattleSimulationScript.new(20270840 + setups.find(setup), setup, 30.0, Vector2(720.0, 640.0))
		for _frame in range(720):
			simulation.step(BattleSimulation.FIXED_STEP)
			if simulation.finished:
				break
		var seen_uids := {}
		var all_finite := true
		for fighter in simulation.active_fighters():
			seen_uids[fighter.fighter_uid] = true
			all_finite = all_finite and is_finite(fighter.pos.x) and is_finite(fighter.pos.y) and is_finite(fighter.hp)
		_check(all_finite, "%s 真实能力组合持续演算不产生非法位置或生命" % setup.mode)
		_check(seen_uids.size() == simulation.active_fighters().size(), "%s 真实能力组合保持主球 UID 唯一" % setup.mode)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _count_owned_entities(
	simulation,
	team_id: int,
	tag: String,
	owner_fighter_uid: int
) -> int:
	var count := 0
	for entity: BallEntity in simulation.entity_list(team_id, tag):
		if entity.owner_fighter_uid == owner_fighter_uid and not entity.removed:
			count += 1
	return count
