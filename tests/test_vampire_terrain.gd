extends SceneTree

const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
var failures: Array[String] = []

class Unit extends BallEntity:
	var hp := 30.0
	var terrain := false
	func is_terrain() -> bool:
		return terrain
	func can_receive_attack(side: int) -> bool:
		return not removed and not is_captured() and is_hostile_to(side)
	func receive_attack(_battle, amount: float, _side: int, _color: Color) -> float:
		var applied := minf(hp, amount)
		hp -= applied
		return applied
	func fighter_collision_inverse_mass() -> float:
		return 0.0

func _init() -> void:
	_check_real_block_collision()
	_check_generic_terrain_and_living_unit()
	_check_remote_drain()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_VAMPIRE_TERRAIN_OK")
		quit(0)
	else:
		for failure in failures: push_error("TEST FAILED: " + failure)
		quit(1)

func _simulation() -> BattleSimulation:
	BallRegistry.configure_settings({"vampire": {"cooldown": 60.0}, "steve": {
		"wood_spawn_weight": 0, "stone_spawn_weight": 0, "iron_spawn_weight": 0,
		"gold_spawn_weight": 0, "diamond_spawn_weight": 0, "netherite_spawn_weight": 1,
	}})
	return Simulation.new(20260918, "vampire", "steve")

func _place(sim: BattleSimulation) -> BallEntity:
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(320, 320)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[1].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[1].team_id), sim.fighter_for_side(sim.teams[0].team_id), 1)
	var block: BallEntity = sim.entity_list(1, "steve_block")[0]
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(500, 500)
	return block

func _check_real_block_collision() -> void:
	var sim := _simulation()
	var block := _place(sim)
	_check(block.is_terrain(), "资源方块明确声明自己是地形")
	var origin := block.pos
	sim.fighter_for_side(sim.teams[0].team_id).hp = 50.0
	sim.fighter_for_side(sim.teams[0].team_id).pos = origin - Vector2(sim.fighter_for_side(sim.teams[0].team_id).radius + block.radius - 1.0, 0)
	sim.fighter_for_side(sim.teams[0].team_id).velocity = Vector2(150, 0)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).before_motion(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.016)
	sim._resolve_fighter_entity_collision(sim.fighter_for_side(sim.teams[0].team_id), sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)), 0, block)
	block.process_step(sim.battle_context, 0.016)
	_check(sim.fighter_for_side(sim.teams[0].team_id).velocity.x < 0.0, "吸血鬼撞地形后正常反弹，不恢复为吸附前进速度")
	_check(not sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).is_latching_entity(), "方块不会启动吸附")
	_check(not sim.has_status(sim.fighter_for_side(sim.teams[0].team_id), "vampire_latch"), "碰地形不获得吸附无敌")
	_check(float(block.get("hp")) == 5.0, "普通碰撞只消耗正常方块耐久")
	for frame in range(180):
		sim.fighter_for_side(sim.teams[0].team_id).pos += sim.fighter_for_side(sim.teams[0].team_id).velocity / 60.0
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).before_motion(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 1.0 / 60.0)
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 1.0 / 60.0)
	_check(block.pos == origin and block.velocity == Vector2.ZERO, "持续更新不会拖动地形")
	_check(float(block.get("hp")) == 5.0 and sim.fighter_for_side(sim.teams[0].team_id).hp == 50.0, "没有持续吸血、回血或额外耐久损失")
	_check(int(sim.stats.get("vampire_entity_latch_drains", 0)) == 0 and sim.count_entities(0, "vampire_latch_tether") == 0, "不产生地形吸血记录与牵引血线")
	_check(block.can_receive_attack(0) and block.is_absorbable() and block.can_transfer_ownership(), "地形标识不改变其它攻击和所有权契约")

func _check_generic_terrain_and_living_unit() -> void:
	var sim := _simulation()
	sim.fighter_for_side(sim.teams[0].team_id).hp = 50.0
	var target := Unit.new()
	target.owner_side = 1
	target.radius = 12.0
	target.pos = Vector2(320, 300)
	target.terrain = true
	sim.add_entity(target)
	var origin := target.pos
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).after_entity_contact(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), target, 0.0)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id))._maintain_entity_latch(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), target)
	var applied: float = sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id))._perform_entity_latch_drain(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), target, 0)
	_check(not sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).is_latching_entity() and applied == 0.0 and target.pos == origin and target.hp == 30.0, "任意地形都被排除，不依赖方块 ID 或类型")
	target.terrain = false
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).after_entity_contact(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), target, 0.0)
	_check(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).is_latching_entity(), "零逆质量的非地形单位仍可被吸附")
	sim.fighter_for_side(sim.teams[0].team_id).pos += Vector2(30, 10)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).before_motion(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.7)
	_check(target.pos != origin and target.hp < 30.0 and sim.fighter_for_side(sim.teams[0].team_id).hp > 50.0, "非地形单位仍正常拖拽、吸血并治疗")
	target.terrain = true
	origin = target.pos
	var hp_before := target.hp
	sim.fighter_for_side(sim.teams[0].team_id).pos += Vector2(30, 10)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).before_motion(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.7)
	_check(not sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).is_latching_entity() and target.pos == origin and target.hp == hp_before, "持续吸附每帧重新检查地形资格并清理状态")

func _check_remote_drain() -> void:
	var sim := _simulation()
	var block := _place(sim)
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(200, 320)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(450, 320)
	sim.fighter_for_side(sim.teams[0].team_id).hp = 50.0
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	var blood: BallEntity = sim.entity_list(0, "vampire_remote_drain")[0]
	blood.process_step(sim.battle_context, 1.0)
	_check(float(block.get("hp")) == 6.0 and block.pos == Vector2(320, 320), "远程吸血不会抽取途经的地形耐久")
	_check(sim.fighter_for_side(sim.teams[1].team_id).hp == 96.0 and sim.fighter_for_side(sim.teams[0].team_id).hp == 54.0, "远程技能仍正常吸取敌方主球生命")

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
