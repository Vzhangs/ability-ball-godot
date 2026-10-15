extends SceneTree

const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
const Setup := preload("res://scripts/simulation/battle_setup.gd")
const Block := preload("res://scripts/balls/steve/block_entity.gd")
const Art := preload("res://scripts/balls/steve/material_art.gd")
const Store := preload("res://scripts/settings/ball_settings_store.gd")
var failures: Array[String] = []

class Unit extends BallEntity:
	var hp := 30.0
	func can_receive_attack(side: int) -> bool:
		return not removed and is_hostile_to(side)
	func receive_attack(_battle, amount: float, _side: int, _color: Color) -> float:
		var applied := minf(hp, amount)
		hp -= applied
		return applied
	func participates_in_entity_collision() -> bool:
		return not removed
	func can_resolve_entity_contact(other: BallEntity) -> bool:
		return is_hostile_to(other.owner_side)

func _init() -> void:
	_check_schema_and_persistence()
	_check_random_and_cap()
	_check_weighted_materials()
	_check_pickup_protection()
	_check_placement_no_displacement()
	_check_collect_once_and_equipment_order()
	_check_enemy_contacts()
	_check_same_team_contact_identity()
	_check_attacks_capture_and_transfer()
	_check_sword_and_armor()
	_check_same_team_owner_isolation()
	_check_determinism_and_rectangles()
	_check_audio_events()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_STEVE_TESTS_OK")
		quit(0)
	else:
		for failure in failures: push_error("TEST FAILED: " + failure)
		quit(1)

func _sim(settings: Dictionary = {}) -> BattleSimulation:
	BallRegistry.configure_settings({"steve": settings})
	return Simulation.new(20260916, "steve", "test_ball")

func _block(sim: BattleSimulation, tier: int, center := Vector2(300, 300)) -> BallEntity:
	var module: BallModule = sim.module_for_fighter(sim.fighter_for_side(sim.teams[0].team_id))
	var block: BallEntity = Block.new(sim.fighter_for_side(sim.teams[0].team_id), center, tier, sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)), {
		"radius": module.settingf("block_radius"), "max_hp": module.settingf(String(Art.IDS[tier]) + "_block_durability"),
		"collision_wear": module.settingf("block_collision_wear"), "release_margin": module.settingf("contact_release_margin"),
		"growth_duration": module.settingf("block_growth_duration"),
		"pickup_delay": module.settingf("block_pickup_delay"),
	})
	sim.add_entity(block)
	return block

func _take(sim: BattleSimulation, block: BallEntity) -> void:
	sim.fighter_for_side(sim.teams[0].team_id).pos = block.pos + Vector2(0, sim.fighter_for_side(sim.teams[0].team_id).radius + block.radius + 10.0)
	block.process_step(sim.battle_context, sim.module_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).settingf("block_pickup_delay") + 0.01)
	sim.fighter_for_side(sim.teams[0].team_id).pos = block.pos
	block.process_step(sim.battle_context, 1.0 / 60.0)

func _check_schema_and_persistence() -> void:
	var sim := _sim()
	_check(BallRegistry.validation_errors().is_empty(), "注册表和观众简介校验通过")
	_check(sim.module_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).display_name == "史蒂夫球" and sim.fighter_for_side(sim.teams[0].team_id).max_hp == 100.0, "史蒂夫球自动发现且默认生命为 100")
	for tier in range(6):
		_check(sim.module_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).settingf(String(Art.IDS[tier]) + "_block_durability") == float(tier + 1), "六种方块默认耐久依次为 1 至 6")
	var path := "user://test_steve_persistence.json"
	_check(Store.save_settings({"steve": {"max_hp": 180.0, "cooldown": 1.5, "wood_block_durability": 21.0, "diamond_sword_damage": 31.0, "netherite_armor_reduction": 60.0, "wood_spawn_weight": 12.0, "block_pickup_delay": 2.5}}, path) == OK, "参数可以保存")
	BallRegistry.configure_settings(Store.load_settings(path))
	var reloaded := Simulation.new(11, "steve", "plant")
	_check(reloaded.fighter_for_side(reloaded.teams[0].team_id).max_hp == 180.0 and reloaded.fighter_for_side(reloaded.teams[0].team_id).cooldown == 1.5, "基础属性保存重载后保持")
	_check(reloaded.module_for_fighter(reloaded.fighter_for_side(reloaded.teams[0].team_id)).settingf("wood_block_durability") == 21.0 and reloaded.module_for_fighter(reloaded.fighter_for_side(reloaded.teams[0].team_id)).settingf("diamond_sword_damage") == 31.0 and reloaded.module_for_fighter(reloaded.fighter_for_side(reloaded.teams[0].team_id)).settingf("netherite_armor_reduction") == 60.0, "各材质参数独立持久化")
	_check(reloaded.fighter_for_side(reloaded.teams[1].team_id).max_hp == 100.0, "史蒂夫参数不覆盖对方")
	_check(reloaded.module_for_fighter(reloaded.fighter_for_side(reloaded.teams[0].team_id)).settingf("wood_spawn_weight") == 12.0 and reloaded.module_for_fighter(reloaded.fighter_for_side(reloaded.teams[0].team_id)).settingf("block_pickup_delay") == 2.5, "材质权重与拾取保护独立持久化")
	DirAccess.remove_absolute(path)

func _check_random_and_cap() -> void:
	var sim := _sim()
	for index in range(8):
		sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(110 + (index % 4) * 110, 110 + (index / 4) * 110)
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
		var blocks := sim.entity_list(0, "steve_block")
		_check(blocks.size() == index + 1, "每次成功放置新增方块")
		if blocks.size() != index + 1: continue
		var tier := int(blocks.back().call("material_tier"))
		_check(tier >= 0 and tier < 6, "放置产生合法随机材质")
		_check(float(blocks.back().get("hp")) == float(tier + 1), "新方块使用抽中材质的耐久")
	var capped := _sim({"maximum_blocks": 1})
	capped.fighter_for_side(capped.teams[0].team_id).pos = Vector2(200, 200)
	capped._ability_for_fighter(capped.fighter_for_side(capped.teams[0].team_id)).activate(capped.battle_context, capped.fighter_for_side(capped.teams[0].team_id), capped.fighter_for_side(capped.teams[1].team_id), 0)
	_check(not capped._ability_for_fighter(capped.fighter_for_side(capped.teams[0].team_id)).automatic_activation_enabled(), "容量上限按本体独立限制放置")
	_take(capped, capped.entity_list(0, "steve_block")[0])
	_check(capped._ability_for_fighter(capped.fighter_for_side(capped.teams[0].team_id)).automatic_activation_enabled(), "取装消耗方块后释放容量")

func _check_weighted_materials() -> void:
	var first := _sim()
	var second := _sim()
	var counts := [0, 0, 0, 0, 0, 0]
	for draw in range(10000):
		var tier := int(first._ability_for_fighter(first.fighter_for_side(first.teams[0].team_id)).call("roll_material_tier", first.battle_context))
		counts[tier] += 1
		_check(tier == int(second._ability_for_fighter(second.fighter_for_side(second.teams[0].team_id)).call("roll_material_tier", second.battle_context)), "材质抽样可按种子重放")
	for tier in range(5):
		_check(counts[tier] > counts[tier + 1], "默认高级材质出现频率更低")
	for selected in range(6):
		var overrides := {}
		for tier in range(6):
			overrides[String(Art.IDS[tier]) + "_spawn_weight"] = 1.0 if tier == selected else 0.0
		var forced := _sim(overrides)
		for draw in range(20):
			_check(int(forced._ability_for_fighter(forced.fighter_for_side(forced.teams[0].team_id)).call("roll_material_tier", forced.battle_context)) == selected, "零权重材质不会出现")
	var disabled := {}
	for material_id: String in Art.IDS:
		disabled[material_id + "_spawn_weight"] = 0.0
	var fallback := _sim(disabled)
	_check(int(fallback._ability_for_fighter(fallback.fighter_for_side(fallback.teams[0].team_id)).call("roll_material_tier", fallback.battle_context)) == 0, "权重全零时稳定回退木头")

func _check_pickup_protection() -> void:
	var sim := _sim({"first_sword_probability": 1.0, "block_pickup_delay": 1.0})
	var block := _block(sim, 3)
	sim.fighter_for_side(sim.teams[0].team_id).pos = block.pos + Vector2(100, 0)
	block.process_step(sim.battle_context, 0.1)
	sim.fighter_for_side(sim.teams[0].team_id).pos = block.pos
	block.process_step(sim.battle_context, 0.1)
	_check(not block.removed, "保护期内快速离开折返仍不能拾取")
	block.process_step(sim.battle_context, 1.0)
	_check(not block.removed, "保护到期时停留在块上也不会自动吃掉")
	sim.fighter_for_side(sim.teams[0].team_id).pos = block.pos + Vector2(100, 0)
	block.process_step(sim.battle_context, 0.01)
	sim.fighter_for_side(sim.teams[0].team_id).pos = block.pos
	block.process_step(sim.battle_context, 0.01)
	_check(block.removed, "保护结束后完全离开再进入才取装")

func _check_placement_no_displacement() -> void:
	var sim := _sim()
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(sim.fighter_for_side(sim.teams[0].team_id).radius, 300)
	var rng_before := sim.rng.state
	_check(not sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).automatic_activation_enabled(), "靠墙空间不足时等待而不把方块挪到前方")
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	_check(sim.count_entities(0, "steve_block") == 0 and sim.rng.state == rng_before, "放置失败既不产生前置方块也不消耗抽样随机数")
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(160, 300)
	_check(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).automatic_activation_enabled(), "走到安全位置后恢复放置")
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
	var block: BallEntity = sim.entity_list(0, "steve_block")[0]
	_check(block.pos == sim.fighter_for_side(sim.teams[0].team_id).pos, "真正生成在脚下，不向前修正落点")
	block.process_step(sim.battle_context, 0.01)
	_check(not block.removed, "生成帧不会吃掉方块")

func _check_collect_once_and_equipment_order() -> void:
	var sim := _sim({"first_sword_probability": 1.0})
	var first := _block(sim, 5)
	sim.fighter_for_side(sim.teams[0].team_id).pos = first.pos
	first.process_step(sim.battle_context, 0.1)
	_check(not first.removed and int(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("sword_tier")) == -1, "出生重叠不会自动取装")
	_take(sim, first)
	_check(first.removed and int(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("sword_tier")) == 5, "触碰直接获得下界合金剑并消耗满耐久方块")
	_check(float(first.get("hp")) == 6.0, "取装不以打空耐久为前提")
	first.process_step(sim.battle_context, 0.1)
	_check(int(sim.stats.get("steve_blocks_collected", 0)) == 1, "已消耗方块不能重复发放装备")
	var second := _block(sim, 2)
	_take(sim, second)
	_check(int(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("armor_tier")) == 2, "已有剑时获得盔甲")
	var lower := _block(sim, 0)
	_take(sim, lower)
	_check(lower.removed and int(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("sword_tier")) == 5, "低级剑不降级但仍消耗方块")
	_take(sim, _block(sim, 4))
	_check(int(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("armor_tier")) == 4, "两件都有后交替尝试升级")
	var armor_first := _sim({"first_sword_probability": 0.0})
	_take(armor_first, _block(armor_first, 1))
	_take(armor_first, _block(armor_first, 3))
	_check(int(armor_first._ability_for_fighter(armor_first.fighter_for_side(armor_first.teams[0].team_id)).call("armor_tier")) == 1 and int(armor_first._ability_for_fighter(armor_first.fighter_for_side(armor_first.teams[0].team_id)).call("sword_tier")) == 3, "首次可以得到盔甲，下一次补剑")

func _hit_block(sim: BattleSimulation, fighter, block: BallEntity, direction := Vector2.RIGHT) -> void:
	fighter.pos = block.pos - direction * (fighter.radius + block.radius - 1.0)
	fighter.velocity = direction * 100.0
	sim._resolve_fighter_entity_collision(fighter, sim.ability_for_fighter(fighter), fighter.team_id, block)

func _check_enemy_contacts() -> void:
	var sim := _sim()
	var block := _block(sim, 5)
	var hp_before: float = sim.fighter_for_side(sim.teams[1].team_id).hp
	_hit_block(sim, sim.fighter_for_side(sim.teams[1].team_id), block)
	_check(sim.fighter_for_side(sim.teams[1].team_id).velocity.x < 0.0, "敌球碰方块会反弹")
	block.process_step(sim.battle_context, 0.01)
	_check(float(block.get("hp")) == 5.0 and sim.fighter_for_side(sim.teams[1].team_id).hp == hp_before, "普通敌球碰撞损耗耐久但方块不伤敌人")
	_check(float(sim.combat_ledger.totals_for(sim.fighter_for_side(sim.teams[1].team_id).fighter_uid).damage_dealt) == 1.0 and float(sim.combat_ledger.totals_for(sim.fighter_for_side(sim.teams[0].team_id).fighter_uid).damage_taken) == 1.0, "方块磨损归实际撞击者与方块主人，而非无来源损耗")
	for repeat in range(4):
		_hit_block(sim, sim.fighter_for_side(sim.teams[1].team_id), block)
		block.process_step(sim.battle_context, 0.01)
	_check(float(block.get("hp")) == 5.0, "持续压在方块上不会重复扣耐久")
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(500, 500)
	block.process_step(sim.battle_context, 0.01)
	_hit_block(sim, sim.fighter_for_side(sim.teams[1].team_id), block)
	block.process_step(sim.battle_context, 0.01)
	_check(float(block.get("hp")) == 4.0, "完全离开再碰撞会再次损耗")
	var wood := _block(sim, 0, Vector2(400, 400))
	_hit_block(sim, sim.fighter_for_side(sim.teams[1].team_id), wood)
	wood.process_step(sim.battle_context, 0.01)
	_check(wood.removed, "木头可被一次普通碰撞摧毁")

func _check_same_team_contact_identity() -> void:
	BallRegistry.configure_settings({})
	var sim := Simulation.new(71, Setup.team_brawl(["steve"], ["test_ball", "test_ball"]))
	var block := _block(sim, 5)
	var enemies := sim.fighters_for_team(1)
	_hit_block(sim, enemies[0], block)
	_hit_block(sim, enemies[1], block, Vector2.LEFT)
	block.process_step(sim.battle_context, 0.01)
	_check(float(block.get("hp")) == 4.0, "同阵营多个敌球的接触按 UID 分别结算")
	for enemy in enemies:
		_check(float(sim.combat_ledger.totals_for(enemy.fighter_uid).damage_dealt) == 1.0, "同队多个撞击者分别记录自己的方块伤害")

func _check_attacks_capture_and_transfer() -> void:
	var sim := _sim()
	var block := _block(sim, 5)
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(100, 100)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(550, 550)
	sim.add_projectile(1, Vector2(220, 300), Vector2(400, 0), 2.0, 2.0, Color.WHITE, 2.0, "plain")
	sim._update_entities(0.2)
	_check(float(block.get("hp")) == 4.0 and sim.entity_list(1, "projectile").is_empty(), "非穿透子弹损耗方块并消失")
	var attachment := Unit.new()
	attachment.owner_side = 1
	attachment.radius = 8.0
	attachment.pos = block.pos - Vector2(20, 0)
	attachment.velocity = Vector2(100, 0)
	sim.add_entity(attachment)
	block.process_step(sim.battle_context, 0.01)
	block.process_step(sim.battle_context, 0.01)
	_check(attachment.velocity.x < 0.0 and float(block.get("hp")) == 3.0, "敌方附属物也会反弹并损耗方块")
	_check(block.disable_for_capture(), "方块可被黑洞捕获")
	var before: float = block.get("hp")
	block.process_step(sim.battle_context, 1.0)
	_check(not block.can_receive_attack(1) and not block.participates_in_fighter_collision() and float(block.get("hp")) == before, "捕获后停用取装、碰撞和受击")
	_check(block.absorb(sim.battle_context, 1, Vector2.ZERO) and block.removed, "捕获后的方块可以吞噬")
	var controlled := _block(sim, 3)
	_check(controlled.transfer_ownership(1, sim.fighter_for_side(sim.teams[1].team_id)), "方块能通过通用契约被永久控制")
	_take(sim, controlled)
	_check(not controlled.removed and int(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("sword_tier")) == -1, "控制后的方块不再给原主人装备")

func _check_sword_and_armor() -> void:
	var sim := _sim({"first_sword_probability": 1.0, "wood_sword_damage": 7.0})
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("collect_equipment", sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), 0)
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(200, 200)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(270, 200)
	var hp_before: float = sim.fighter_for_side(sim.teams[1].team_id).hp
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	_check(hp_before - sim.fighter_for_side(sim.teams[1].team_id).hp == 7.0, "剑首次触碰伤害按配置结算，持续重叠不连扣")
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(450, 200)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(270, 200)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	_check(hp_before - sim.fighter_for_side(sim.teams[1].team_id).hp == 14.0, "脱离剑后可再次命中")
	var entity := Unit.new()
	entity.owner_side = 1
	entity.radius = 8.0
	entity.pos = Vector2(250, 200)
	sim.add_entity(entity)
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
	_check(entity.hp == 23.0, "剑也能命中附属物")
	_check(sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).contact_damage(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id)) == 0.0, "本体普通碰撞不额外叠加剑伤害")
	var icons_before := sim.count_entities(0, "steve_cast_vfx")
	var rings_before := sim.impact_rings.size()
	sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("collect_equipment", sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), 5)
	_check(sim.count_entities(0, "steve_cast_vfx") == icons_before, "取盔甲不再生成覆盖头部的居中盔甲图案")
	_check(sim.impact_rings.size() == rings_before, "取盔甲不再叠加覆盖头部的升级光环")
	var applied := sim.damage(sim.fighter_for_side(sim.teams[0].team_id), 20.0, Color.WHITE, sim.fighter_for_side(sim.teams[1].team_id))
	_check(is_equal_approx(applied, 10.4), "下界合金盔甲按材质减伤")
	_check(is_equal_approx(float(sim.stats.damage_to_left), 10.4), "护甲吸收部分不计入承伤")

func _check_same_team_owner_isolation() -> void:
	BallRegistry.configure_settings({"steve": {"first_sword_probability": 1.0}})
	var sim := Simulation.new(72, Setup.team_brawl(["steve", "steve"], ["test_ball"]))
	var owners := sim.fighters_for_team(0)
	var block := _block(sim, 2)
	owners[0].pos = Vector2(100, 100)
	block.process_step(sim.battle_context, 1.01)
	owners[1].pos = block.pos
	block.process_step(sim.battle_context, 0.01)
	_check(not block.removed and int(sim.ability_for_fighter(owners[1]).call("sword_tier")) == -1, "同队同名球不会偷领他人的装备")
	owners[0].pos = block.pos
	block.process_step(sim.battle_context, 0.01)
	_check(block.removed and int(sim.ability_for_fighter(owners[0]).call("sword_tier")) == 2, "方块准确绑定创建者")

func _check_determinism_and_rectangles() -> void:
	BallRegistry.configure_settings({})
	var first := Simulation.new(73, "steve", "test_ball", 120.0, Vector2(440, 740))
	var second := Simulation.new(73, "steve", "test_ball", 120.0, Vector2(440, 740))
	for frame in range(2400):
		first.step(1.0 / 60.0)
		second.step(1.0 / 60.0)
	_check(first.snapshot() == second.snapshot(), "同种子长竞技场演算确定性一致")
	_check(first._ability_for_fighter(first.fighter_for_side(first.teams[0].team_id)).call("sword_tier") == second._ability_for_fighter(second.fighter_for_side(second.teams[0].team_id)).call("sword_tier") and first._ability_for_fighter(first.fighter_for_side(first.teams[0].team_id)).call("armor_tier") == second._ability_for_fighter(second.fighter_for_side(second.teams[0].team_id)).call("armor_tier"), "装备随机结果也可重现")
	for block: BallEntity in first.entity_list(-1, "steve_block"):
		_check(block.pos.x >= block.radius and block.pos.x <= 440.0 - block.radius and block.pos.y >= block.radius and block.pos.y <= 740.0 - block.radius, "方块不越过长方形场地边界")

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _check_audio_events() -> void:
	var catalog = load("res://scripts/balls/steve/audio_catalog.gd")
	for tier in range(6):
		var settings := {"first_sword_probability": 1.0}
		for index in range(6):
			settings[String(Art.IDS[index]) + "_spawn_weight"] = 1.0 if tier == index else 0.0
		var sim := _sim(settings)
		sim.take_combat_events()
		sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(200, 200)
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
		_expect_sound(sim, catalog.block_event("place", tier), "成功放置只播放对应材质声")
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).activate(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0)
		_check(sim.take_combat_events().is_empty(), "重叠落点放置失败不发声")
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("collect_equipment", sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), tier)
		_expect_sound(sim, "steve_upgrade", "剑升级播放经验球提示")
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("collect_equipment", sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), tier)
		_expect_sound(sim, catalog.armor_event(tier), "盔甲使用对应材质穿戴声")
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).call("collect_equipment", sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), tier)
		_expect_sound(sim, "steve_pickup", "未升级拾取不能播放升级声")
		sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(270, 200)
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
		_expect_sound(sim, "steve_sword_light" if tier < 2 else "steve_sword_heavy", "有效剑击使用原版攻击声")
		sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).on_step(sim.battle_context, sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), 0, 0.01)
		_check(sim.take_combat_events().is_empty(), "持续贴剑不重复发声")
		var block := _block(sim, tier, Vector2(400, 400))
		block.set("hp", 10.0)
		block.receive_attack(sim.battle_context, 1.0, 1, Color.WHITE)
		_expect_sound(sim, catalog.block_event("hit", tier), "未碎方块播放材质敲击声")
		block.receive_attack(sim.battle_context, 1.0, 1, Color.WHITE)
		_check(sim.take_combat_events().is_empty(), "密集受击音有限流")
		block.receive_attack(sim.battle_context, 20.0, 1, Color.WHITE)
		_expect_sound(sim, catalog.block_event("break", tier), "破碎声不受敲击限流影响")
		block.receive_attack(sim.battle_context, 20.0, 1, Color.WHITE)
		_check(sim.take_combat_events().is_empty(), "已破碎方块不重复发声")
		_check(sim.module_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).sound_kind.is_empty(), "自动激活不叠加通用声音")
		for event: String in sim.module_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).audio_samples():
			var spec: Dictionary = sim.module_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)).audio_samples()[event]
			_check(spec.stream is AudioStream and spec.stream.get_length() > 0.0 and spec.stream.get_length() < 2.0, "全部原版短采样可加载")
			_check(not bool(spec.get("loop", false)), "所有史蒂夫事件均为一次性短音")

func _expect_sound(sim: BattleSimulation, kind: String, message: String) -> void:
	var events := sim.take_combat_events()
	_check(events.size() == 1 and String(events[0].kind) == kind, message)
