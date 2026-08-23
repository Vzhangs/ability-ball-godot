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

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_setup_contracts()
	_check_relay_replacement_is_local()
	_check_free_for_all_targeting_and_result()
	_check_team_brawl_has_independent_fighters()
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
	var duel = BattleSetupScript.duel("test_ball", "laser")
	var relay = BattleSetupScript.relay(["test_ball", "laser"], ["test_ball", "heaven"])
	var free_for_all = BattleSetupScript.free_for_all([["test_ball"], ["laser"], ["heaven"]])
	var team_brawl = BattleSetupScript.team_brawl(["test_ball", "laser"], ["heaven", "wdc"])
	_check(duel.is_valid() and duel.mode == BattleSetupScript.MODE_DUEL, "一对一预设生成合法统一设置")
	_check(relay.is_valid() and relay.teams[0]["active_count"] == 1, "擂台预设每方只启用一个阵容位")
	_check(free_for_all.is_valid() and free_for_all.teams.size() == 3, "多方混战预设支持三个阵营")
	_check(team_brawl.is_valid() and team_brawl.teams[0]["active_count"] == 2, "双方大混战让同队多个主球同时上场")
	var invalid = BattleSetupScript.new(BattleSetupScript.MODE_FREE_FOR_ALL, [
		BattleSetupScript.team(0, "A", ["test_ball"]),
		BattleSetupScript.team(1, "B", ["missing_ball"]),
	])
	_check(not invalid.is_valid(), "非法阵营数量和未注册球种会在开局前被拒绝")

func _check_relay_replacement_is_local() -> void:
	var setup = BattleSetupScript.relay(["test_ball", "laser"], ["test_ball", "heaven"])
	var simulation := BattleSimulationScript.new(20270824, setup, 60.0, Vector2(640.0, 640.0))
	var defeated = simulation.left
	var untouched = simulation.right
	var defeated_position := Vector2(214.0, 327.0)
	defeated.pos = defeated_position
	untouched.pos = Vector2(491.0, 288.0)
	untouched.velocity = Vector2(-123.0, 87.0)
	untouched.hp = 73.0
	untouched.ability_timer = 2.75
	var untouched_position: Vector2 = untouched.pos
	var untouched_velocity: Vector2 = untouched.velocity
	var owned_fixture := OwnedFixtureEntity.new(defeated.team_id, defeated.pos)
	var previous_scope = simulation.call("_set_execution_fighter", defeated)
	simulation.add_entity(owned_fixture)
	simulation.call("_set_execution_fighter", previous_scope)
	_check(owned_fixture.owner_fighter_uid == defeated.fighter_uid, "附属实体自动记录真实创建主球 UID")
	simulation.damage(defeated, defeated.hp, untouched.accent, untouched)
	simulation.call("_check_finish")
	_check(not simulation.finished, "擂台当前主球死亡但仍有候补时对局继续")
	_check(simulation.left.id == "laser" and simulation.left.fighter_uid != defeated.fighter_uid, "擂台按阵容顺序换入全新主球实例")
	_check(simulation.left.pos.is_equal_approx(defeated_position), "候补球在阵亡位置接替")
	_check(is_equal_approx(simulation.left.hp, simulation.left.max_hp), "候补球以自身完整生命和新状态上场")
	_check(simulation.right == untouched, "敌方主球对象没有被重建")
	_check(untouched.pos == untouched_position and untouched.velocity == untouched_velocity, "接替不会修改敌方位置和速度")
	_check(is_equal_approx(untouched.hp, 73.0) and is_equal_approx(untouched.ability_timer, 2.75), "接替不会修改敌方生命或技能计时")
	_check(not simulation.entities.has(owned_fixture), "阵亡主球仍归属自己的附属物会被局部清理")

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

func _check_timeout_counts_queued_roster_hp() -> void:
	var setup = BattleSetupScript.relay(["test_ball", "test_ball"], ["test_ball"])
	var simulation := BattleSimulationScript.new(20270827, setup, 10.0, Vector2(640.0, 640.0))
	simulation.left.hp = 10.0
	simulation.right.hp = 50.0
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
		BattleSetupScript.relay(["vampire", "laser"], ["wdc", "plant"]),
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
