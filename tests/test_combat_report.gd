extends SceneTree

const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
const Setup := preload("res://scripts/simulation/battle_setup.gd")
const Plant := preload("res://scripts/balls/plant/growth_entity.gd")
const Burn := preload("res://scripts/balls/core/burn_status_effect.gd")
const Shield := preload("res://scripts/balls/core/invulnerability_status_effect.gd")
const View := preload("res://scripts/ui/battle_view.gd")
const CjkFont := preload("res://scripts/ui/cjk_font_provider.gd")

var failures: Array[String] = []

class Unit extends BallEntity:
	var hp := 50.0
	var shoot := false
	func combat_category() -> Dictionary:
		return {"id": "test_unit", "name": "测试单位"}
	func is_absorbable() -> bool:
		return true
	func can_receive_attack(side: int) -> bool:
		return not removed and not is_captured() and side != owner_side
	func receive_attack(_battle, amount: float, _side: int, _color: Color) -> float:
		var applied := minf(hp, amount)
		hp -= applied
		removed = hp <= 0.0
		return applied
	func step(battle, _delta: float) -> void:
		if shoot:
			shoot = false
			battle.add_projectile(owner_side, pos, Vector2.RIGHT * 400.0, 2.0, 8.0, Color.WHITE, 5.0, "plain")

class WallDamage extends BallStatusEffect:
	func on_wall_hit(battle, target) -> void:
		battle.damage(target, 3.0, Color.WHITE, battle.fighter_for_side(source_side))

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	_check_actual_amounts()
	_check_transfer_and_in_flight_provenance()
	_check_wall_status_provenance()
	_check_real_plant_categories_and_burn()
	_check_controlled_cannon_projectiles()
	_check_roster_history_and_reset()
	_check_determinism()
	await _check_result_scroll_and_lifecycle()
	await _check_real_brawl_paused_result_layout()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_COMBAT_REPORT_TESTS_OK")
		quit(0)
	else:
		for failure in failures: push_error("TEST FAILED: " + failure)
		quit(1)

func _check_actual_amounts() -> void:
	var sim := Simulation.new(901, "test_ball", "test_ball")
	sim.fighter_for_side(sim.teams[1].team_id).hp = 12.0
	var shield = Shield.new(1.0, 1, "test_shield")
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), shield)
	sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 50.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id))
	_eq(_total(sim, sim.fighter_for_side(sim.teams[0].team_id), "damage_dealt"), 0.0, "无敌挡掉的伤害不入账")
	sim.fighter_for_side(sim.teams[1].team_id).status_effects.clear()
	sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 5.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id))
	sim.heal(sim.fighter_for_side(sim.teams[1].team_id), 2000.0)
	_eq(_total(sim, sim.fighter_for_side(sim.teams[1].team_id), "healing"), 993.0, "回复只统计实际恢复量，不统计溢出")
	sim.fighter_for_side(sim.teams[1].team_id).hp = 7.0
	sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 100.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id))
	_eq(_total(sim, sim.fighter_for_side(sim.teams[0].team_id), "damage_dealt"), 12.0, "过量伤害按目标实际损血计数")
	_eq(_total(sim, sim.fighter_for_side(sim.teams[1].team_id), "damage_taken"), 12.0, "承伤与实际扣血一致")
	sim.damage(sim.fighter_for_side(sim.teams[0].team_id), 3.0, Color.WHITE, null)
	_eq(_total(sim, sim.fighter_for_side(sim.teams[0].team_id), "damage_dealt"), 12.0, "无来源自损不会算成输出")
	_eq(_total(sim, sim.fighter_for_side(sim.teams[0].team_id), "damage_taken"), 3.0, "无来源损血仍计承伤")
	sim.heal(sim.fighter_for_side(sim.teams[0].team_id), 5.0, true)
	_eq(_total(sim, sim.fighter_for_side(sim.teams[0].team_id), "healing"), 5.0, "允许超上限的回血按真实增加量记录")

func _check_transfer_and_in_flight_provenance() -> void:
	var sim := Simulation.new(902, "test_ball", "yuri")
	var unit := Unit.new()
	unit.owner_side = 0
	unit.owner_fighter_uid = sim.fighter_for_side(sim.teams[0].team_id).fighter_uid
	unit.pos = Vector2(280.0, 320.0)
	sim.add_entity(unit)
	sim.damage_entity(unit, 4.0, Color.WHITE, 1, false, sim.fighter_for_side(sim.teams[1].team_id))
	sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 6.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id), false, unit)
	unit.shoot = true
	sim._update_entities(0.01)
	var old_projectile: BallEntity = sim.entity_list(0, "projectile")[0]
	_check(unit.transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id)), "测试单位实际永久转移归属")
	sim.damage_entity(unit, 3.0, Color.WHITE, 0, false, sim.fighter_for_side(sim.teams[0].team_id))
	sim.damage(sim.fighter_for_side(sim.teams[0].team_id), 7.0, Color.WHITE, sim.fighter_for_side(sim.teams[1].team_id), false, unit)
	_eq(_category(sim, sim.fighter_for_side(sim.teams[0].team_id), "test_unit", "damage_taken"), 4.0, "控制前承伤留在原主球")
	_eq(_category(sim, sim.fighter_for_side(sim.teams[1].team_id), "test_unit", "damage_taken"), 3.0, "控制后承伤归新主人")
	_eq(_category(sim, sim.fighter_for_side(sim.teams[0].team_id), "test_unit", "damage_dealt"), 6.0, "控制不会搬走历史输出")
	_eq(_category(sim, sim.fighter_for_side(sim.teams[1].team_id), "test_unit", "damage_dealt"), 7.0, "控制后的单位输出归新主人")
	old_projectile.pos = sim.fighter_for_side(sim.teams[1].team_id).pos
	sim._update_entities(0.01)
	_eq(_category(sim, sim.fighter_for_side(sim.teams[0].team_id), "test_unit", "damage_dealt"), 14.0, "控制前已发出的子弹保留原来源")
	unit.shoot = true
	sim._update_entities(0.01)
	var new_projectile: BallEntity = sim.entity_list(1, "projectile")[0]
	new_projectile.pos = sim.fighter_for_side(sim.teams[0].team_id).pos
	sim._update_entities(0.01)
	_eq(_category(sim, sim.fighter_for_side(sim.teams[1].team_id), "test_unit", "damage_dealt"), 15.0, "控制后发出的子弹归新主人同类单位")
	unit.removed = true
	sim._remove_finished_entities()
	_eq(_category(sim, sim.fighter_for_side(sim.teams[0].team_id), "test_unit", "damage_dealt"), 14.0, "附属物销毁后仍保留历史")
	var controller_row: Dictionary = sim.combat_report()["fighters"][1]["rows"][1]
	_check(controller_row["controlled"] and String(controller_row["origin_name"]).contains("测试球"), "受控分类保留原主球来源")

func _check_wall_status_provenance() -> void:
	var sim := Simulation.new(910, "test_ball", "yuri")
	var unit := Unit.new()
	unit.owner_side = 0
	unit.owner_fighter_uid = sim.fighter_for_side(sim.teams[0].team_id).fighter_uid
	sim.add_entity(unit)
	var effect := WallDamage.new()
	effect.key = "wall_test"
	effect.remaining = 5.0
	effect.source_side = 0
	effect.source_fighter_uid = sim.fighter_for_side(sim.teams[0].team_id).fighter_uid
	effect.combat_source = unit.combat_identity()
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), effect)
	unit.transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id))
	sim._notify_status_wall_hit(sim.fighter_for_side(sim.teams[1].team_id))
	_eq(_category(sim, sim.fighter_for_side(sim.teams[0].team_id), "test_unit", "damage_dealt"), 3.0, "撞墙状态伤害也保留施加时的附属物来源")
	_eq(_category(sim, sim.fighter_for_side(sim.teams[1].team_id), "test_unit", "damage_dealt"), 0.0, "控制后不会挪走已施加的撞墙状态伤害")

func _check_real_plant_categories_and_burn() -> void:
	var sim := Simulation.new(903, "plant", "yuri")
	var plants: Array[BallEntity] = []
	for form in [Plant.GrowthForm.SUNFLOWER, Plant.GrowthForm.PEA_FIRE, Plant.GrowthForm.PEA_ICE, Plant.GrowthForm.PEA_GATLING]:
		var plant := Plant.new(0, Vector2(280.0, 320.0), sim.fighter_for_side(sim.teams[0].team_id).color, sim.fighter_for_side(sim.teams[0].team_id).accent, BallRegistry.get_module("plant").settings_snapshot())
		plant.owner_fighter_uid = sim.fighter_for_side(sim.teams[0].team_id).fighter_uid
		plant._form = form
		plant._mature_body()
		plant._action_timer = 999.0
		sim.add_entity(plant)
		plants.append(plant)
		_eq(_category(sim, sim.fighter_for_side(sim.teams[0].team_id), String(plant.combat_category()["id"]), "damage_taken"), 0.0, "各成熟植物有独立统计行")
		plant.pos += Vector2(0.0, float(plants.size()) * 45.0)
	var fire = plants[1]
	fire._action_timer = 0.0
	sim._update_entities(0.01)
	var shot: BallEntity = sim.entity_list(0, "projectile")[0]
	_check(String(shot.combat_source["category_id"]) == "plant_pea_fire", "真实火豌豆子弹继承射手分类")
	shot.pos = sim.fighter_for_side(sim.teams[1].team_id).pos
	sim._update_entities(0.01)
	var before := _category(sim, sim.fighter_for_side(sim.teams[0].team_id), "plant_pea_fire", "damage_dealt")
	_check(before > 0.0, "真实火豌豆直击计入火豌豆行")
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[1].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[1].team_id), sim.fighter_for_side(sim.teams[0].team_id), 1)
	if fire.owner_side != 1:
		_check(fire.transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id)), "火豌豆转到控制方")
	fire.removed = true
	sim._update_status_effects(sim.fighter_for_side(sim.teams[1].team_id), 1.01)
	_check(_category(sim, sim.fighter_for_side(sim.teams[0].team_id), "plant_pea_fire", "damage_dealt") > before, "已施加灼烧不随射手控制或死亡转移归属")
	_eq(_category(sim, sim.fighter_for_side(sim.teams[1].team_id), "plant_pea_fire", "damage_dealt"), 0.0, "旧灼烧不能冒领到控制方")
	# A controlled sunflower's healing credit and the recipient's recovery are separate.
	var sunflower = plants[0]
	if sunflower.owner_side != 1: sunflower.transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id))
	sunflower._action_timer = 0.0
	sim._update_entities(0.01)
	var suns: Array[BallEntity] = sim.entity_list(1, "plant_sun_pickup")
	_check(not suns.is_empty(), "受控向日葵产生真实阳光")
	if not suns.is_empty():
		var sun = suns[0]
		sun._landed = true
		sun.pos = sim.fighter_for_side(sim.teams[1].team_id).pos
		sim.fighter_for_side(sim.teams[1].team_id).hp = 50.0
		sim._update_entities(0.01)
		_check(_category(sim, sim.fighter_for_side(sim.teams[1].team_id), "plant_sunflower", "healing_done") > 0.0, "阳光治疗贡献归受控向日葵")
		_check(_total(sim, sim.fighter_for_side(sim.teams[1].team_id), "healing") > 0.0, "拾取者实际回复独立入账")

func _check_controlled_cannon_projectiles() -> void:
	var sim := Simulation.new(904, "replicator", "yuri")
	var previous = sim._set_execution_fighter(sim.fighter_for_side(sim.teams[0].team_id))
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	sim._set_execution_fighter(previous)
	var cannon: BallEntity = sim.entity_list(0, "clone")[0]
	cannon.transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id))
	for projectile: BallEntity in sim.entity_list(-1, "projectile"): projectile.removed = true
	previous = sim._set_execution_fighter(sim.fighter_for_side(sim.teams[0].team_id))
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	sim._set_execution_fighter(previous)
	var controlled_shots := sim.entity_list(1, "projectile")
	_check(not controlled_shots.is_empty(), "被控制的浮游炮仍发射子弹")
	if not controlled_shots.is_empty():
		var shot: BallEntity = controlled_shots[0]
		_check(int(shot.combat_source["fighter_uid"]) == sim.fighter_for_side(sim.teams[1].team_id).fighter_uid, "原能力统一齐射时不能把受控炮弹算回原主人")
		_check(String(shot.combat_source["category_id"]) == "replicator_cannon", "炮弹归浮游炮分类而非尤里本体")

func _check_roster_history_and_reset() -> void:
	var setup = Setup.relay(["test_ball", "test_ball", "test_ball"], ["test_ball"])
	var sim := Simulation.new(905, setup)
	var dead_uid := sim.fighter_for_side(sim.teams[0].team_id).fighter_uid
	sim.damage(sim.fighter_for_side(sim.teams[0].team_id), 2000.0, Color.WHITE, sim.fighter_for_side(sim.teams[1].team_id))
	sim.step(Simulation.FIXED_STEP)
	for _frame in range(130): sim.step(Simulation.FIXED_STEP)
	var report: Dictionary = sim.combat_report()
	_check(report["fighters"].size() == 4, "结算包含已败、当前和未出场的完整阵容")
	_check(report["fighters"][0]["state"] == "落败" and int(report["fighters"][0]["fighter_uid"]) == dead_uid, "换人后保留已败球的独立记录")
	_check(report["fighters"][2]["state"] == "未上场", "候补不伪造成参战球")
	_eq(float(report["fighters"][0]["totals"]["damage_taken"]), 1000.0, "落败球承伤不会记到同名接替者")
	sim.reset(905, "test_ball", "test_ball")
	_eq(_total(sim, sim.fighter_for_side(sim.teams[0].team_id), "damage_taken"), 0.0, "重开清空上一局账本")

func _check_determinism() -> void:
	var first := Simulation.new(906, "plant", "splitter")
	var replay := Simulation.new(906, "plant", "splitter")
	for _frame in range(420):
		first.step(Simulation.FIXED_STEP)
		replay.step(Simulation.FIXED_STEP)
	_check(first.snapshot() == replay.snapshot(), "战报无进程对象 ID，随相同种子确定性重放")

func _check_result_scroll_and_lifecycle() -> void:
	var view := View.new()
	view.size = Vector2(650.0, 700.0)
	var ui_theme := Theme.new()
	ui_theme.default_font = CjkFont.font()
	view.theme = ui_theme
	root.add_child(view)
	var roster := []
	for _index in range(16): roster.append("test_ball")
	view.start_battle_setup(907, Setup.team_brawl(roster, roster), 2.0, Vector2(440.0, 440.0))
	view.paused = true
	view.simulation.finished = true
	view.simulation.winner_team_id = -1
	view._result_reveal_elapsed = 999.0
	view._sync_result_panel()
	for _frame in range(8): await process_frame
	var panel = view.result_panel
	_check(panel != null and panel.report["fighters"].size() == 32, "多人结算逐球列出全部参战者")
	_check(panel.automatic_scroll, "普通对局的战报也默认自动滚动")
	_check(panel.scroll_distance() > 0.0 and panel.scroll.get_v_scroll_bar().visible, "首次创建长战报就有可用滚动条")
	panel.scroll.scroll_vertical = int(panel.scroll_distance())
	await process_frame
	_check(panel.scroll.scroll_vertical > 0, "第一次打开即可滚动到末尾")
	_check(panel.position.y + panel.size.y <= view.size.y + 0.1, "结算不会超出战斗视图底部")
	panel.automatic_scroll = true
	panel._process(panel.presentation_duration())
	_check(absf(float(panel.scroll.scroll_vertical) - panel.scroll_distance()) < 2.0, "录制自动滚动完整战报到最后一行")
	panel._process(3.0)
	_check(panel.presentation_finished(), "真正滚到末尾并停留后才允许结束录制")
	view.start_battle(908, "test_ball", "test_ball")
	_check(view.result_panel == null, "重新开局移除旧战报")
	view.queue_free()
	await process_frame

func _check_real_brawl_paused_result_layout() -> void:
	var view := View.new()
	view.size = Vector2(650.0, 701.0)
	view.process_mode = Node.PROCESS_MODE_DISABLED
	var ui_theme := Theme.new()
	ui_theme.default_font = CjkFont.font()
	view.theme = ui_theme
	root.add_child(view)
	view.start_battle_setup(911, Setup.team_brawl(["plant", "replicator"], ["yuri", "splitter"]), 40.0, Vector2(440.0, 440.0))
	for _frame in range(2500):
		view.simulation.step(Simulation.FIXED_STEP)
		if view.simulation.finished: break
	var damage := 0.0
	var taken := 0.0
	var own_loss := 0.0
	for participant: Dictionary in view.simulation.combat_report()["fighters"]:
		for row: Dictionary in participant["rows"]:
			damage += float(row["damage_dealt"])
			taken += float(row["damage_taken"])
			own_loss += float(row["self_damage"]) + float(row["unattributed_damage"])
	_eq(damage, taken - own_loss, "真实混战双方输出与承伤扣除自损后守恒")
	view._result_reveal_elapsed = 999.0
	view._sync_result_panel()
	for _frame in range(12): await process_frame
	var panel = view.result_panel
	_check(panel.scroll_distance() > 0.0, "附属物明细需要真实滚动区域")
	_check(panel.position.y + panel.size.y <= view.size.y + 0.1, "游戏暂停时首次打开多行附属物战报也不溢出")
	panel.scroll.scroll_vertical = int(panel.scroll_distance())
	await process_frame
	_check(panel.scroll.scroll_vertical > 0, "暂停时首次打开即可查看战报末尾")
	view.size.y = 1100.0
	view._sync_result_panel()
	for _frame in range(8): await process_frame
	_check(panel.position.y + panel.size.y <= view.size.y + 0.1, "长竞技场结算跟随视图高度")
	view.size.y = 600.0
	view._sync_result_panel()
	for _frame in range(8): await process_frame
	_check(panel.position.y + panel.size.y <= view.size.y + 0.1, "视图缩短后结算恢复滚动且不超界")
	panel.set_process(false)
	panel._age = 0.0
	panel._bottom_hold = 0.0
	panel.scroll.scroll_vertical = 0
	panel._process(panel.LEAD_HOLD + 1.0)
	_check(panel.scroll.scroll_vertical > 0 and not panel.presentation_finished(), "尚未到底时不能结束录制")
	for _tick in range(int(ceilf(panel.presentation_duration() * 60.0)) + 1):
		panel._process(1.0 / 60.0)
	_check(panel.presentation_finished() and absf(float(panel.scroll.scroll_vertical) - panel.scroll_distance()) < 2.0, "按实际帧推进完成自动滚动和最后一行停留")
	view.queue_free()
	await process_frame

func _total(sim, fighter, metric: String) -> float:
	return float(sim.combat_ledger.totals_for(fighter.fighter_uid)[metric])

func _category(sim, fighter, category: String, metric: String) -> float:
	var total := 0.0
	for row: Dictionary in sim.combat_ledger.rows_for(fighter.fighter_uid):
		if row["category_id"] == category: total += float(row[metric])
	return total

func _eq(actual: float, expected: float, label: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (实际 %s，预期 %s)" % [label, actual, expected])

func _check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)
