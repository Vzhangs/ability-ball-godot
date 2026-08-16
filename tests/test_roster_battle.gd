extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const ReplicatorAbility := preload("res://scripts/balls/replicator/ability.gd")
const ReplicatorCannonEntity := preload("res://scripts/balls/replicator/clone_entity.gd")
const SplitterAbility := preload("res://scripts/balls/splitter/ability.gd")
const SplitterCloneEntity := preload("res://scripts/balls/splitter/clone_entity.gd")

var failures: Array[String] = []

class TestAbsorbableEntity extends BallEntity:
	func _init(spawn_owner: int, spawn_position: Vector2, spawn_radius: float, tag: String) -> void:
		owner_side = spawn_owner
		pos = spawn_position
		radius = spawn_radius
		tags = PackedStringArray([tag])

	func is_absorbable() -> bool:
		return true

func _init() -> void:
	BallRegistry.reload()
	_check(BallRegistry.is_valid(), "球模块注册表通过完整性校验")
	var ids := BallRegistry.ids()
	_check(ids.size() >= 10, "球库保留首批 10 个球")
	var unique := {}
	for ball_id in ids:
		unique[ball_id] = true
		var module: BallModule = BallRegistry.get_module(ball_id)
		_check(module.id == ball_id, "%s 的目录 ID 一致" % ball_id)
		_check(not module.display_name.is_empty(), "%s 有显示名称" % ball_id)
		_check(module.max_hp > 0.0, "%s 有有效生命值" % ball_id)
		_check(module.cooldown > 0.0, "%s 有有效能力冷却" % ball_id)
		_check(module.create_ability() is BallAbility, "%s 提供独立能力实现" % ball_id)
		_check(module.create_visual() is BallVisual, "%s 提供独立视觉实现" % ball_id)
	_check(unique.size() == ids.size(), "球 ID 不重复")
	_check(not BallRegistry.has_id("not-a-ball"), "未知球 ID 被注册表拒绝")
	_check_inertial_motion()
	_check_contact_damage_contract()
	_check_replicator_dual_ring_formation()
	_check_splitter_clone_bodies()
	_check_splitter_attack_reception()
	_check_black_hole_orbit_force()
	_check_black_hole_wall_damage()
	_check_black_hole_projectile_capture()
	_check_black_hole_absorption()
	_check_time_limit_configuration()
	_check_visual_rng_isolation()

	var deterministic_a := BattleSimulationScript.new(20260815, "splitter", "black_hole")
	var deterministic_b := BattleSimulationScript.new(20260815, "splitter", "black_hole")
	_run_to_finish(deterministic_a, true)
	_run_to_finish(deterministic_b, false)
	_check(deterministic_a.snapshot() == deterministic_b.snapshot(), "相同球种和种子可完全重放")

	var ability_totals := {}
	var wins := {}
	var total_elapsed := 0.0
	var minimum_elapsed := 999.0
	var maximum_elapsed := 0.0
	var timeout_count := 0
	for ball_id in ids:
		ability_totals[ball_id] = 0
		wins[ball_id] = 0
	var matchup_count := 0
	for left_index in range(ids.size()):
		for right_index in range(left_index + 1, ids.size()):
			var simulation := BattleSimulationScript.new(20260815 + matchup_count, ids[left_index], ids[right_index])
			_run_to_finish(simulation, true)
			matchup_count += 1
			total_elapsed += simulation.elapsed
			minimum_elapsed = minf(minimum_elapsed, simulation.elapsed)
			maximum_elapsed = maxf(maximum_elapsed, simulation.elapsed)
			if simulation.finish_reason == "时限判定":
				timeout_count += 1
			_check(simulation.finished, "%s VS %s 能在时限内结束" % [simulation.left.display_name, simulation.right.display_name])
			_check(not simulation.winner_side.is_empty(), "%s VS %s 产生胜者" % [simulation.left.display_name, simulation.right.display_name])
			_check(float(simulation.stats["damage_to_left"]) + float(simulation.stats["damage_to_right"]) > 0.0, "%s VS %s 产生真实伤害" % [simulation.left.display_name, simulation.right.display_name])
			var abilities: Dictionary = simulation.stats["abilities"]
			ability_totals[simulation.left.id] = int(ability_totals[simulation.left.id]) + int(abilities[simulation.left.id])
			ability_totals[simulation.right.id] = int(ability_totals[simulation.right.id]) + int(abilities[simulation.right.id])
			wins[simulation.winner_id] = int(wins[simulation.winner_id]) + 1

	var expected_matchups := ids.size() * (ids.size() - 1) / 2
	_check(matchup_count == expected_matchups, "%d 个球的 %d 种异种组合全部覆盖" % [ids.size(), expected_matchups])
	_check(minimum_elapsed >= 12.0, "最快对局也保留首轮能力展开时间")
	_check(total_elapsed / matchup_count >= 30.0, "平均对局时长适合短视频叙事")
	for ball_id in ids:
		var module: BallModule = BallRegistry.get_module(ball_id)
		_check(int(ability_totals[ball_id]) > 0, "%s 的专属能力至少触发一次" % module.display_name)

	var zero_seed := BattleSimulationScript.new(0, "splitter", "black_hole")
	_check(zero_seed.seed_value == 20260815, "零种子回退到默认种子")

	print("ABILITY_BALL_ROSTER_TEST_SUMMARY ", JSON.stringify({
		"balls": ids.size(),
		"matchups": matchup_count,
		"minimum_elapsed": minimum_elapsed,
		"average_elapsed": total_elapsed / matchup_count,
		"maximum_elapsed": maximum_elapsed,
		"timeouts": timeout_count,
		"ability_totals": ability_totals,
		"wins": wins,
	}))
	if failures.is_empty():
		print("ABILITY_BALL_ROSTER_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_ROSTER_TESTS_FAILED count=", failures.size())
		quit(1)

func _run_to_finish(simulation: BattleSimulation, check_bounds: bool) -> void:
	var max_frames := int(ceil(simulation.max_battle_time / BattleSimulation.FIXED_STEP)) + 4
	for frame in range(max_frames):
		simulation.step(BattleSimulation.FIXED_STEP)
		if check_bounds and frame % 300 == 0:
			_check(_inside_arena(simulation.left), "%s 始终留在竞技场" % simulation.left.display_name)
			_check(_inside_arena(simulation.right), "%s 始终留在竞技场" % simulation.right.display_name)
		if simulation.finished:
			break

func _inside_arena(fighter: BattleSimulation.FighterState) -> bool:
	return (
		fighter.pos.x >= fighter.radius - 0.01
		and fighter.pos.x <= BattleSimulation.ARENA_SIZE.x - fighter.radius + 0.01
		and fighter.pos.y >= fighter.radius - 0.01
		and fighter.pos.y <= BattleSimulation.ARENA_SIZE.y - fighter.radius + 0.01
	)

func _check_inertial_motion() -> void:
	var simulation := BattleSimulationScript.new(20260821, "splitter", "heaven")
	simulation.left.pos = Vector2(180.0, 180.0)
	simulation.right.pos = Vector2(500.0, 470.0)
	simulation.left.velocity = Vector2(150.0, 70.0)
	var initial_direction := simulation.left.velocity.normalized()
	simulation.step(BattleSimulation.FIXED_STEP)
	var direction_alignment := initial_direction.dot(simulation.left.velocity.normalized())
	_check(direction_alignment > 0.9999, "普通球保持初速度方向，不再自动追踪对手")

func _check_contact_damage_contract() -> void:
	var default_ability := BallAbility.new()
	_check(is_zero_approx(default_ability.contact_damage(null, null, null)), "基础能力的球体碰撞默认无伤害")

	var neutral_contact := BattleSimulationScript.new(20260828, "laser", "black_hole")
	_prepare_contact(neutral_contact)
	var neutral_left_hp := neutral_contact.left.hp
	var neutral_right_hp := neutral_contact.right.hp
	neutral_contact._resolve_collision()
	_check(is_equal_approx(neutral_contact.left.hp, neutral_left_hp), "无碰撞能力的左球相撞不掉血")
	_check(is_equal_approx(neutral_contact.right.hp, neutral_right_hp), "无碰撞能力的右球相撞不掉血")
	_check(int(neutral_contact.stats["contact_hits"]) == 1, "无伤害碰撞仍保留物理碰撞统计")

	var damaging_contact := BattleSimulationScript.new(20260829, "vampire", "laser")
	_prepare_contact(damaging_contact)
	var vampire_hp := damaging_contact.left.hp
	var laser_hp := damaging_contact.right.hp
	damaging_contact._resolve_collision()
	_check(is_equal_approx(damaging_contact.left.hp, vampire_hp), "没有碰撞能力的一侧不会反向造成伤害")
	_check(damaging_contact.right.hp < laser_hp, "吸血鬼通过自身碰撞能力显式造成伤害")

func _prepare_contact(simulation: BattleSimulation) -> void:
	var minimum_distance := simulation.left.radius + simulation.right.radius
	simulation.left.pos = Vector2(280.0, 320.0)
	simulation.right.pos = Vector2(280.0 + minimum_distance - 1.0, 320.0)
	simulation.left.velocity = Vector2(160.0, 0.0)
	simulation.right.velocity = Vector2(-160.0, 0.0)

func _check_replicator_dual_ring_formation() -> void:
	_check(ReplicatorAbility.MAX_CANNONS == 22, "浮游炮总上限固定为 22 门")
	_check(ReplicatorCannonEntity.INNER_RING_CAPACITY == 8, "浮游炮内圈容量固定为 8 门")
	_check(ReplicatorCannonEntity.OUTER_RING_CAPACITY == 14, "浮游炮外圈容量固定为 14 门")
	var simulation := BattleSimulationScript.new(20260906, "replicator", "laser")
	simulation.left.pos = Vector2(320.0, 320.0)
	simulation.right.pos = Vector2(580.0, 320.0)
	for _activation in range(ReplicatorAbility.MAX_CANNONS):
		simulation.left_ability.activate(
			simulation.battle_context,
			simulation.left,
			simulation.right,
			0
		)
	var cannons: Array[BallEntity] = simulation.entity_list(0, "clone")
	_check(cannons.size() == 22, "连续部署后恰好形成 22 门浮游炮")
	if cannons.size() != 22:
		return
	var inner_ring: Array[BallEntity] = []
	var outer_ring: Array[BallEntity] = []
	for cannon: BallEntity in cannons:
		if int(cannon.call("formation_ring")) == 0:
			inner_ring.append(cannon)
		else:
			outer_ring.append(cannon)
	_check(inner_ring.size() == 8, "前 8 门浮游炮均匀进入第一层内圈")
	_check(outer_ring.size() == 14, "其余 14 门浮游炮均匀进入第二层外圈")
	_check_circular_ring(
		inner_ring,
		simulation.left.pos,
		ReplicatorCannonEntity.INNER_ORBIT_RADIUS,
		"内圈"
	)
	_check_circular_ring(
		outer_ring,
		simulation.left.pos,
		ReplicatorCannonEntity.OUTER_ORBIT_RADIUS,
		"外圈"
	)
	var first_offset: Vector2 = cannons[0].pos - simulation.left.pos
	simulation.left.pos += Vector2(45.0, -30.0)
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	_check(cannons[0].pos - simulation.left.pos == first_offset, "双环编队会整体跟随浮游炮本体移动")
	var projectile_count_before := simulation.count_entities(0, "projectile")
	simulation.left_ability.activate(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0
	)
	_check(simulation.count_entities(0, "clone") == 22, "达到上限后不会部署第 23 门浮游炮")
	var projectiles: Array[BallEntity] = simulation.entity_list(0, "projectile")
	var new_projectile_count := projectiles.size() - projectile_count_before
	_check(new_projectile_count == 23, "满编时由本体与 22 门浮游炮共同齐射 23 发")
	if new_projectile_count == 23:
		var first_new_projectile := projectiles[projectile_count_before]
		_check(first_new_projectile.pos == simulation.left.pos, "满编齐射保留本体发射点")
		for index in range(cannons.size()):
			_check(
				projectiles[projectile_count_before + index + 1].pos == cannons[index].pos,
				"第 %d 门浮游炮从自身真实环绕位置开火" % (index + 1)
			)

func _check_circular_ring(
	entities: Array[BallEntity],
	center: Vector2,
	expected_radius: float,
	label: String
) -> void:
	if entities.is_empty():
		return
	var angles: Array[float] = []
	for entity: BallEntity in entities:
		var offset := entity.pos - center
		_check(is_equal_approx(offset.length(), expected_radius), "%s浮游炮位于固定圆形半径" % label)
		angles.append(offset.angle())
	angles.sort()
	var expected_gap := TAU / float(angles.size())
	for index in range(angles.size()):
		var next_angle := angles[(index + 1) % angles.size()]
		if index == angles.size() - 1:
			next_angle += TAU
		_check(is_equal_approx(next_angle - angles[index], expected_gap), "%s浮游炮按等角间距环绕" % label)

func _check_splitter_clone_bodies() -> void:
	_check(SplitterAbility.MAX_CLONES == 100, "分裂球允许同时存在 100 个独立分身")
	var cap_simulation := BattleSimulationScript.new(20260831, "splitter", "laser")
	for _activation in range(40):
		cap_simulation.left_ability.activate(
			cap_simulation.battle_context,
			cap_simulation.left,
			cap_simulation.right,
			0
		)
	_check(cap_simulation.count_entities(0, "splitter_clone") == 100, "连续分裂会恰好封顶 100 个分身")
	cap_simulation.left_ability.activate(
		cap_simulation.battle_context,
		cap_simulation.left,
		cap_simulation.right,
		0
	)
	_check(cap_simulation.count_entities(0, "splitter_clone") == 100, "达到上限后不会继续生成第 101 个分身")

	var simulation := BattleSimulationScript.new(20260830, "splitter", "laser")
	simulation.left.pos = Vector2(180.0, 180.0)
	simulation.right.pos = Vector2(500.0, 500.0)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	var clones: Array[BallEntity] = simulation.entity_list(0, "splitter_clone")
	_check(clones.size() == 2, "分裂球首次激活生成两个独立小球")
	_check(is_equal_approx(
		simulation.left_ability.contact_damage(simulation.battle_context, simulation.left, simulation.right),
		5.0
	), "分裂球本体撞击伤害固定为 5")
	if clones.size() < 2:
		return
	var clone := clones[0]
	clones[1].pos = Vector2(580.0, 100.0)
	_check(is_equal_approx(clone.radius, SplitterCloneEntity.BODY_RADIUS), "分身拥有独立的小型碰撞半径")
	_check(is_equal_approx(float(clone.get("hp")), SplitterCloneEntity.MAX_HP), "分身拥有独立生命值")
	clone.pos = Vector2(240.0, 220.0)
	clone.velocity = Vector2(200.0, 0.0)
	simulation.left.pos = Vector2(100.0, 100.0)
	var independent_position := clone.pos
	clone.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_check(clone.pos.x > independent_position.x, "分身按自己的速度自由移动")
	_check(clone.pos.distance_to(simulation.left.pos) > 100.0, "分身的位置不再跟随主球")
	clone.pos = Vector2(clone.radius - 1.0, 180.0)
	clone.velocity = Vector2(-220.0, 0.0)
	clone.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_check(clone.pos.x >= clone.radius and clone.velocity.x > 0.0, "分身使用自己的碰撞体反弹墙面")
	clone.set("_contact_timer", 0.0)
	simulation.right.pos = Vector2(340.0, 320.0)
	simulation.right.velocity = Vector2.ZERO
	clone.pos = simulation.right.pos - Vector2(simulation.right.radius + clone.radius - 0.5, 0.0)
	clone.velocity = Vector2(220.0, 0.0)
	var target_hp_before := simulation.right.hp
	var clone_hp_before := float(clone.get("hp"))
	clone.process_step(simulation.battle_context, 0.0)
	_check(is_equal_approx(
		target_hp_before - simulation.right.hp,
		SplitterCloneEntity.CONTACT_DAMAGE * simulation.damage_scale
	), "分身撞击伤害固定为 2 并走统一伤害倍率")
	_check(is_equal_approx(float(clone.get("hp")), clone_hp_before - SplitterCloneEntity.IMPACT_WEAR), "分身碰撞后独立掉血")
	_check(int(simulation.stats.get("clone_contact_hits", 0)) == 1, "分身碰撞拥有独立命中统计")
	while simulation.count_entities(0, "splitter_clone") < 4:
		simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	simulation.left_ability.after_entities_step(simulation.battle_context, simulation.left, simulation.right, 0, 0.0)
	clones = simulation.entity_list(0, "splitter_clone")
	_check(SplitterCloneEntity.HEALTH_BARS_PER_ROW == 1, "分身血条每行固定排列一个")
	for index in range(clones.size()):
		_check(int(clones[index].call("health_bar_index")) == index, "存活分身血条按紧凑顺序排列")
	clone.call("receive_collision_damage", simulation.battle_context, SplitterCloneEntity.MAX_HP)
	_check(clone.removed and is_zero_approx(float(clone.get("hp"))), "分身生命耗尽后独立死亡")
	simulation.step(0.0)
	_check(not simulation.entities.has(clone), "死亡分身由通用实体生命周期清理")

func _check_splitter_attack_reception() -> void:
	var projectile_simulation := BattleSimulationScript.new(20260902, "splitter", "replicator")
	projectile_simulation.left.pos = Vector2(100.0, 320.0)
	projectile_simulation.right.pos = Vector2(600.0, 320.0)
	projectile_simulation.left_ability.activate(
		projectile_simulation.battle_context,
		projectile_simulation.left,
		projectile_simulation.right,
		0
	)
	var projectile_clones: Array[BallEntity] = projectile_simulation.entity_list(0, "splitter_clone")
	_check(projectile_clones.size() >= 2, "投射物受击测试成功生成分身")
	if projectile_clones.size() < 2:
		return
	var struck_clone := projectile_clones[0]
	struck_clone.pos = Vector2(300.0, 320.0)
	var struck_hp_before := float(struck_clone.get("hp"))
	var main_hp_before := projectile_simulation.left.hp
	projectile_simulation.add_projectile(
		1,
		Vector2(360.0, 320.0),
		Vector2(-600.0, 0.0),
		5.0,
		4.0,
		Color("38d9ff"),
		2.0,
		"splitter_hit_test"
	)
	var projectile: BallProjectileEntity = projectile_simulation.entity_list(1, "projectile")[0]
	projectile.process_step(projectile_simulation.battle_context, 0.2)
	_check(projectile.removed, "非穿透投射物命中分身后立即消除")
	_check(is_equal_approx(
		struck_hp_before - float(struck_clone.get("hp")),
		4.0 * projectile_simulation.damage_scale
	), "敌方投射物按统一伤害倍率扣除分身生命")
	_check(is_equal_approx(projectile_simulation.left.hp, main_hp_before), "被分身挡住的非穿透投射物不会继续命中本体")

	var friendly_clone := projectile_clones[1]
	friendly_clone.pos = Vector2(300.0, 420.0)
	var friendly_hp_before := float(friendly_clone.get("hp"))
	projectile_simulation.add_projectile(
		0,
		Vector2(360.0, 420.0),
		Vector2(-600.0, 0.0),
		5.0,
		4.0,
		Color.WHITE,
		2.0,
		"friendly_pass_test"
	)
	var friendly_projectile: BallProjectileEntity = projectile_simulation.entity_list(0, "projectile")[0]
	friendly_projectile.process_step(projectile_simulation.battle_context, 0.2)
	_check(not friendly_projectile.removed, "己方投射物穿过分身时不会误判命中")
	_check(is_equal_approx(float(friendly_clone.get("hp")), friendly_hp_before), "己方攻击不会扣除分身生命")

	var beam_simulation := BattleSimulationScript.new(20260903, "splitter", "laser")
	beam_simulation.left.pos = Vector2(100.0, 300.0)
	beam_simulation.right.pos = Vector2(500.0, 300.0)
	beam_simulation.left_ability.activate(
		beam_simulation.battle_context,
		beam_simulation.left,
		beam_simulation.right,
		0
	)
	beam_simulation.left_ability.activate(
		beam_simulation.battle_context,
		beam_simulation.left,
		beam_simulation.right,
		0
	)
	var beam_clones: Array[BallEntity] = beam_simulation.entity_list(0, "splitter_clone")
	_check(beam_clones.size() >= 3, "穿透攻击测试成功生成多个分身")
	if beam_clones.size() >= 3:
		beam_clones[0].pos = Vector2(400.0, 300.0)
		beam_clones[1].pos = Vector2(300.0, 300.0)
		beam_clones[2].pos = Vector2(300.0, 420.0)
		var first_hp_before := float(beam_clones[0].get("hp"))
		var second_hp_before := float(beam_clones[1].get("hp"))
		var off_beam_hp_before := float(beam_clones[2].get("hp"))
		beam_simulation.right_ability.activate(
			beam_simulation.battle_context,
			beam_simulation.right,
			beam_simulation.left,
			1
		)
		var expected_beam_damage := 20.6 * beam_simulation.damage_scale
		_check(is_equal_approx(first_hp_before - float(beam_clones[0].get("hp")), expected_beam_damage), "穿透激光会扣除路径上第一个分身生命")
		_check(is_equal_approx(second_hp_before - float(beam_clones[1].get("hp")), expected_beam_damage), "穿透激光会继续命中路径上的后续分身")
		_check(is_equal_approx(float(beam_clones[2].get("hp")), off_beam_hp_before), "攻击不会主动改为追踪光束外的分身")

	var area_simulation := BattleSimulationScript.new(20260904, "splitter", "vampire")
	area_simulation.left.pos = Vector2(100.0, 260.0)
	area_simulation.right.pos = Vector2(420.0, 260.0)
	area_simulation.left_ability.activate(
		area_simulation.battle_context,
		area_simulation.left,
		area_simulation.right,
		0
	)
	var area_clones: Array[BallEntity] = area_simulation.entity_list(0, "splitter_clone")
	if not area_clones.is_empty():
		area_clones[0].pos = Vector2(470.0, 260.0)
		var area_clone_hp_before := float(area_clones[0].get("hp"))
		var area_main_hp_before := area_simulation.left.hp
		area_simulation.right_ability.activate(
			area_simulation.battle_context,
			area_simulation.right,
			area_simulation.left,
			1
		)
		_check(area_clones[0].get("hp") < area_clone_hp_before, "范围攻击会伤害实际落在范围内的分身")
		_check(is_equal_approx(area_simulation.left.hp, area_main_hp_before), "本体不在范围内时不会因分身受击而被连带扣血")

	var contact_simulation := BattleSimulationScript.new(20260905, "splitter", "sonic")
	contact_simulation.left_ability.activate(
		contact_simulation.battle_context,
		contact_simulation.left,
		contact_simulation.right,
		0
	)
	var contact_clones: Array[BallEntity] = contact_simulation.entity_list(0, "splitter_clone")
	if not contact_clones.is_empty():
		var contact_clone := contact_clones[0]
		contact_simulation.right.pos = Vector2(420.0, 320.0)
		contact_simulation.right.velocity = Vector2(-400.0, 0.0)
		contact_clone.pos = contact_simulation.right.pos - Vector2(
			contact_simulation.right.radius + contact_clone.radius - 0.5,
			0.0
		)
		contact_clone.velocity = Vector2(220.0, 0.0)
		contact_clone.set("_contact_timer", 0.0)
		var contact_hp_before := float(contact_clone.get("hp"))
		var sonic_contact_damage: float = contact_simulation.right_ability.contact_damage(
			contact_simulation.battle_context,
			contact_simulation.right,
			contact_clone
		)
		contact_clone.process_step(contact_simulation.battle_context, 0.0)
		var expected_contact_damage := (
			sonic_contact_damage * contact_simulation.damage_scale
			+ SplitterCloneEntity.IMPACT_WEAR
		)
		_check(is_equal_approx(
			contact_hp_before - float(contact_clone.get("hp")),
			expected_contact_damage
		), "具备本体撞击能力的敌球碰到分身时会结算能力伤害")

func _check_black_hole_orbit_force() -> void:
	var simulation := BattleSimulationScript.new(20260822, "black_hole", "heaven")
	_check(is_equal_approx(simulation.left.cooldown, 6.3), "黑洞技能发动间隔为原来 4.2 秒的 1.5 倍")
	_check(is_equal_approx(
		simulation.left_ability.speed_multiplier(simulation.battle_context, simulation.left, simulation.right, 0),
		1.0
	), "黑洞技能未发动时保持正常速度")
	simulation.left.pos = Vector2(320.0, 320.0)
	simulation.right.pos = Vector2(540.0, 320.0)
	simulation.right.velocity = Vector2.ZERO
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	_check(is_equal_approx(
		simulation.left_ability.speed_multiplier(simulation.battle_context, simulation.left, simulation.right, 0),
		0.62
	), "黑洞技能发动期间由自身能力降速至 62%")
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(simulation.right.velocity.x < 0.0, "黑洞把目标牵引向轨道半径")
	_check(absf(simulation.right.velocity.y) > 0.0, "黑洞在吸引过程中加入柔和切向牵引")
	_check(simulation.right.velocity.length() < 20.0, "黑洞单帧只施加连续加速度，不硬改目标速度")
	_check(simulation.has_status(simulation.right, "vortex_tether:"), "目标进入黑洞漩涡牵引状态")
	var initial_distance := simulation.right.pos.distance_to(simulation.left.pos)
	var previous_angle := (simulation.right.pos - simulation.left.pos).angle()
	var angular_travel := 0.0
	for _frame in range(110):
		simulation.left_ability.before_motion(simulation.battle_context, simulation.left, simulation.right, 0, BattleSimulation.FIXED_STEP)
		simulation.left_ability.on_step(simulation.battle_context, simulation.left, simulation.right, 0, BattleSimulation.FIXED_STEP)
		simulation.right.pos += simulation.right.velocity * BattleSimulation.FIXED_STEP
		var current_angle := (simulation.right.pos - simulation.left.pos).angle()
		angular_travel += absf(wrapf(current_angle - previous_angle, -PI, PI))
		previous_angle = current_angle
	_check(angular_travel > 1.2, "黑洞牵引形成持续可见的绕行轨道")
	_check(simulation.right.pos.distance_to(simulation.left.pos) < initial_distance - 28.0, "黑洞轨道会平滑收缩而不是停留在原半径")

func _check_black_hole_wall_damage() -> void:
	var simulation := BattleSimulationScript.new(20260823, "black_hole", "heaven")
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	simulation.right.pos = Vector2(
		BattleSimulation.ARENA_SIZE.x - simulation.right.radius - 0.25,
		320.0
	)
	simulation.right.velocity = Vector2(400.0, 0.0)
	var hp_before := simulation.right.hp
	simulation.step(BattleSimulation.FIXED_STEP)
	_check(simulation.right.hp < hp_before, "被黑洞牵引的球撞墙会掉血")
	_check(int(simulation.stats["gravity_wall_hits"]) == 1, "黑洞牵引撞墙被独立统计")

func _check_black_hole_projectile_capture() -> void:
	var simulation := BattleSimulationScript.new(20260824, "black_hole", "replicator")
	simulation.left.pos = Vector2(320.0, 320.0)
	simulation.right.pos = Vector2(500.0, 500.0)
	var original_color := Color("38d9ff")
	simulation.add_projectile(1, Vector2(630.0, 320.0), Vector2(260.0, 0.0), 5.0, 4.0, original_color, 6.0, "capture_test")
	var projectile: BallProjectileEntity = simulation.entity_list(1, "projectile")[0]
	var initial_distance := projectile.pos.distance_to(simulation.left.pos)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	simulation.left_ability.on_step(simulation.battle_context, simulation.left, simulation.right, 0, BattleSimulation.FIXED_STEP)
	_check(projectile.is_captured(), "黑洞在大范围内直接捕获敌方投射物")
	_check(projectile.owner_side == 1, "被捕获投射物保留原所属阵营")
	_check(projectile.color == original_color, "被捕获投射物完整保留自身原色")
	_check(not projectile.removed, "投射物被捕获后不会瞬间消失")
	_check(int(simulation.stats.get("objects_captured", 0)) == 1, "投射物走统一附属物捕获统计")
	var captured_position := projectile.pos
	var black_hole_hp_before := simulation.left.hp
	projectile.pos = simulation.left.pos
	projectile.process_step(simulation.battle_context, 1.0)
	_check(is_equal_approx(simulation.left.hp, black_hole_hp_before), "被捕获投射物禁用命中与伤害")
	_check(projectile.pos == simulation.left.pos, "被捕获投射物禁用自主移动")
	projectile.pos = captured_position
	var previous_angle := (projectile.pos - simulation.left.pos).angle()
	var angular_travel := 0.0
	var closest_distance := initial_distance
	for _frame in range(360):
		simulation.left_ability.before_motion(simulation.battle_context, simulation.left, simulation.right, 0, BattleSimulation.FIXED_STEP)
		simulation.left_ability.on_step(simulation.battle_context, simulation.left, simulation.right, 0, BattleSimulation.FIXED_STEP)
		if projectile.removed:
			break
		var current_distance := projectile.pos.distance_to(simulation.left.pos)
		var current_angle := (projectile.pos - simulation.left.pos).angle()
		angular_travel += absf(wrapf(current_angle - previous_angle, -PI, PI))
		previous_angle = current_angle
		closest_distance = minf(closest_distance, current_distance)
	_check(angular_travel > 2.0, "被捕获投射物沿黑洞轨道持续绕行")
	_check(closest_distance < initial_distance * 0.45, "捕获轨道逐圈向事件视界收缩")
	_check(projectile.removed, "被捕获投射物最终进入事件视界并被吞噬")
	_check(int(simulation.stats.get("objects_absorbed", 0)) == 1, "轨道吞噬计入对象吞噬统计")
	var absorption_effects := simulation.entity_list(0, "absorption_vfx")
	_check(absorption_effects.size() == 1, "投射物最终触发压缩消失动画")
	if absorption_effects.size() == 1:
		var effect_color: Color = absorption_effects[0].get("_color")
		_check(effect_color == original_color, "压缩消失与收束粒子继续使用投射物原色")

func _check_black_hole_absorption() -> void:
	var simulation := BattleSimulationScript.new(20260827, "black_hole", "replicator")
	simulation.left.pos = Vector2(320.0, 320.0)
	simulation.right.pos = Vector2(500.0, 320.0)
	var zone := TestAbsorbableEntity.new(1, Vector2(420.0, 320.0), 8.0, "zone_fixture")
	var anchor := TestAbsorbableEntity.new(1, Vector2(430.0, 320.0), 0.0, "anchor_fixture")
	var edge_object := TestAbsorbableEntity.new(1, Vector2(440.0, 320.0), 0.0, "expanded_radius_fixture")
	var clone := TestAbsorbableEntity.new(1, simulation.right.pos, simulation.right.radius + 18.0, "clone")
	simulation.add_entity(zone)
	simulation.add_entity(anchor)
	simulation.add_entity(edge_object)
	simulation.add_entity(clone)
	var zone_distance_before := zone.pos.distance_to(simulation.left.pos)
	var anchor_distance_before := anchor.pos.distance_to(simulation.left.pos)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	simulation.left_ability.on_step(simulation.battle_context, simulation.left, simulation.right, 0, 0.1)
	_check(int(simulation.stats.get("objects_absorbed", 0)) == 0, "黑洞不会让远处非本体瞬间消失")
	_check(int(simulation.stats.get("objects_captured", 0)) == 4, "持续区域、锚点、场景物件和分身统一进入捕获轨道")
	for entity in [zone, anchor, edge_object, clone]:
		_check(entity.is_captured(), "%s 被黑洞捕获并禁用" % entity.tags[0])
		_check(entity.owner_side == 1, "%s 被捕获后保留原阵营" % entity.tags[0])
		_check(not entity.removed, "%s 被捕获后不会瞬间消失" % entity.tags[0])
	_check(zone.pos.distance_to(simulation.left.pos) < zone_distance_before, "持续区域沿收缩轨道被吸向黑洞")
	_check(anchor.pos.distance_to(simulation.left.pos) < anchor_distance_before, "场景物件沿收缩轨道被吸向黑洞")
	var disabled_position := zone.pos
	zone.velocity = Vector2(300.0, 0.0)
	zone.process_step(simulation.battle_context, 1.0)
	_check(zone.pos == disabled_position, "被捕获的非投射物同样禁用自主行为")
	for _frame in range(240):
		simulation.left_ability.before_motion(simulation.battle_context, simulation.left, simulation.right, 0, BattleSimulation.FIXED_STEP)
		simulation.left_ability.on_step(simulation.battle_context, simulation.left, simulation.right, 0, BattleSimulation.FIXED_STEP)
		if zone.removed and anchor.removed and edge_object.removed and clone.removed:
			break
	_check(int(simulation.stats.get("objects_absorbed", 0)) == 4, "四类敌方非本体最终都进入事件视界")
	_check(zone.removed, "黑洞移除范围内的敌方持续区域")
	_check(anchor.removed, "黑洞移除范围内的敌方场景物件")
	_check(edge_object.removed, "敌方附属物在 72 像素事件视界内被吞噬")
	_check(clone.removed, "黑洞能够捕获复制或分裂出来的非本体")
	var absorption_effects := simulation.entity_list(0, "absorption_vfx")
	_check(absorption_effects.size() == 4, "每个被吞噬对象都会生成独立压缩动画")
	var particle_count_before := simulation.particles.size()
	for effect in absorption_effects:
		effect.step(simulation.battle_context, 0.5)
	_check(simulation.entity_list(0, "absorption_vfx").is_empty(), "压缩动画最终缩小到完全消失")
	_check(simulation.particles.size() >= particle_count_before + 48, "完全吞噬后在黑洞旁释放收束粒子")

func _check_time_limit_configuration() -> void:
	var default_battle := BattleSimulationScript.new(20260825, "splitter", "heaven")
	_check(is_equal_approx(default_battle.max_battle_time, 120.0), "普通对局默认时限为两分钟")
	var boss_battle := BattleSimulationScript.new(20260825, "vampire", "six_king")
	_check(is_equal_approx(boss_battle.max_battle_time, 120.0), "默认 Boss 对局时限为两分钟")
	var configured_battle := BattleSimulationScript.new(20260825, "splitter", "heaven", 75.0)
	_check(is_equal_approx(configured_battle.max_battle_time, 75.0), "调用方可以覆盖单局时限")

func _check_visual_rng_isolation() -> void:
	var baseline := BattleSimulationScript.new(20260826, "splitter", "heaven")
	var extra_effects := BattleSimulationScript.new(20260826, "splitter", "heaven")
	extra_effects.spawn_particles(Vector2(320.0, 320.0), Color.WHITE, 100, 300.0)
	for _frame in range(600):
		baseline.step(BattleSimulation.FIXED_STEP)
		extra_effects.step(BattleSimulation.FIXED_STEP)
	_check(baseline.snapshot() == extra_effects.snapshot(), "增减纯视觉粒子不会改变游戏轨迹或胜负规则")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
