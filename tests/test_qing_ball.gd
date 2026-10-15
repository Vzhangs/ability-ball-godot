extends SceneTree

const Stun := preload("res://scripts/balls/qing/paralysis_status.gd")
const Store := preload("res://scripts/settings/ball_settings_store.gd")
var failures: Array[String] = []

class StrongMotion extends BallStatusEffect:
	func _init() -> void:
		key = "test_strong_motion"
		remaining = 0.5
	func preserves_external_velocity() -> bool:
		return true
	func movement_control_priority() -> int:
		return 200
	func tick(battle, target, delta: float) -> void:
		target.velocity = Vector2(0, 77)
		super(battle, target, delta)

func _init() -> void:
	BallRegistry.configure_settings({})
	check(BallRegistry.get_module("qing").display_name == "晴球", "晴球自动注册")
	_test_deployment()
	_test_arc_and_control()
	_test_stun()
	_test_persistence()
	for opponent in ["garen", "sniper", "splitter"]:
		var first := BattleSimulation.new(9425, "qing", opponent, 30)
		var replay := BattleSimulation.new(9425, "qing", opponent, 30)
		for _frame in range(1801):
			first.step(BattleSimulation.FIXED_STEP)
			replay.step(BattleSimulation.FIXED_STEP)
		check(first.finished and first.snapshot() == replay.snapshot(), "晴球自然对战与确定性重放：" + opponent)
		check(int(first.stats.get("qing_deployments", 0)) > 0, "自然对战真实部署：" + opponent)
		print("QING_NATURAL ", opponent, " deployments=", first.stats.get("qing_deployments", 0), " arc_hits=", first.stats.get("qing_arc_hits", 0))
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_QING_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _deploy(sim, count: int) -> Array[BallEntity]:
	for _i in range(count): sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	return sim.entity_list(0, "qing_athena")

func _test_deployment() -> void:
	var sim := BattleSimulation.new(19, "qing", "test_ball")
	check(is_equal_approx(sim.fighter_for_side(sim.teams[0].team_id).ability_timer, 5.0), "首次部署等待完整周期")
	var nodes := _deploy(sim, 3)
	check(nodes.size() == 3 and nodes[0].get("hp") == 20.0, "原投稿部署数量与生命")
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	check(sim.count_entities(0, "qing_athena") == 3, "容量满时不超量部署")
	sim.damage_entity(nodes[0], 99.0, Color.WHITE, 1)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	check(sim.count_entities(0, "qing_athena") == 3, "失去召唤物后可补充")
	check(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).contact_damage(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id)) == 0.0, "本体没有隐藏撞伤")

func _test_arc_and_control() -> void:
	var sim := BattleSimulation.new(21, "qing", "test_ball")
	var nodes := _deploy(sim, 3)
	for i in range(3):
		nodes[i].pos = [Vector2(200, 300), Vector2(440, 300), Vector2(320, 480)][i]
		nodes[i].velocity = Vector2.ZERO
	sim._update_entities(0.01)
	var links := sim.entity_list(0, "qing_arc")
	check(links.size() == 3, "召唤物两两成网且不重复生成电弧")
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(320, 300)
	var hp: float = sim.fighter_for_side(sim.teams[1].team_id).hp
	links[0].step(sim.battle_context, 0.2)
	check(is_equal_approx(hp - sim.fighter_for_side(sim.teams[1].team_id).hp, 3.0), "真正触碰电弧扣除接触伤害")
	check(sim.has_status(sim.fighter_for_side(sim.teams[1].team_id), "qing_paralysis"), "命中施加瘫痪")
	links[0].step(sim.battle_context, 0.01)
	check(is_equal_approx(hp - sim.fighter_for_side(sim.teams[1].team_id).hp, 3.0), "持续接触遵守伤害间隔")
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(520, 520)
	links[0].step(sim.battle_context, 0.01)
	hp = sim.fighter_for_side(sim.teams[1].team_id).hp
	links[0].step(sim.battle_context, 1.0)
	check(is_equal_approx(hp, sim.fighter_for_side(sim.teams[1].team_id).hp), "离开电弧没有隐形伤害")
	check(nodes[0].transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id)), "雅典娜可被夺取")
	for link in links: link.step(sim.battle_context, 0.01)
	check(sim.entity_list(0, "qing_arc").size() == 1, "夺取一个端点会切断原阵营相邻电弧")
	check(nodes[1].transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id)), "多个端点可归新主人")
	sim._update_entities(0.01)
	check(sim.count_entities(1, "qing_arc") == 1, "归同一新主人的端点重建敌我正确的连线")
	check(nodes[1].disable_for_capture(), "雅典娜可捕获")
	for link in sim.entity_list(1, "qing_arc"): link.step(sim.battle_context, 0.01)
	check(sim.count_entities(1, "qing_arc") == 0, "捕获立即关闭电弧")
	check(nodes[1].absorb(sim.battle_context, 0, Vector2.ZERO), "被捕获端点可被吞噬")
	var rows: Array = sim.combat_ledger.rows_for(sim.fighter_for_side(sim.teams[0].team_id).fighter_uid)
	var reported := false
	for row in rows:
		if row["category_id"] == "qing_athena" and float(row["damage_dealt"]) >= 3.0:
			reported = true
	check(reported, "召唤物输出进入真实战报")

func _test_stun() -> void:
	var sim := BattleSimulation.new(22, "qing", "test_ball")
	sim.fighter_for_side(sim.teams[1].team_id).velocity = Vector2.LEFT * sim.fighter_for_side(sim.teams[1].team_id).base_speed
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), Stun.new(0.2, 0))
	sim._update_fighter(sim.fighter_for_side(sim.teams[1].team_id), sim.fighter_for_side(sim.teams[0].team_id), sim._ability_for_fighter(sim.fighter_for_side(sim.teams[1].team_id)), 1, 0.1)
	check(sim.fighter_for_side(sim.teams[1].team_id).velocity.length() < 0.1, "瘫痪期间停止自主移动")
	sim._update_fighter(sim.fighter_for_side(sim.teams[1].team_id), sim.fighter_for_side(sim.teams[0].team_id), sim._ability_for_fighter(sim.fighter_for_side(sim.teams[1].team_id)), 1, 0.11)
	check(is_equal_approx(sim.fighter_for_side(sim.teams[1].team_id).velocity.length(), sim.fighter_for_side(sim.teams[1].team_id).base_speed) and sim.fighter_for_side(sim.teams[1].team_id).velocity.x < 0.0, "瘫痪结束恢复原方向而不会锁死")
	var unit := BallEntity.new()
	unit.velocity = Vector2(100, 0)
	unit.status_effects.append(Stun.new(0.2, 0))
	unit.process_step(sim.battle_context, 0.1)
	check(unit.pos == Vector2.ZERO, "瘫痪同样冻结独立作战单位")
	unit.status_effects[0].tick(sim.battle_context, unit, 0.21)
	unit.process_step(sim.battle_context, 0.1)
	check(unit.pos.x > 0.0, "单位瘫痪到期正常继续行动")
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), Stun.new(0.2, 0))
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), StrongMotion.new())
	sim._update_fighter(sim.fighter_for_side(sim.teams[1].team_id), sim.fighter_for_side(sim.teams[0].team_id), sim._ability_for_fighter(sim.fighter_for_side(sim.teams[1].team_id)), 1, 0.1)
	sim._update_fighter(sim.fighter_for_side(sim.teams[1].team_id), sim.fighter_for_side(sim.teams[0].team_id), sim._ability_for_fighter(sim.fighter_for_side(sim.teams[1].team_id)), 1, 0.11)
	check(sim.fighter_for_side(sim.teams[1].team_id).velocity == Vector2(0, 77), "瘫痪及到期恢复均让位于更高优先级强制移动")

func _test_persistence() -> void:
	var path := "user://qing-gale-test-settings-%d.json" % OS.get_process_id()
	check(Store.save_settings({"qing": {"drone_hp": 37.0}, "gale": {"collision_growth": 0.12}}, path) == OK, "参数存档写入")
	BallRegistry.configure_settings(Store.load_settings(path))
	check(is_equal_approx(BallRegistry.get_module("qing").settingf("drone_hp"), 37.0), "晴球参数经过磁盘重载")
	check(is_equal_approx(BallRegistry.get_module("gale").settingf("collision_growth"), 0.12), "两球独立参数不会串改")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	BallRegistry.configure_settings({})

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
