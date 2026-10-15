extends SceneTree

const Lane := preload("res://scripts/balls/gale/wind_lane_entity.gd")
const Blade := preload("res://scripts/balls/gale/wind_blade_entity.gd")
const Wind := preload("res://scripts/balls/gale/wind_status.gd")
var failures: Array[String] = []

class Target extends BallEntity:
	var hp := 100.0
	func can_receive_attack(side: int) -> bool:
		return is_hostile_to(side) and not removed
	func receive_attack(_battle, amount: float, _side: int, _color: Color) -> float:
		var applied := minf(hp, amount)
		hp -= applied
		return applied
	func participates_in_fighter_collision() -> bool:
		return true

func _init() -> void:
	BallRegistry.configure_settings({})
	check(BallRegistry.get_module("gale").display_name == "疾风球", "疾风自动注册")
	_test_lanes()
	_test_growth_and_wall()
	_test_blade()
	for opponent in ["garen", "sniper", "splitter"]:
		var first := BattleSimulation.new(391, "gale", opponent, 30)
		var replay := BattleSimulation.new(391, "gale", opponent, 30)
		for _frame in range(1801):
			first.step(BattleSimulation.FIXED_STEP)
			replay.step(BattleSimulation.FIXED_STEP)
		check(first.finished and first.snapshot() == replay.snapshot(), "疾风自然对战与确定性重放：" + opponent)
		check(int(first.stats.get("gale_blades_fired", 0)) > 0, "自然撞墙发射风刃：" + opponent)
		check(first.count_entities(0, "gale_lane") <= 96, "风道数量有界")
		print("GALE_NATURAL ", opponent, " fired=", first.stats.get("gale_blades_fired", 0), " hits=", first.stats.get("gale_blade_hits", 0))
	if failures.is_empty():
		print("ABILITY_BALL_GALE_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _test_lanes() -> void:
	var sim := BattleSimulation.new(25, "gale", "test_ball")
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(300, 300)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(340, 300)
	var config: Dictionary = sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("_lane_config")
	var lanes: Array[BallEntity] = []
	for _index in range(3):
		var lane := Lane.new(0, Vector2(250, 300), Vector2(390, 300), config)
		lane.owner_fighter_uid = sim.fighter_for_side(sim.teams[0].team_id).fighter_uid
		sim.add_entity(lane)
		lanes.append(lane)
	var ally := Target.new()
	ally.owner_side = 0
	ally.pos = Vector2(300, 300)
	ally.radius = 12
	sim.add_entity(ally)
	var enemy := Target.new()
	enemy.owner_side = 1
	enemy.pos = Vector2(330, 300)
	enemy.radius = 12
	sim.add_entity(enemy)
	for lane in lanes: lane.step(sim.battle_context, 0.01)
	check(sim.has_status(sim.fighter_for_side(sim.teams[0].team_id), "gale_tailwind") and sim.has_status(sim.fighter_for_side(sim.teams[1].team_id), "gale_headwind"), "风道正确区别双方主球")
	check(sim.fighter_for_side(sim.teams[0].team_id).status_effects.size() == 1 and sim.fighter_for_side(sim.teams[1].team_id).status_effects.size() == 1, "重叠风道只刷新而不堆叠")
	check(is_equal_approx(ally.status_step_multiplier(), 1.3) and is_equal_approx(enemy.status_step_multiplier(), 0.65), "友方与敌方附属单位也能受到风道影响")
	for target in [sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), ally, enemy]:
		sim._update_status_effects(target, 0.2)
	check(sim.fighter_for_side(sim.teams[0].team_id).status_effects.is_empty() and ally.status_step_multiplier() == 1.0, "余效到期完全清理")
	lanes[0].disable_for_capture()
	lanes[1].step(sim.battle_context, 0.01)
	check(sim.has_status(sim.fighter_for_side(sim.teams[0].team_id), "gale_tailwind"), "首段被吞噬后其余风道仍能接续")
	for lane in lanes: lane.removed = true
	sim._update_status_effects(sim.fighter_for_side(sim.teams[0].team_id), 0.2)
	check(not sim.has_status(sim.fighter_for_side(sim.teams[0].team_id), "gale_tailwind"), "风道清除后没有持续隐形加速")

func _test_growth_and_wall() -> void:
	var sim := BattleSimulation.new(26, "gale", "test_ball")
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).after_contact(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).after_contact(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	check(is_equal_approx(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).speed_multiplier(null, null, null, 0), 1.08), "持续接触不会刷满增速")
	for _index in range(60):
		sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(26, 320)
		sim.fighter_for_side(sim.teams[0].team_id).velocity = Vector2(-300, 0)
		sim._resolve_wall(sim.fighter_for_side(sim.teams[0].team_id))
	check(is_equal_approx(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).speed_multiplier(null, null, null, 0), 3.0), "碰撞增速存在上限")
	var blades := sim.entity_list(0, "gale_blade")
	check(blades.size() == 60 and blades[0].velocity.x > 0, "风刃沿真实反弹方向发射")
	check(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).contact_damage(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id)) == 0.0, "疾风没有额外普通撞伤")

func _test_blade() -> void:
	var sim := BattleSimulation.new(27, "gale", "test_ball")
	var config := {}
	var module: BallModule = BallRegistry.get_module("gale")
	for key in ["blade_speed", "blade_radius", "blade_duration", "blade_base_damage", "speed_difference_damage", "blade_damage_cap"]:
		config[key] = module.setting(key)
	var blade := Blade.new(0, Vector2(100, 300), Vector2.RIGHT, 400.0, config)
	blade.owner_fighter_uid = sim.fighter_for_side(sim.teams[0].team_id).fighter_uid
	check(is_equal_approx(blade.damage_for_speed(100), 14.0) and is_equal_approx(blade.damage_for_speed(400), 2.0), "风刃按命中目标真实速度差计算伤害")
	check(blade.damage_for_speed(2000) <= 32.0, "极端速度差仍受伤害上限约束")
	var blocker := Target.new()
	blocker.owner_side = 1
	blocker.pos = Vector2(200, 300)
	blocker.velocity = Vector2(100, 0)
	blocker.radius = 12
	sim.add_entity(blocker)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(350, 300)
	var hp: float = sim.fighter_for_side(sim.teams[1].team_id).hp
	blade.step(sim.battle_context, 0.5)
	check(blade.removed and is_equal_approx(blocker.hp, 86.0) and sim.fighter_for_side(sim.teams[1].team_id).hp == hp, "高速扫掠只击中首个挡路实体")
	check(blade.disable_for_capture() == false, "已命中风刃不可再捕获")
	var fresh := Blade.new(0, Vector2(100, 300), Vector2.RIGHT, 400.0, config)
	check(fresh.disable_for_capture() and not fresh.can_transfer_ownership(), "风刃可捕获吞噬但不能被心控")
	fresh.process_step(sim.battle_context, 0.5)
	check(fresh.pos == Vector2(100, 300), "捕获状态不会继续造成扫掠命中")
	fresh.absorb(sim.battle_context, 1, Vector2.ZERO)
	check(fresh.removed, "风刃吞噬完成")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
