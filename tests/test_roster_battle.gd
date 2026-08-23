extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const ProceduralAudioScript := preload("res://scripts/audio/procedural_audio.gd")
const SplitterCloneEntity := preload("res://scripts/balls/splitter/clone_entity.gd")
const PlantPeaProjectileEntity := preload("res://scripts/balls/plant/pea_projectile_entity.gd")
const PlantIceSlowEffect := preload("res://scripts/balls/plant/ice_slow_effect.gd")
const BurnStatusEffectScript := preload("res://scripts/balls/core/burn_status_effect.gd")
const BallSettingsStoreScript := preload("res://scripts/settings/ball_settings_store.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const GlobalSettingsStoreScript := preload("res://scripts/settings/global_settings_store.gd")

var failures: Array[String] = []

class TestAbsorbableEntity extends BallEntity:
	func _init(spawn_owner: int, spawn_position: Vector2, spawn_radius: float, tag: String) -> void:
		owner_side = spawn_owner
		pos = spawn_position
		radius = spawn_radius
		tags = PackedStringArray([tag])

	func is_absorbable() -> bool:
		return true

class TestDamageableEntity extends BallEntity:
	var hp := 100.0

	func _init(spawn_owner: int, spawn_position: Vector2, spawn_radius: float) -> void:
		owner_side = spawn_owner
		pos = spawn_position
		radius = spawn_radius

	func can_receive_attack(source_side: int) -> bool:
		return not removed and is_hostile_to(source_side)

	func receive_attack(_battle, amount: float, source_side: int, _hit_color: Color) -> float:
		if not can_receive_attack(source_side):
			return 0.0
		var applied := minf(hp, amount)
		hp -= applied
		return applied

func _init() -> void:
	BallRegistry.configure_settings({})
	_check(BallRegistry.is_valid(), "球模块注册表通过完整性校验")
	var ids := BallRegistry.ids()
	_check(ids.size() >= 10, "球库保留首批 10 个球")
	var unique := {}
	for ball_id in ids:
		unique[ball_id] = true
		var module: BallModule = BallRegistry.get_module(ball_id)
		_check(module.id == ball_id, "%s 的目录 ID 一致" % ball_id)
		_check(not module.display_name.is_empty(), "%s 有显示名称" % ball_id)
		_check(is_equal_approx(module.max_hp, 100.0), "%s 的默认生命值统一为 100" % ball_id)
		_check(module.cooldown > 0.0, "%s 有有效能力冷却" % ball_id)
		_check(module.setting_specs().size() >= 4, "%s 声明可配置参数 Schema" % ball_id)
		_check(module.create_ability() is BallAbility, "%s 提供独立能力实现" % ball_id)
		_check(module.create_visual() is BallVisual, "%s 提供独立视觉实现" % ball_id)
	_check(unique.size() == ids.size(), "球 ID 不重复")
	_check(not BallRegistry.has_id("not-a-ball"), "未知球 ID 被注册表拒绝")
	_check_seeded_spawn_directions()
	_check_inertial_motion()
	_check_wall_impact_audio()
	_check_spider_web_abilities()
	_check_sniper_abilities()
	_check_heavy_industry_abilities()
	_check_garen_abilities()
	_check_contact_damage_contract()
	_check_fighter_death_presentation()
	_check_vampire_abilities()
	_check_sonic_speed_growth()
	_check_combat_audio_contract()
	_check_wind_swordsman_abilities()
	_check_forced_movement_priority()
	_check_wind_ice_slow_resume()
	_check_yuri_abilities()
	_check_plant_growth_cycle()
	_check_plant_clone_entity_collision()
	_check_plant_fighter_collision()
	_check_wdc_abilities()
	_check_replicator_dual_ring_formation()
	_check_splitter_clone_bodies()
	_check_splitter_attack_reception()
	_check_black_hole_orbit_force()
	_check_black_hole_wall_damage()
	_check_black_hole_projectile_capture()
	_check_black_hole_absorption()
	_check_time_limit_configuration()
	_check_global_settings_configuration()
	_check_visual_rng_isolation()
	_check_settings_configuration()

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
			var total_damage := float(simulation.stats["damage_to_left"]) + float(simulation.stats["damage_to_right"])
			_check(
				total_damage > 0.0
					or not simulation.left_ability.automatic_activation_enabled()
					or not simulation.right_ability.automatic_activation_enabled(),
				"%s VS %s 有伤害来源，或包含明确关闭自动能力的惰性/被动球" % [simulation.left.display_name, simulation.right.display_name]
			)
			var abilities: Dictionary = simulation.stats["abilities"]
			ability_totals[simulation.left.id] = int(ability_totals[simulation.left.id]) + int(abilities[simulation.left.id])
			ability_totals[simulation.right.id] = int(ability_totals[simulation.right.id]) + int(abilities[simulation.right.id])
			wins[simulation.winner_id] = int(wins[simulation.winner_id]) + 1

	var expected_matchups := ids.size() * (ids.size() - 1) / 2
	_check(matchup_count == expected_matchups, "%d 个球的 %d 种异种组合全部覆盖" % [ids.size(), expected_matchups])
	for ball_id in ids:
		var module: BallModule = BallRegistry.get_module(ball_id)
		var ability: BallAbility = module.create_ability()
		if ability.automatic_activation_enabled():
			_check(int(ability_totals[ball_id]) > 0, "%s 的自动能力至少触发一次" % module.display_name)

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
			_check(_inside_arena(simulation.left, simulation.arena_size()), "%s 始终留在竞技场" % simulation.left.display_name)
			_check(_inside_arena(simulation.right, simulation.arena_size()), "%s 始终留在竞技场" % simulation.right.display_name)
		if simulation.finished:
			break

func _inside_arena(fighter: BattleSimulation.FighterState, arena_size: Vector2) -> bool:
	return (
		fighter.pos.x >= fighter.radius - 0.01
		and fighter.pos.x <= arena_size.x - fighter.radius + 0.01
		and fighter.pos.y >= fighter.radius - 0.01
		and fighter.pos.y <= arena_size.y - fighter.radius + 0.01
	)

func _check_seeded_spawn_directions() -> void:
	var first := BattleSimulationScript.new(20260831, "vampire", "wdc")
	var replay := BattleSimulationScript.new(20260831, "vampire", "wdc")
	var divergent := BattleSimulationScript.new(20260901, "vampire", "wdc")
	_check(first.left.velocity.is_equal_approx(replay.left.velocity), "相同种子复现左球初始方向")
	_check(first.right.velocity.is_equal_approx(replay.right.velocity), "相同种子复现右球初始方向")
	_check(not first.left.velocity.normalized().is_equal_approx(divergent.left.velocity.normalized()), "不同种子改变左球初始方向")
	_check(not first.right.velocity.normalized().is_equal_approx(divergent.right.velocity.normalized()), "不同种子改变右球初始方向")
	_check(
		is_equal_approx(first.left.velocity.length(), first.left_module.speed),
		"左球随机方向保留自身配置的初始速度大小"
	)
	_check(
		is_equal_approx(first.right.velocity.length(), first.right_module.speed),
		"右球随机方向保留自身配置的初始速度大小"
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

func _check_heavy_industry_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("heavy_industry")
	_check(module.display_name == "重工球", "重工球通过目录自动发现并使用公开中文名")
	_check(is_equal_approx(module.settingf("tank_max_hp"), 15.0), "重工球坦克默认拥有 15 点生命")
	_check(is_equal_approx(module.settingf("tank_contact_damage"), 3.0), "重工球坦克默认碰撞伤害为 3")
	_check(is_equal_approx(module.settingf("shell_damage"), 4.0), "重工球坦克炮弹默认伤害为 4")

	var simulation := BattleSimulationScript.new(20261224, "heavy_industry", "laser")
	_check(
		is_equal_approx(simulation.left.ability_timer, simulation.left.cooldown),
		"重工球首次出仓与后续出仓都遵循完整可配置冷却"
	)
	_check(
		is_zero_approx(simulation.left_ability.contact_damage(
			simulation.battle_context,
			simulation.left,
			simulation.right
		)),
		"重工球本体保持普通碰撞无伤害"
	)
	var initial_port_angle := float(simulation.left_ability.call("port_angle"))
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.25
	)
	var rotated_port_angle := float(simulation.left_ability.call("port_angle"))
	_check(not is_equal_approx(initial_port_angle, rotated_port_angle), "重工球出仓口空闲时进行 360° 连续旋转")
	simulation.left_ability.activate(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0
	)
	var deployment_duration := module.settingf("deployment_animation_duration")
	_check(
		bool(simulation.left_ability.call("deployment_animation_active")),
		"成功生产坦克后启动球内私有出仓动画"
	)
	_check(
		is_zero_approx(float(simulation.left_ability.call("deployment_gate_open_amount"))),
		"出仓动画首帧双门保持闭合"
	)
	var deployment_port_angle := float(simulation.left_ability.call("port_angle"))
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		deployment_duration * 0.2
	)
	_check(
		is_equal_approx(float(simulation.left_ability.call("port_angle")), deployment_port_angle),
		"坦克出仓期间门体暂停旋转并保持生产方向"
	)
	_check(
		float(simulation.left_ability.call("deployment_gate_open_amount")) > 0.0,
		"出仓动画前段双门开始向两侧滑开"
	)
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		deployment_duration * 0.2
	)
	_check(
		is_equal_approx(float(simulation.left_ability.call("deployment_gate_open_amount")), 1.0),
		"坦克通过门洞时双门保持完全打开"
	)
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		deployment_duration * 0.5
	)
	var closing_amount := float(simulation.left_ability.call("deployment_gate_open_amount"))
	_check(closing_amount > 0.0 and closing_amount < 1.0, "出仓动画末段双门平滑关闭")
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		deployment_duration * 0.2
	)
	_check(
		not bool(simulation.left_ability.call("deployment_animation_active"))
		and is_zero_approx(float(simulation.left_ability.call("deployment_gate_open_amount"))),
		"出仓动画完成后清理状态并恢复闭门"
	)
	var tanks: Array[BallEntity] = simulation.entity_list(0, "heavy_tank")
	_check(tanks.size() == 1, "重工球沿当前出仓口朝向释放一辆坦克")
	if tanks.is_empty():
		BallRegistry.configure_settings({})
		return
	var tank: BallEntity = tanks[0]
	var deployment_direction := Vector2.from_angle(rotated_port_angle)
	_check(tank.velocity.normalized().dot(deployment_direction) > 0.999, "坦克沿出仓时确定的直线方向运动")
	_check(is_equal_approx(float(tank.get("max_hp")), 15.0), "坦克实体取得自身持久化生命值")
	_check(tank.can_receive_attack(1) and not tank.can_receive_attack(0), "坦克只接受敌方攻击并保留友军保护")
	_check(tank.participates_in_fighter_collision(), "坦克通过通用实体契约阻挡敌方大球")
	_check(tank.participates_in_entity_collision(), "坦克通过通用实体契约参与附属物碰撞")
	_check(is_zero_approx(tank.fighter_collision_inverse_mass()), "坦克碰撞时保持出生巡弋直线不被冲量带偏")

	var arena_size := simulation.arena_size()
	tank.pos = Vector2(arena_size.x - tank.radius - 0.4, 300.0)
	tank.velocity = Vector2(90.0, 45.0)
	var wall_start_y := tank.pos.y
	tank.process_step(simulation.battle_context, 0.02)
	_check(tank.velocity.is_equal_approx(Vector2(-90.0, -45.0)), "坦克碰墙反转完整速度向量而不是按墙面法线折射")
	_check(tank.pos.y < wall_start_y, "坦克碰墙后沿原直线反向折返")
	_check(int(simulation.stats.get("heavy_tank_wall_reversals", 0)) == 1, "坦克原路折返进入独立统计")

	tank.pos = Vector2(340.0, 320.0)
	var tank_position_before_contact := tank.pos
	simulation.right.pos = tank.pos + Vector2(tank.radius + simulation.right.radius - 2.0, 0.0)
	simulation.right.velocity = Vector2(-120.0, 0.0)
	var fighter_hp_before := simulation.right.hp
	simulation.call(
		"_resolve_fighter_entity_collision",
		simulation.right,
		simulation.right_ability,
		1,
		tank
	)
	_check(is_equal_approx(fighter_hp_before - simulation.right.hp, 3.0), "坦克触碰敌方主球造成 3 点默认碰撞伤害")
	_check(tank.pos.is_equal_approx(tank_position_before_contact), "坦克撞击大球后仍不偏离巡弋线")

	var tank_hp_before := float(tank.get("hp"))
	var applied_to_tank := simulation.damage_entity(tank, 5.0, simulation.right.accent, 1)
	_check(is_equal_approx(applied_to_tank, 5.0), "敌方攻击命中坦克时正确结算伤害")
	_check(is_equal_approx(float(tank.get("hp")), tank_hp_before - 5.0), "坦克被命中后扣除自己的独立生命")

	simulation.right.pos = tank.pos + Vector2(0.0, -220.0)
	var turret_angle_before := float(tank.call("turret_angle"))
	tank.process_step(simulation.battle_context, 0.1)
	var turret_angle_after := float(tank.call("turret_angle"))
	_check(not is_equal_approx(turret_angle_before, turret_angle_after), "坦克炮塔独立于履带朝向旋转追踪敌球")
	tank.set("_fire_timer", 0.01)
	tank.process_step(simulation.battle_context, 0.02)
	var shells := simulation.entity_list(0, "projectile")
	_check(shells.size() == 1, "坦克按自己的射击间隔发射标准炮弹")
	if not shells.is_empty():
		_check(String(shells[0].get("projectile_type")) == "tank_shell", "坦克炮弹拥有独立投射物语义")
		_check(is_equal_approx(float(shells[0].get("damage_amount")), 4.0), "坦克炮弹携带 4 点默认伤害")
	_check(int(simulation.stats.get("heavy_tank_shells_fired", 0)) == 1, "坦克开炮进入独立统计")

	var native_tank_color := tank.absorption_visual_color()
	_check(tank.transfer_ownership(1, simulation.right), "坦克支持通用永久所有权转移")
	tank.set_ownership_visual_color(Color("b65cff"))
	_check(tank.owner_side == 1, "被控制的坦克永久切换阵营")
	_check(tank.absorption_visual_color() != native_tank_color, "被控制坦克通过自身绘制契约改变颜色")

	var capture := BattleSimulationScript.new(20261225, "black_hole", "heavy_industry")
	capture.left.pos = Vector2(320.0, 320.0)
	capture.right.pos = Vector2(500.0, 320.0)
	capture.right_ability.activate(
		capture.battle_context,
		capture.right,
		capture.left,
		1
	)
	var capture_tanks := capture.entity_list(1, "heavy_tank")
	_check(capture_tanks.size() == 1, "黑洞反制场景生成敌方坦克")
	if not capture_tanks.is_empty():
		var captured_tank: BallEntity = capture_tanks[0]
		var original_owner := captured_tank.owner_side
		var original_color := captured_tank.absorption_visual_color()
		capture.left_ability.activate(capture.battle_context, capture.left, capture.right, 0)
		capture.left_ability.on_step(
			capture.battle_context,
			capture.left,
			capture.right,
			0,
			BattleSimulation.FIXED_STEP
		)
		_check(captured_tank.is_captured(), "坦克进入黑洞范围后通过通用协议被捕获")
		_check(captured_tank.owner_side == original_owner, "黑洞捕获坦克时不改变阵营")
		_check(captured_tank.absorption_visual_color() == original_color, "黑洞捕获坦克时保留原色")
		var captured_position := captured_tank.pos
		var shell_count_before := capture.count_entities(1, "projectile")
		captured_tank.process_step(capture.battle_context, 1.0)
		_check(captured_tank.pos == captured_position, "被捕获坦克立即停止巡弋")
		_check(capture.count_entities(1, "projectile") == shell_count_before, "被捕获坦克立即停止开炮")

	BallRegistry.configure_settings({
		"heavy_industry": {
			"max_tanks": 2,
			"tank_max_hp": 27.0,
			"tank_contact_damage": 6.0,
			"shell_damage": 9.0,
		},
	})
	var configured := BattleSimulationScript.new(20261226, "heavy_industry", "heaven")
	for _activation in range(4):
		configured.left_ability.activate(
			configured.battle_context,
			configured.left,
			configured.right,
			0
		)
	var configured_tanks := configured.entity_list(0, "heavy_tank")
	_check(configured_tanks.size() == 2, "重工球持久化坦克上限限制实际出仓数量")
	if not configured_tanks.is_empty():
		_check(is_equal_approx(float(configured_tanks[0].get("max_hp")), 27.0), "重工球自定义坦克生命进入实体")
		_check(is_equal_approx(configured_tanks[0].entity_contact_damage(), 6.0), "重工球自定义坦克碰撞伤害进入实体")
		configured_tanks[0].set("_fire_timer", 0.0)
		configured_tanks[0].process_step(configured.battle_context, BattleSimulation.FIXED_STEP)
		var configured_shells := configured.entity_list(0, "projectile")
		_check(
			not configured_shells.is_empty()
			and is_equal_approx(float(configured_shells[0].get("damage_amount")), 9.0),
			"重工球自定义炮弹伤害进入投射物"
		)
	_check(is_equal_approx(configured.right.max_hp, 100.0), "重工球配置不会串改对手参数")
	BallRegistry.configure_settings({})

	var deterministic_a := BattleSimulationScript.new(20261227, "heavy_industry", "plant")
	var deterministic_b := BattleSimulationScript.new(20261227, "heavy_industry", "plant")
	for _frame in range(600):
		deterministic_a.step(BattleSimulation.FIXED_STEP)
		deterministic_b.step(BattleSimulation.FIXED_STEP)
	_check(deterministic_a.snapshot() == deterministic_b.snapshot(), "重工球坦克生产、运动与开炮可以按种子确定性重放")

func _check_garen_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("garen")
	_check(module.display_name == "盖伦球", "盖伦球通过目录自动发现并使用公开中文名")
	_check(module.sound_kind == "garen_spin_whoosh", "盖伦球旋转起手只绑定自己的破空声")
	var garen_audio_samples := module.audio_samples()
	_check(garen_audio_samples.has("garen_sword_hit"), "盖伦球独立声明短促破空命中采样")
	_check(garen_audio_samples.has("garen_spin_whoosh"), "盖伦球独立声明旋转起手破空采样")
	_check(bool(garen_audio_samples["garen_spin_whoosh"].get("loop", false)), "盖伦球声明旋转破空采样需要持续循环")
	_check(not garen_audio_samples.has("blade_slash"), "盖伦球不再复用风剑球 Hasagi 事件")
	var garen_audio = ProceduralAudioScript.new()
	garen_audio.configure_samples(BallRegistry.audio_samples())
	_check(garen_audio.has_sample_event("garen_sword_hit"), "战斗音频系统装载盖伦球短促破空命中声")
	var garen_sword_hit_duration := garen_audio.sample_event_duration("garen_sword_hit")
	_check(garen_sword_hit_duration >= 0.20 and garen_sword_hit_duration <= 0.30, "剑命中声直接采用一段短促的物体挥动破空采样")
	_check(garen_audio.has_sample_event("garen_spin_whoosh"), "战斗音频系统装载盖伦球旋转破空声")
	_check(garen_audio.sample_event_loops("garen_spin_whoosh"), "战斗音频系统按通用采样契约循环旋转破空声")
	_check(not garen_audio.sample_event_loops("garen_sword_hit"), "短促命中采样保持单次播放")
	var garen_spin_whoosh_duration := garen_audio.sample_event_duration("garen_spin_whoosh")
	_check(garen_spin_whoosh_duration >= 0.80 and garen_spin_whoosh_duration <= 0.95, "旋转起手声保留完整的三段棍棒式挥动气流节奏")
	garen_audio.free()
	_check(is_equal_approx(module.settingf("sword_length"), 110.0), "盖伦球默认剑长为 110")
	_check(is_equal_approx(module.settingf("sword_width"), 16.0), "盖伦球默认剑宽为 16")
	_check(is_equal_approx(module.settingf("sword_damage"), 10.0), "盖伦球默认普通触剑伤害为 10")
	_check(is_equal_approx(module.cooldown, 6.0), "盖伦球默认每 6 秒发动剑刃旋转")
	_check(is_equal_approx(module.settingf("spin_duration"), 2.5), "盖伦球默认旋转持续 2.5 秒")
	_check(is_equal_approx(module.settingf("spin_turns_per_second"), 1.5), "盖伦球默认每秒旋转 1.5 圈")
	_check(is_equal_approx(module.settingf("spin_sword_damage"), 6.0), "盖伦球默认旋转触剑伤害为 6")

	var simulation := BattleSimulationScript.new(20261229, "garen", "laser")
	simulation.left.pos = Vector2(240.0, 320.0)
	simulation.right.pos = Vector2(340.0, 320.0)
	simulation.left.velocity = Vector2.ZERO
	simulation.right.velocity = Vector2(37.0, -19.0)
	_check(
		is_equal_approx(simulation.left.ability_timer, simulation.left.cooldown),
		"盖伦球首次旋转与后续旋转都遵循完整可配置冷却"
	)
	_check(
		is_zero_approx(simulation.left_ability.contact_damage(
			simulation.battle_context,
			simulation.left,
			simulation.right
		)),
		"盖伦球本体保持普通碰撞无伤害"
	)

	var velocity_before_hit := simulation.right.velocity
	var position_before_hit := simulation.right.pos
	var hp_before_hit := simulation.right.hp
	simulation.take_combat_events()
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	_check(is_equal_approx(hp_before_hit - simulation.right.hp, 10.0), "敌球首次接触常驻长剑扣除普通触剑伤害")
	_check(simulation.right.velocity == velocity_before_hit, "无碰撞长剑命中不会改变敌球速度")
	_check(simulation.right.pos == position_before_hit, "无碰撞长剑命中不会推动敌球位置")
	var sword_hit_events := simulation.take_combat_events()
	_check(_count_combat_events(sword_hit_events, "garen_sword_hit") == 1, "盖伦球触剑只发送自己的短促破空命中事件")
	_check(_count_combat_events(sword_hit_events, "blade_slash") == 0, "盖伦球触剑不会再触发 Hasagi 语音事件")
	var hp_during_same_contact := simulation.right.hp
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	_check(is_equal_approx(simulation.right.hp, hp_during_same_contact), "敌球没有离开同一柄剑时不会连续扣血")

	simulation.right.pos = Vector2(560.0, 500.0)
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	_check(not bool(simulation.left_ability.call("sword_contacting_opponent")), "敌球离开剑刃后重新武装触剑伤害")
	simulation.right.pos = Vector2(340.0, 320.0)
	var hp_before_reentry := simulation.right.hp
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	_check(is_equal_approx(hp_before_reentry - simulation.right.hp, 10.0), "敌球离剑后再次接触可重新受伤")

	simulation.left_ability.activate(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0
	)
	_check(bool(simulation.left_ability.call("spin_active")), "盖伦球发动技能后进入独立剑刃旋转状态")
	_check(int(simulation.stats.get("garen_spins", 0)) == 1, "剑刃旋转进入盖伦球私有统计")
	simulation.right.pos = Vector2(560.0, 500.0)
	var angle_before_spin := float(simulation.left_ability.call("sword_angle"))
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.1
	)
	var expected_spin_delta := TAU * module.settingf("spin_turns_per_second") * 0.1
	var actual_spin_delta := fposmod(float(simulation.left_ability.call("sword_angle")) - angle_before_spin, TAU)
	_check(is_equal_approx(actual_spin_delta, expected_spin_delta), "剑刃按可配置的小数圈速连续旋转")

	var spin_direction: Vector2 = simulation.left_ability.call("sword_direction")
	simulation.right.pos = simulation.left.pos + spin_direction * (simulation.left.radius + 48.0)
	var spin_velocity_before := simulation.right.velocity
	var spin_hp_before := simulation.right.hp
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	_check(is_equal_approx(spin_hp_before - simulation.right.hp, 6.0), "旋转期间触剑使用独立修正伤害")
	_check(simulation.right.velocity == spin_velocity_before, "旋转长剑仍不参与物理碰撞")

	var audio_timeline_simulation := BattleSimulationScript.new(20261231, "garen", "laser")
	audio_timeline_simulation.left.pos = Vector2(120.0, 120.0)
	audio_timeline_simulation.right.pos = Vector2(520.0, 520.0)
	audio_timeline_simulation.left_ability.activate(
		audio_timeline_simulation.battle_context,
		audio_timeline_simulation.left,
		audio_timeline_simulation.right,
		0
	)
	audio_timeline_simulation.take_combat_events()
	audio_timeline_simulation.left_ability.on_step(
		audio_timeline_simulation.battle_context,
		audio_timeline_simulation.left,
		audio_timeline_simulation.right,
		0,
		module.settingf("spin_duration") - BattleSimulation.FIXED_STEP
	)
	_check(
		_count_combat_events(audio_timeline_simulation.take_combat_events(), "garen_spin_whoosh") == 0,
		"旋转仍在持续时不会提前停止循环破空声"
	)
	audio_timeline_simulation.left_ability.on_step(
		audio_timeline_simulation.battle_context,
		audio_timeline_simulation.left,
		audio_timeline_simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	var spin_end_events := audio_timeline_simulation.take_combat_events()
	var spin_stop_events := 0
	for event in spin_end_events:
		if String(event["kind"]) == "garen_spin_whoosh" and is_zero_approx(float(event["strength"])):
			spin_stop_events += 1
	_check(spin_stop_events == 1, "剑刃旋转结束的同一帧发送一次破空循环停止事件")
	_check(not bool(audio_timeline_simulation.left_ability.call("spin_active")), "破空循环停止时剑刃旋转状态同步结束")

	var clone_simulation := BattleSimulationScript.new(20261232, "garen", "splitter")
	clone_simulation.left.pos = Vector2(200.0, 320.0)
	clone_simulation.right.pos = Vector2(550.0, 320.0)
	clone_simulation.left.velocity = Vector2.ZERO
	clone_simulation.right.velocity = Vector2.ZERO
	clone_simulation.right_ability.activate(
		clone_simulation.battle_context,
		clone_simulation.right,
		clone_simulation.left,
		1
	)
	var clones: Array[BallEntity] = clone_simulation.entity_list(1, "splitter_clone")
	_check(not clones.is_empty(), "盖伦球附属物命中用例生成真实分身球分身")
	if not clones.is_empty():
		var clone: BallEntity = clones[0]
		clone.pos = Vector2(310.0, 320.0)
		clone.velocity = Vector2.ZERO
		clone_simulation.left_ability.activate(
			clone_simulation.battle_context,
			clone_simulation.left,
			clone_simulation.right,
			0
		)
		clone_simulation.take_combat_events()
		var clone_position_before := clone.pos
		var clone_velocity_before := clone.velocity
		clone_simulation.left_ability.on_step(
			clone_simulation.battle_context,
			clone_simulation.left,
			clone_simulation.right,
			0,
			0.0
		)
		_check(is_equal_approx(float(clone.get("hp")), 4.0), "旋转长剑命中分身球分身并扣除 6 点配置伤害")
		_check(clone.pos == clone_position_before and clone.velocity == clone_velocity_before, "长剑命中分身仍不施加物理推力")
		_check(int(clone_simulation.left_ability.call("sword_contacting_entity_count")) == 1, "分身连续触剑状态由盖伦球能力独立锁存")
		var clone_first_hit_events := clone_simulation.take_combat_events()
		_check(_count_combat_events(clone_first_hit_events, "garen_sword_hit") == 1, "长剑命中分身播放短促破空命中声")
		_check(_count_combat_events(clone_first_hit_events, "blade_slash") == 0, "长剑命中分身不会播放 Hasagi")
		clone_simulation.left_ability.on_step(
			clone_simulation.battle_context,
			clone_simulation.left,
			clone_simulation.right,
			0,
			0.0
		)
		_check(is_equal_approx(float(clone.get("hp")), 4.0), "同一分身未离开剑刃前不会连续扣血")
		clone.pos = Vector2(500.0, 500.0)
		clone_simulation.left_ability.on_step(
			clone_simulation.battle_context,
			clone_simulation.left,
			clone_simulation.right,
			0,
			0.0
		)
		_check(int(clone_simulation.left_ability.call("sword_contacting_entity_count")) == 0, "分身离开剑刃后重置自己的触剑锁存")
		clone.pos = Vector2(310.0, 320.0)
		clone_simulation.left_ability.on_step(
			clone_simulation.battle_context,
			clone_simulation.left,
			clone_simulation.right,
			0,
			0.0
		)
		_check(bool(clone.get("removed")), "分身离剑后再次进入可被旋转长剑正确击破")

	simulation.right.pos = Vector2(540.0, 470.0)
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		module.settingf("spin_duration")
	)
	var target_direction := (simulation.right.pos - simulation.left.pos).normalized()
	var restored_direction: Vector2 = simulation.left_ability.call("sword_direction")
	_check(not bool(simulation.left_ability.call("spin_active")), "可配置持续时间结束后剑刃旋转停止")
	_check(restored_direction.dot(target_direction) > 0.9999, "停止旋转后长剑立即恢复指向敌方球")

	BallRegistry.configure_settings({
		"garen": {
			"cooldown": 8.5,
			"sword_length": 155.0,
			"sword_width": 23.0,
			"sword_damage": 13.5,
			"spin_duration": 3.2,
			"spin_turns_per_second": 2.3,
			"spin_sword_damage": 4.5,
		},
	})
	var configured := BattleSimulationScript.new(20261230, "garen", "heaven")
	_check(is_equal_approx(configured.left.cooldown, 8.5), "盖伦球旋转间隔使用自己的持久化配置")
	_check(is_equal_approx(configured.left_module.settingf("sword_length"), 155.0), "盖伦球自定义剑长进入新对局")
	_check(is_equal_approx(configured.left_module.settingf("sword_width"), 23.0), "盖伦球自定义剑宽进入新对局")
	_check(is_equal_approx(configured.left_module.settingf("sword_damage"), 13.5), "盖伦球自定义普通触剑伤害进入新对局")
	_check(is_equal_approx(configured.left_module.settingf("spin_duration"), 3.2), "盖伦球自定义旋转时长进入新对局")
	_check(is_equal_approx(configured.left_module.settingf("spin_turns_per_second"), 2.3), "盖伦球自定义小数圈速进入新对局")
	_check(is_equal_approx(configured.left_module.settingf("spin_sword_damage"), 4.5), "盖伦球自定义旋转伤害进入新对局")
	_check(is_equal_approx(configured.right.max_hp, 100.0), "盖伦球配置不会串改对手参数")
	BallRegistry.configure_settings({})

	var deterministic_a := BattleSimulationScript.new(20261231, "garen", "plant")
	var deterministic_b := BattleSimulationScript.new(20261231, "garen", "plant")
	for _frame in range(600):
		deterministic_a.step(BattleSimulation.FIXED_STEP)
		deterministic_b.step(BattleSimulation.FIXED_STEP)
	_check(deterministic_a.snapshot() == deterministic_b.snapshot(), "盖伦球指向、旋转和触剑伤害可以按种子确定性重放")

func _check_wall_impact_audio() -> void:
	var simulation := BattleSimulationScript.new(20260822, "laser", "heaven")
	var arena_size: Vector2 = simulation.arena_size()
	simulation.take_combat_events()
	simulation.left.pos = Vector2(
		arena_size.x - simulation.left.radius + 2.0,
		arena_size.y - simulation.left.radius + 2.0
	)
	simulation.left.velocity = Vector2(180.0, 120.0)
	simulation._resolve_wall(simulation.left)
	var corner_events := simulation.take_combat_events()
	_check(
		_count_combat_events(corner_events, "wall_impact") == 1,
		"球在墙角同时触碰两面时只发送一次撞墙音效"
	)
	var wall_strength := -1.0
	for event: Dictionary in corner_events:
		if String(event.get("kind", "")) == "wall_impact":
			wall_strength = float(event.get("strength", -1.0))
			break
	_check(
		wall_strength >= BattleSimulation.WALL_IMPACT_MIN_STRENGTH
			and wall_strength <= BattleSimulation.WALL_IMPACT_MAX_STRENGTH
			and wall_strength < 0.5,
		"撞墙音量强度保持低于大球互撞"
	)
	simulation.left.pos = arena_size * 0.5
	simulation._resolve_wall(simulation.left)
	_check(
		_count_combat_events(simulation.take_combat_events(), "wall_impact") == 0,
		"未触墙时不发送撞墙音效"
	)

func _check_spider_web_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("spider_web")
	_check(module != null and module.display_name == "蜘蛛网", "蜘蛛网由注册表自动发现并使用独立公开名称")
	for key in ["web_damage", "web_collision_half_width"]:
		_check(module.setting_specs().has(key), "蜘蛛网参数 %s 由自身 Schema 配置" % key)
	_check(not module.create_ability().automatic_activation_enabled(), "蜘蛛网只有撞墙被动，不运行自动冷却技能")

	var simulation := BattleSimulationScript.new(20261212, "spider_web", "laser")
	simulation.take_combat_events()
	simulation.left.pos = Vector2(simulation.left.radius - 2.0, 320.0)
	simulation.left.velocity = Vector2(-220.0, 0.0)
	simulation._resolve_wall(simulation.left)
	var lines: Array[BallEntity] = simulation.entity_list(0, "spider_web_line")
	_check(lines.size() == 1, "蜘蛛网每次真实撞墙生成一根蛛丝")
	_check(int(simulation.stats["abilities"]["spider_web"]) == 1, "撞墙结网计入蜘蛛网专属能力触发")
	_check(int(simulation.stats.get("web_lines_created", 0)) == 1, "撞墙结网写入独立统计")
	var wall_events := simulation.take_combat_events()
	_check(_count_combat_events(wall_events, "wall_impact") == 1, "结网时保留通用撞墙音效")
	_check(_count_combat_events(wall_events, "web_attach") == 1, "结网时额外播放蛛丝绷紧音效")
	if not lines.is_empty():
		var line: BallEntity = lines[0]
		_check(line.remaining < 0.0 and not line.removed, "蛛丝没有持续时间并永久留在本局")
		_check(line.is_absorbable() and line.can_be_captured(), "墙锚蛛丝通过通用契约允许黑洞捕获与吞噬")
		_check(Vector2(line.call("anchor_position")).is_equal_approx(Vector2(0.0, 320.0)), "蛛丝墙锚固定在真实碰撞点")
		simulation.left.pos = Vector2(520.0, 320.0)
		_check(Vector2(line.call("strand_end", simulation.battle_context)).is_equal_approx(simulation.left.pos), "蛛丝另一端持续跟随蜘蛛网本体")
		simulation.right.pos = Vector2(270.0, 320.0)
		var initial_hp := simulation.right.hp
		line.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(is_equal_approx(simulation.right.hp, initial_hp - 1.0), "敌球首次触碰单根蛛丝只扣 1 点默认伤害")
		_check(bool(line.call("is_opponent_touching")) and int(line.call("trigger_count")) == 1, "蛛丝记住敌球仍处于线内")
		line.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(is_equal_approx(simulation.right.hp, initial_hp - 1.0), "敌球停在线上时同一根蛛丝不会连续扣血")
		simulation.right.pos = Vector2(270.0, 390.0)
		line.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(not bool(line.call("is_opponent_touching")), "敌球完全穿过并离开蛛丝后解除单线门控")
		simulation.right.pos = Vector2(270.0, 320.0)
		line.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(is_equal_approx(simulation.right.hp, initial_hp - 2.0), "敌球离开后再次碰到同一蛛丝可以再次触发一次")
		_check(_count_combat_events(simulation.take_combat_events(), "web_trigger") == 2, "两次独立越线各播放一次蛛丝触发音效")

	var capture_simulation := BattleSimulationScript.new(20261224, "black_hole", "spider_web")
	capture_simulation.left.pos = Vector2(320.0, 320.0)
	capture_simulation.right.pos = Vector2(capture_simulation.right.radius - 2.0, 320.0)
	capture_simulation.right.velocity = Vector2(-220.0, 0.0)
	capture_simulation._resolve_wall(capture_simulation.right)
	var capturable_lines: Array[BallEntity] = capture_simulation.entity_list(1, "spider_web_line")
	_check(capturable_lines.size() == 1, "黑洞反制测试生成一根敌方墙锚蛛丝")
	if not capturable_lines.is_empty():
		var capturable_line: BallEntity = capturable_lines[0]
		var native_line_color := capturable_line.absorption_visual_color()
		var initial_attraction_position := capturable_line.attraction_position()
		var initial_distance := initial_attraction_position.distance_to(capture_simulation.left.pos)
		capture_simulation.left_ability.activate(
			capture_simulation.battle_context,
			capture_simulation.left,
			capture_simulation.right,
			0
		)
		capture_simulation.left_ability.on_step(
			capture_simulation.battle_context,
			capture_simulation.left,
			capture_simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
		_check(
			capturable_line.is_captured()
				and not capturable_line.removed
				and int(capture_simulation.stats.get("objects_captured", 0)) == 1,
			"黑洞在通用捕获半径内夺走蛛丝但不会让它瞬间消失"
		)
		_check(
			capturable_line.owner_side == 1
				and capturable_line.absorption_visual_color() == native_line_color,
			"被黑洞捕获的蛛丝保留蜘蛛网原阵营与原色"
		)
		_check(not capturable_line.can_transfer_ownership(), "墙锚蛛丝只支持捕获吞噬，不会意外接入心灵控制")
		_check(
			capturable_line.pos.distance_to(capture_simulation.left.pos) < initial_distance,
			"蛛丝脱离墙锚和蜘蛛网本体后立即进入黑洞收缩轨道"
		)
		var black_hole_hp_before := capture_simulation.left.hp
		var trigger_count_before := int(capturable_line.call("trigger_count"))
		capturable_line.pos = capture_simulation.left.pos
		capturable_line.process_step(capture_simulation.battle_context, 0.17)
		_check(
			is_equal_approx(capture_simulation.left.hp, black_hole_hp_before)
				and int(capturable_line.call("trigger_count")) == trigger_count_before,
			"被捕获蛛丝立即禁用越线伤害，即使视觉扫过黑洞本体也不扣血"
		)
		_check(
			float(capturable_line.call("capture_fold_progress")) > 0.45,
			"被捕获蛛丝拥有连续折叠收束动画而不是整根瞬间消失"
		)
		for _frame in range(360):
			capture_simulation.left_ability.before_motion(
				capture_simulation.battle_context,
				capture_simulation.left,
				capture_simulation.right,
				0,
				BattleSimulation.FIXED_STEP
			)
			capture_simulation.left_ability.on_step(
				capture_simulation.battle_context,
				capture_simulation.left,
				capture_simulation.right,
				0,
				BattleSimulation.FIXED_STEP
			)
			if capturable_line.removed:
				break
			capturable_line.process_step(
				capture_simulation.battle_context,
				BattleSimulation.FIXED_STEP
			)
		_check(
			capturable_line.removed
				and int(capture_simulation.stats.get("objects_absorbed", 0)) == 1,
			"蛛丝沿轨道逐步靠近后最终进入事件视界并被吞噬"
		)
		var web_absorption_effects := capture_simulation.entity_list(0, "absorption_vfx")
		_check(web_absorption_effects.size() == 1, "蛛丝完全吞噬后生成通用压缩消失效果")
		if not web_absorption_effects.is_empty():
			_check(
				Color(web_absorption_effects[0].get("_color")) == native_line_color,
				"蛛丝吞噬特效继续使用原本的蛛丝颜色"
			)

	var clone_simulation := BattleSimulationScript.new(20261222, "spider_web", "splitter")
	clone_simulation.left.pos = Vector2(clone_simulation.left.radius - 2.0, 320.0)
	clone_simulation.left.velocity = Vector2(-220.0, 0.0)
	clone_simulation._resolve_wall(clone_simulation.left)
	clone_simulation.right_ability.activate(
		clone_simulation.battle_context,
		clone_simulation.right,
		clone_simulation.left,
		1
	)
	var clone_lines: Array[BallEntity] = clone_simulation.entity_list(0, "spider_web_line")
	var web_target_clones: Array[BallEntity] = clone_simulation.entity_list(1, "splitter_clone")
	_check(not clone_lines.is_empty() and not web_target_clones.is_empty(), "蛛丝附属物测试生成永久线与敌方分身")
	if not clone_lines.is_empty() and not web_target_clones.is_empty():
		var clone_line: BallEntity = clone_lines[0]
		var target_clone: BallEntity = web_target_clones[0]
		for clone_index in range(1, web_target_clones.size()):
			web_target_clones[clone_index].pos = Vector2(620.0, 80.0)
		clone_simulation.right.pos = Vector2(620.0, 620.0)
		clone_simulation.left.pos = Vector2(520.0, 220.0)
		target_clone.pos = Vector2(300.0, 320.0)
		target_clone.velocity = Vector2.ZERO
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		var clone_hp_before_sweep := float(target_clone.get("hp"))
		clone_simulation.left.pos = Vector2(520.0, 420.0)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(
			is_equal_approx(float(target_clone.get("hp")), clone_hp_before_sweep - 1.0),
			"分身自身不动时，蜘蛛网移动带动蛛丝横扫仍会对分身造成伤害"
		)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(
			is_equal_approx(float(target_clone.get("hp")), clone_hp_before_sweep - 1.0),
			"移动蛛丝完成一次横扫后不会在未重新穿过时连续伤害同一分身"
		)
		clone_simulation.left.pos = Vector2(520.0, 220.0)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(
			is_equal_approx(float(target_clone.get("hp")), clone_hp_before_sweep - 2.0),
			"蛛丝完全离开后反向再次扫过同一分身可重新触发伤害"
		)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		target_clone.pos = Vector2(300.0, 500.0)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		clone_simulation.left.pos = Vector2(520.0, 320.0)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		target_clone.pos = Vector2(300.0, 390.0)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		target_clone.pos = Vector2(300.0, 250.0)
		clone_line.process_step(clone_simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(
			is_equal_approx(float(target_clone.get("hp")), clone_hp_before_sweep - 3.0),
			"分身主动穿过静止蛛丝时也只触发一次伤害"
		)
		_check(
			int(clone_simulation.stats.get("web_entity_triggers", 0)) == 3,
			"蛛丝命中可受击附属物进入独立统计"
		)

	BallRegistry.configure_settings({
		"plant": {
			"growth_delay": 0.1,
			"sunflower_growth_weight": 1.0,
			"fire_pea_growth_weight": 0.0,
			"ice_pea_growth_weight": 0.0,
			"gatling_pea_growth_weight": 0.0,
		}
	})
	var plant_simulation := BattleSimulationScript.new(20261223, "spider_web", "plant")
	plant_simulation.right_ability.activate(
		plant_simulation.battle_context,
		plant_simulation.right,
		plant_simulation.left,
		1
	)
	var web_target_plants: Array[BallEntity] = plant_simulation.entity_list(1, "plant_growth")
	_check(not web_target_plants.is_empty(), "蛛丝植物测试生成敌方植物")
	if not web_target_plants.is_empty():
		var target_plant: BallEntity = web_target_plants[0]
		target_plant.process_step(plant_simulation.battle_context, 0.11)
		_check(target_plant.can_receive_attack(0), "成熟植物通过通用契约允许蛛丝伤害")
		plant_simulation.left.pos = Vector2(plant_simulation.left.radius - 2.0, 320.0)
		plant_simulation.left.velocity = Vector2(-220.0, 0.0)
		plant_simulation._resolve_wall(plant_simulation.left)
		var plant_lines: Array[BallEntity] = plant_simulation.entity_list(0, "spider_web_line")
		if not plant_lines.is_empty():
			var plant_line: BallEntity = plant_lines[0]
			plant_simulation.right.pos = Vector2(620.0, 620.0)
			plant_simulation.left.pos = Vector2(520.0, 220.0)
			target_plant.pos = Vector2(300.0, 320.0)
			plant_line.process_step(plant_simulation.battle_context, BattleSimulation.FIXED_STEP)
			var plant_hp_before_sweep := float(target_plant.get("hp"))
			plant_simulation.left.pos = Vector2(520.0, 420.0)
			plant_line.process_step(plant_simulation.battle_context, BattleSimulation.FIXED_STEP)
			_check(
				is_equal_approx(float(target_plant.get("hp")), plant_hp_before_sweep - 1.0),
				"固定不动的成熟植物被移动蛛丝扫过时正确扣血"
			)
	BallRegistry.configure_settings({})

	var deterministic_a := BattleSimulationScript.new(20261213, "spider_web", "replicator")
	var deterministic_b := BattleSimulationScript.new(20261213, "spider_web", "replicator")
	for _frame in range(900):
		deterministic_a.step(BattleSimulation.FIXED_STEP)
		deterministic_b.step(BattleSimulation.FIXED_STEP)
	_check(deterministic_a.snapshot() == deterministic_b.snapshot(), "蜘蛛网相同种子下的撞墙、结网与越线伤害可完全重放")
	_check(
		deterministic_a.count_entities(0, "spider_web_line")
			== deterministic_b.count_entities(0, "spider_web_line"),
		"蜘蛛网确定性重放保留相同永久蛛丝数量"
	)

	BallRegistry.configure_settings({"spider_web": {"web_damage": 4.5, "web_collision_half_width": 7.0}})
	var configured := BattleSimulationScript.new(20261214, "spider_web", "laser")
	configured.left.pos = Vector2(configured.left.radius - 2.0, 280.0)
	configured.left.velocity = Vector2(-180.0, 0.0)
	configured._resolve_wall(configured.left)
	var configured_lines: Array[BallEntity] = configured.entity_list(0, "spider_web_line")
	if not configured_lines.is_empty():
		configured.left.pos = Vector2(520.0, 280.0)
		configured.right.pos = Vector2(250.0, 280.0)
		var configured_hp := configured.right.hp
		configured_lines[0].process_step(configured.battle_context, BattleSimulation.FIXED_STEP)
		_check(is_equal_approx(configured.right.hp, configured_hp - 4.5), "蛛丝伤害使用蜘蛛网自己的持久化配置")
		_check(is_equal_approx(configured_lines[0].radius, 7.0), "蛛丝判定半宽使用蜘蛛网自己的持久化配置")
	BallRegistry.configure_settings({})

func _check_sniper_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("sniper")
	_check(module != null and module.display_name == "狙击球", "狙击球由注册表自动发现")
	_check(is_equal_approx(module.cooldown, 4.0), "狙击球默认每 4 秒开始一次瞄准")
	_check(is_equal_approx(module.settingf("muzzle_distance_multiplier"), 3.4), "狙击枪默认枪口距离缩短为 3.4 倍本体半径")
	_check(module.sound_kind == "sniper_aim", "狙击球能力触发音只绑定缩圈瞄准事件")
	for key in [
		"aim_duration",
		"bullet_damage",
		"bullet_speed",
		"bullet_radius",
		"bullet_lifetime",
		"muzzle_distance_multiplier",
		"scatter_count",
		"scatter_damage",
		"scatter_speed",
		"scatter_radius",
		"scatter_spread_degrees",
		"scatter_lifetime",
	]:
		_check(module.setting_specs().has(key), "狙击球参数 %s 由自身 Schema 配置" % key)
	var spread_spec: Dictionary = module.setting_specs()["scatter_spread_degrees"]
	_check(is_equal_approx(float(spread_spec["max"]), 360.0), "狙击球散弹扇面允许配置为完整 360°")

	var simulation := BattleSimulationScript.new(20261216, "sniper", "laser")
	_check(is_equal_approx(simulation.left.ability_timer, 4.0), "狙击球开局完整等待 4 秒后才开始首次瞄准")
	simulation.left.pos = Vector2(100.0, 320.0)
	simulation.right.pos = Vector2(540.0, 320.0)
	simulation.left.velocity = Vector2.ZERO
	simulation.right.velocity = Vector2.ZERO
	var first_blocker := TestDamageableEntity.new(1, Vector2(250.0, 320.0), 8.0)
	first_blocker.hp = 10.0
	var second_blocker := TestDamageableEntity.new(1, Vector2(360.0, 320.0), 9.0)
	second_blocker.hp = 15.0
	simulation.add_entity(first_blocker)
	simulation.add_entity(second_blocker)
	var ability: BallAbility = simulation.left_ability
	ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	_check(bool(ability.call("is_aiming")), "狙击球先进入 1 秒瞄准而不是瞬发子弹")
	_check(simulation.count_entities(0, "sniper_aim_vfx") == 1, "瞄准时生成独立缩圈与虚线实体")
	_check(int(simulation.stats.get("sniper_aims", 0)) == 1, "每次成功瞄准写入狙击球统计")
	ability.on_step(simulation.battle_context, simulation.left, simulation.right, 0, 0.5)
	var mid_aim_progress := float(ability.call("aim_progress"))
	_check(mid_aim_progress > 0.45 and mid_aim_progress < 0.55, "瞄准进度按配置时间连续推进")
	_check(simulation.count_entities(0, "sniper_round") == 0, "瞄准完成前不会提前发射")
	ability.on_step(simulation.battle_context, simulation.left, simulation.right, 0, 0.51)
	var rounds: Array[BallEntity] = simulation.entity_list(0, "sniper_round")
	_check(not bool(ability.call("is_aiming")) and rounds.size() == 1, "瞄准满 1 秒后发射一枚高速狙击弹")
	_check(int(ability.call("shots_fired")) == 1, "狙击球自身记录真实开火次数")
	_check(int(simulation.stats.get("sniper_rounds_fired", 0)) == 1, "狙击弹发射进入独立统计")
	var fire_events := simulation.take_combat_events()
	_check(_count_combat_events(fire_events, "sniper_fire") == 1, "狙击弹出膛时发送独立枪声音效")
	if not rounds.is_empty():
		var round: BallEntity = rounds[0]
		var expected_muzzle_distance := (
			simulation.left.radius * module.settingf("muzzle_distance_multiplier")
			+ module.settingf("bullet_radius")
		)
		_check(
			is_equal_approx(round.pos.distance_to(simulation.left.pos), expected_muzzle_distance),
			"狙击弹从外移后的真实枪口位置生成"
		)
		_check(round.is_absorbable() and round.can_be_captured(), "狙击弹可被黑洞按通用投射物契约捕获")
		_check(not round.can_transfer_ownership(), "狙击弹不会被尤里球控制或改变阵营")
		round.process_step(simulation.battle_context, 0.31)
		_check(is_zero_approx(first_blocker.hp) and is_zero_approx(second_blocker.hp), "狙击弹按轨迹依次打穿多个可受击附属物")
		_check(int(round.call("penetration_count")) == 2, "同一枚狙击弹对每个穿透障碍只结算一次")
		_check(is_equal_approx(simulation.right.hp, 60.0), "障碍物实际损失 10 与 15 血后，剩余 40 点弹伤命中主球")
		_check(round.removed, "狙击弹命中敌方主球后结束而不继续穿墙")
		var hit_events := simulation.take_combat_events()
		_check(_count_combat_events(hit_events, "sniper_pierce") == 2, "每个被打穿附属物各播放一次穿透音效")
		_check(_count_combat_events(hit_events, "sniper_hit") == 1, "剩余弹伤命中主球时播放一次重击音效")
		_check(int(simulation.stats.get("sniper_penetrations", 0)) == 2, "穿透两个障碍物进入独立统计")
		_check(int(simulation.stats.get("sniper_main_hits", 0)) == 1, "命中敌方主球进入独立统计")

	var miss := BattleSimulationScript.new(20261217, "sniper", "laser")
	miss.left.pos = Vector2(100.0, 150.0)
	miss.right.pos = Vector2(500.0, 150.0)
	miss.left.velocity = Vector2.ZERO
	miss.right.velocity = Vector2.ZERO
	miss.left_ability.activate(miss.battle_context, miss.left, miss.right, 0)
	miss.left_ability.on_step(miss.battle_context, miss.left, miss.right, 0, 1.0)
	var missing_rounds: Array[BallEntity] = miss.entity_list(0, "sniper_round")
	if not missing_rounds.is_empty():
		var missing_round: BallEntity = missing_rounds[0]
		miss.right.pos = Vector2(500.0, 500.0)
		missing_round.process_step(miss.battle_context, 0.5)
		var scatter: Array[BallEntity] = miss.entity_list(0, "projectile")
		_check(missing_round.removed, "狙击弹没有命中主球时在墙面终止主弹")
		_check(scatter.size() == module.settingi("scatter_count"), "狙击弹撞墙后分裂为可配置数量的小球形散弹")
		var total_scatter_damage := 0.0
		var all_scatter_inward := true
		for pellet: BallEntity in scatter:
			total_scatter_damage += float(pellet.get("damage_amount"))
			all_scatter_inward = all_scatter_inward and pellet.velocity.x < 0.0
			_check(is_equal_approx(pellet.radius, module.settingf("scatter_radius")), "每颗散弹使用狙击球自己的小球半径配置")
		_check(all_scatter_inward, "右墙分裂出的散弹扇面全部朝竞技场内侧飞行")
		_check(total_scatter_damage <= module.settingf("bullet_damage") + 0.001, "散弹总伤害不会超过撞墙时主弹的剩余伤害")
		var wall_events := miss.take_combat_events()
		_check(_count_combat_events(wall_events, "sniper_wall_split") == 1, "狙击弹撞墙分裂时发送独立散射音效")
		_check(int(miss.stats.get("sniper_wall_splits", 0)) == 1, "撞墙分裂进入独立统计")
		_check(int(miss.stats.get("sniper_scatter_spawned", 0)) == module.settingi("scatter_count"), "实际生成散弹数进入独立统计")

	BallRegistry.configure_settings({
		"sniper": {
			"aim_duration": 0.1,
			"scatter_count": 8,
			"scatter_spread_degrees": 360.0,
		}
	})
	var radial_module: BallModule = BallRegistry.get_module("sniper")
	_check(is_equal_approx(radial_module.settingf("scatter_spread_degrees"), 360.0), "360° 散射配置不会被球模块截断")
	var radial := BattleSimulationScript.new(20261221, "sniper", "laser")
	radial.left.pos = Vector2(100.0, 150.0)
	radial.right.pos = Vector2(500.0, 150.0)
	radial.left.velocity = Vector2.ZERO
	radial.right.velocity = Vector2.ZERO
	radial.left_ability.activate(radial.battle_context, radial.left, radial.right, 0)
	radial.left_ability.on_step(radial.battle_context, radial.left, radial.right, 0, 0.1)
	var radial_rounds: Array[BallEntity] = radial.entity_list(0, "sniper_round")
	if not radial_rounds.is_empty():
		radial.right.pos = Vector2(500.0, 500.0)
		radial_rounds[0].process_step(radial.battle_context, 0.5)
		var radial_scatter: Array[BallEntity] = radial.entity_list(0, "projectile")
		_check(radial_scatter.size() == 8, "360° 撞墙散射生成完整配置数量的小球")
		var direction_keys := {}
		var has_positive_x := false
		var has_negative_x := false
		var has_positive_y := false
		var has_negative_y := false
		for pellet: BallEntity in radial_scatter:
			var pellet_direction := pellet.velocity.normalized()
			direction_keys["%.4f,%.4f" % [pellet_direction.x, pellet_direction.y]] = true
			has_positive_x = has_positive_x or pellet_direction.x > 0.2
			has_negative_x = has_negative_x or pellet_direction.x < -0.2
			has_positive_y = has_positive_y or pellet_direction.y > 0.2
			has_negative_y = has_negative_y or pellet_direction.y < -0.2
		_check(direction_keys.size() == 8, "360° 散射首尾方向不重叠")
		_check(
			has_positive_x and has_negative_x and has_positive_y and has_negative_y,
			"360° 散射覆盖撞墙点四周而不是仍被限制在内侧扇面"
		)

	BallRegistry.configure_settings({
		"sniper": {
			"aim_duration": 0.2,
			"bullet_damage": 30.0,
			"bullet_speed": 2100.0,
			"bullet_radius": 6.0,
			"scatter_count": 5,
		}
	})
	var configured := BattleSimulationScript.new(20261218, "sniper", "laser")
	configured.left.pos = Vector2(100.0, 260.0)
	configured.right.pos = Vector2(500.0, 260.0)
	configured.left.velocity = Vector2.ZERO
	configured.right.velocity = Vector2.ZERO
	var absorbing_blocker := TestDamageableEntity.new(1, Vector2(250.0, 260.0), 10.0)
	absorbing_blocker.hp = 30.0
	configured.add_entity(absorbing_blocker)
	configured.left_ability.activate(configured.battle_context, configured.left, configured.right, 0)
	configured.left_ability.on_step(configured.battle_context, configured.left, configured.right, 0, 0.2)
	var configured_rounds: Array[BallEntity] = configured.entity_list(0, "sniper_round")
	if not configured_rounds.is_empty():
		var configured_round: BallEntity = configured_rounds[0]
		_check(is_equal_approx(float(configured_round.call("remaining_damage")), 30.0), "狙击弹初始伤害使用持久化配置")
		_check(is_equal_approx(configured_round.velocity.length(), 2100.0), "狙击弹高速飞行速度使用持久化配置")
		_check(is_equal_approx(configured_round.radius, 6.0), "狙击弹判定粗细使用持久化配置")
		configured.right.pos = Vector2(500.0, 500.0)
		configured_round.process_step(configured.battle_context, 0.1)
		_check(configured_round.removed and is_zero_approx(absorbing_blocker.hp), "障碍物血量等于剩余弹伤时把狙击弹完全耗尽")
		_check(configured.count_entities(0, "projectile") == 0, "弹伤在到墙前归零时不会错误生成散弹")
		_check(int(configured.stats.get("sniper_rounds_depleted", 0)) == 1, "障碍耗尽狙击弹进入独立统计")
	BallRegistry.configure_settings({})

	var deterministic_a := BattleSimulationScript.new(20261219, "sniper", "plant")
	var deterministic_b := BattleSimulationScript.new(20261219, "sniper", "plant")
	for _frame in range(900):
		deterministic_a.step(BattleSimulation.FIXED_STEP)
		deterministic_b.step(BattleSimulation.FIXED_STEP)
		if deterministic_a.finished and deterministic_b.finished:
			break
	_check(deterministic_a.snapshot() == deterministic_b.snapshot(), "狙击球的瞄准、穿透与散射在相同种子下可完全重放")

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
	_check(
		_count_combat_events(neutral_contact.take_combat_events(), "body_impact") == 1,
		"两个大球接触时由碰撞结算立即发送撞击音效事件"
	)

	var damaging_contact := BattleSimulationScript.new(20260829, "vampire", "laser")
	_prepare_contact(damaging_contact)
	var vampire_hp := damaging_contact.left.hp
	var laser_hp := damaging_contact.right.hp
	damaging_contact._resolve_collision()
	_check(is_equal_approx(damaging_contact.left.hp, vampire_hp), "没有碰撞能力的一侧不会反向造成伤害")
	_check(is_equal_approx(damaging_contact.right.hp, laser_hp), "吸血鬼碰撞本身不再造成瞬时伤害")
	_check(bool(damaging_contact.left_ability.call("is_latching")), "吸血鬼通过自身碰撞能力启动延时吸附")

func _check_vampire_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("vampire")
	_check(is_equal_approx(module.cooldown, 6.0), "吸血鬼远程抽血默认每 6 秒发动一次")
	for key in [
		"remote_drain_damage",
		"remote_heal_ratio",
		"remote_strand_count",
		"remote_travel_duration",
		"remote_strand_stagger",
		"remote_suction_duration",
		"latch_duration",
		"latch_drain_interval",
		"latch_drain_damage",
		"latch_heal_ratio",
		"latch_gap",
		"latch_release_speed",
		"latch_release_duration",
	]:
		_check(module.setting_specs().has(key), "吸血鬼参数 %s 由自身 Schema 配置" % key)
	for removed_key in [
		"burst_radius",
		"burst_damage",
		"burst_heal",
		"body_impact_damage",
		"impact_lifesteal_ratio",
	]:
		_check(not module.setting_specs().has(removed_key), "吸血鬼已删除旧血爆/碰撞直伤参数 %s" % removed_key)

	var remote_simulation := BattleSimulationScript.new(20261005, "vampire", "laser")
	var remote_ability: BallAbility = remote_simulation.left_ability
	_check(is_equal_approx(remote_simulation.left.ability_timer, 6.0), "吸血鬼首次远程抽血等待完整 6 秒")
	remote_simulation.left.hp = 98.0
	var remote_victim_hp := remote_simulation.right.hp
	remote_ability.activate(
		remote_simulation.battle_context,
		remote_simulation.left,
		remote_simulation.right,
		0
	)
	_check(is_equal_approx(remote_simulation.right.hp, remote_victim_hp), "远程血线生成时不会瞬时扣血")
	var remote_drains: Array[BallEntity] = remote_simulation.entity_list(0, "vampire_remote_drain")
	_check(remote_drains.size() == 1, "远程抽血生成吸血鬼私有的持续血线实体")
	if not remote_drains.is_empty():
		var remote_entity: BallEntity = remote_drains[0]
		_check(remote_entity.draws_above_balls(), "远程血线绘制在球体上方并清晰连接双方")
		_check(not remote_entity.is_absorbable(), "远程血线是无碰撞技能表现而不是可吞噬投射物")
		var attach_time: float = (
			module.settingf("remote_travel_duration")
			+ float(module.settingi("remote_strand_count") - 1) * module.settingf("remote_strand_stagger")
		)
		var frames_before_attach := int(floor((attach_time - 0.03) / BattleSimulation.FIXED_STEP))
		for _frame in range(frames_before_attach):
			remote_entity.process_lifetime(BattleSimulation.FIXED_STEP)
			if not remote_entity.removed:
				remote_entity.process_step(remote_simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(is_equal_approx(remote_simulation.right.hp, remote_victim_hp), "血线尚未全部附着前不会提前结算远程抽血")
		for _frame in range(5):
			remote_entity.process_lifetime(BattleSimulation.FIXED_STEP)
			if not remote_entity.removed:
				remote_entity.process_step(remote_simulation.battle_context, BattleSimulation.FIXED_STEP)
		_check(is_equal_approx(
			remote_victim_hp - remote_simulation.right.hp,
			module.settingf("remote_drain_damage")
		), "全部血线附着到吸血鬼后才结算一次远程抽血伤害")
		_check(is_equal_approx(
			remote_simulation.left.hp,
			98.0 + module.settingf("remote_drain_damage") * module.settingf("remote_heal_ratio")
		), "远程血线吸入口器后可按实际伤害突破本体生命上限")
		_check(int(remote_simulation.stats.get("vampire_remote_drains", 0)) == 1, "远程血线只结算一次抽血统计")

	var latch_simulation := BattleSimulationScript.new(20261006, "vampire", "laser")
	var latch_ability: BallAbility = latch_simulation.left_ability
	latch_simulation.left.pos = Vector2(280.0, 320.0)
	latch_simulation.right.pos = Vector2(335.0, 320.0)
	latch_simulation.left.velocity = Vector2(96.0, 18.0)
	var opponent_velocity_before_latch := Vector2(-145.0, 36.0)
	latch_simulation.right.velocity = opponent_velocity_before_latch
	latch_simulation.left.hp = 60.0
	var latch_victim_hp := latch_simulation.right.hp
	latch_ability.after_contact(
		latch_simulation.battle_context,
		latch_simulation.left,
		latch_simulation.right,
		0.0
	)
	_check(bool(latch_ability.call("is_latching")), "吸血鬼碰撞后立即进入 2 秒吸附状态")
	_check(latch_simulation.has_status(latch_simulation.left, "vampire_latch_invulnerability"), "贴身吸血开始时吸血鬼立即获得无敌状态")
	_check(latch_simulation.has_status(latch_simulation.right, "vampire_latch_drag"), "被吸附球获得通用高优先级强制移动状态")
	var hp_before_blocked_damage: float = latch_simulation.left.hp
	var blocked_damage: float = latch_simulation.damage(
		latch_simulation.left,
		40.0,
		latch_simulation.right.accent,
		latch_simulation.right
	)
	_check(is_zero_approx(blocked_damage), "贴身吸血期间所有本体伤害均被无敌状态拦截")
	_check(is_equal_approx(latch_simulation.left.hp, hp_before_blocked_damage), "无敌拦截不会改变吸血鬼当前生命")
	_check(is_equal_approx(
		float(latch_ability.call("latch_remaining")),
		module.settingf("latch_duration")
	), "碰撞吸附持续时间使用默认 2 秒配置")
	_check(latch_simulation.count_entities(0, "vampire_latch_tether") == 1, "吸附期间生成持续可见的血液连接")
	_check(latch_simulation.right.velocity.is_equal_approx(latch_simulation.left.velocity), "被吸附球立即跟随吸血鬼运动")
	_check(is_equal_approx(
		latch_simulation.left.pos.distance_to(latch_simulation.right.pos),
		latch_simulation.left.radius + latch_simulation.right.radius + module.settingf("latch_gap")
	), "被吸附球保持在吸血鬼口器前方的配置距离")
	for _frame in range(35):
		latch_ability.on_step(
			latch_simulation.battle_context,
			latch_simulation.left,
			latch_simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
	_check(is_equal_approx(latch_simulation.right.hp, latch_victim_hp), "吸附未满 0.6 秒时不会提前抽血")
	for _frame in range(2):
		latch_ability.on_step(
			latch_simulation.battle_context,
			latch_simulation.left,
			latch_simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
	_check(is_equal_approx(
		latch_victim_hp - latch_simulation.right.hp,
		module.settingf("latch_drain_damage")
	), "吸附满 0.6 秒后恰好结算第一次周期抽血")
	var remaining_before_repeat_contact := float(latch_ability.call("latch_remaining"))
	latch_ability.after_contact(
		latch_simulation.battle_context,
		latch_simulation.left,
		latch_simulation.right,
		0.0
	)
	_check(is_equal_approx(
		float(latch_ability.call("latch_remaining")),
		remaining_before_repeat_contact
	), "吸附期间的重复碰撞不会把 2 秒计时无限刷新")
	for _frame in range(120):
		if not bool(latch_ability.call("is_latching")):
			break
		latch_ability.on_step(
			latch_simulation.battle_context,
			latch_simulation.left,
			latch_simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
	_check(not bool(latch_ability.call("is_latching")), "吸血鬼吸附在 2 秒后准时解除")
	_check(not latch_simulation.has_status(latch_simulation.right, "vampire_latch_drag"), "吸附结束后立即移除强制移动状态")
	_check(int(latch_simulation.stats.get("vampire_latch_drains", 0)) == 3, "2 秒吸附按 0.6 秒间隔恰好抽血 3 次")
	_check(is_equal_approx(
		latch_victim_hp - latch_simulation.right.hp,
		module.settingf("latch_drain_damage") * 3.0
	), "三次吸附抽血均使用独立可配置伤害")
	_check(is_equal_approx(
		latch_simulation.left.hp,
		60.0 + module.settingf("latch_drain_damage") * module.settingf("latch_heal_ratio") * 3.0
	), "三次吸附抽血均按实际伤害回复吸血鬼")
	_check(not latch_simulation.has_status(latch_simulation.left, "vampire_latch_invulnerability"), "贴身吸血结束后立即移除无敌状态")
	var release_direction: Vector2 = (latch_simulation.right.pos - latch_simulation.left.pos).normalized()
	_check(
		is_equal_approx(latch_simulation.left.velocity.length(), module.settingf("latch_release_speed"))
			and latch_simulation.left.velocity.dot(release_direction) < 0.0,
		"吸完血后吸血鬼按配置速度向后弹开"
	)
	_check(
		is_equal_approx(latch_simulation.right.velocity.length(), module.settingf("latch_release_speed"))
			and latch_simulation.right.velocity.dot(release_direction) > 0.0,
		"吸完血后对方按配置速度向前弹开"
	)
	_check(latch_simulation.has_status(latch_simulation.left, "vampire_latch_release:"), "吸血鬼弹开速度在配置时段内不被基础移速截断")
	_check(latch_simulation.has_status(latch_simulation.right, "vampire_latch_release:"), "对方弹开速度在配置时段内不被基础移速截断")
	_check(latch_simulation.count_entities(0, "vampire_latch_tether") == 0, "吸附结束后同步移除血液连接实体")
	latch_simulation.left.pos = Vector2(300.0, 360.0)
	latch_simulation.right.pos = Vector2(300.0, 180.0)
	latch_ability.before_motion(
		latch_simulation.battle_context,
		latch_simulation.left,
		latch_simulation.right,
		0,
		0.0
	)
	var facing_direction: Vector2 = latch_ability.call("facing_direction")
	_check(facing_direction.dot(Vector2.UP) > 0.999, "吸血鬼口器方向始终更新为当前对手方向")

func _check_sonic_speed_growth() -> void:
	var module: BallModule = BallRegistry.get_module("sonic")
	_check(is_equal_approx(module.cooldown, 1.0), "音速球默认每 1 秒增长一次速度")
	_check(is_equal_approx(module.settingf("speed_growth_ratio"), 0.10), "音速球每次速度增长默认使用 10%")
	var simulation := BattleSimulationScript.new(20260916, "sonic", "laser")
	var ability: BallAbility = simulation.left_ability
	var base_contact_damage := module.settingf("body_impact_damage")
	_check(is_equal_approx(
		ability.speed_multiplier(simulation.battle_context, simulation.left, simulation.right, 0),
		1.0
	), "音速球开局保持初始速度倍率")
	_check(is_equal_approx(
		ability.contact_damage(simulation.battle_context, simulation.left, simulation.right),
		base_contact_damage
	), "音速球技能尚未发动时使用基础撞击伤害")
	for _frame in range(59):
		simulation.step(BattleSimulation.FIXED_STEP)
	_check(int(simulation.stats["abilities"]["sonic"]) == 0, "未满 1 秒时音速球不会提前加速")
	for _frame in range(2):
		simulation.step(BattleSimulation.FIXED_STEP)
	_check(int(simulation.stats["abilities"]["sonic"]) == 1, "满 1 秒后音速球恰好完成一次加速")
	_check(is_equal_approx(
		ability.speed_multiplier(simulation.battle_context, simulation.left, simulation.right, 0),
		1.10
	), "第一次加速把速度倍率乘以 1.10")
	_check(is_equal_approx(
		ability.contact_damage(simulation.battle_context, simulation.left, simulation.right),
		base_contact_damage * 1.10
	), "第一次加速后撞击伤害同步乘以 1.10")
	_check(is_equal_approx(
		simulation.left.velocity.length(),
		simulation.left.base_speed * 1.10
	), "音速球的真实移动速度同步增长到初速的 1.10 倍")
	for _frame in range(60):
		simulation.step(BattleSimulation.FIXED_STEP)
	_check(int(simulation.stats["abilities"]["sonic"]) == 2, "再经过 1 秒后音速球完成第二次加速")
	_check(is_equal_approx(
		ability.speed_multiplier(simulation.battle_context, simulation.left, simulation.right, 0),
		1.21
	), "连续加速按 10% 复利叠加")
	var expected_contact_damage := base_contact_damage * 1.21
	simulation.left.velocity = Vector2.RIGHT * simulation.left.base_speed * 4.0
	_check(is_equal_approx(
		ability.contact_damage(simulation.battle_context, simulation.left, simulation.right),
		expected_contact_damage
	), "外部瞬时加速不会改变音速球当前层数的撞击伤害")
	simulation.left.velocity = Vector2.RIGHT * simulation.left.base_speed * 0.2
	_check(is_equal_approx(
		ability.contact_damage(simulation.battle_context, simulation.left, simulation.right),
		expected_contact_damage
	), "碰撞、牵引或状态造成的瞬时减速不会改变音速球撞击伤害")
	var wave_simulation := BattleSimulationScript.new(20260917, "sonic", "laser")
	var wave_ability: BallAbility = wave_simulation.left_ability
	wave_ability.activate(
		wave_simulation.battle_context,
		wave_simulation.left,
		wave_simulation.right,
		0
	)
	_check(wave_simulation.impact_rings.size() == 1, "音速球提速时立即释放第一层音波")
	for expected_layers in range(2, 5):
		wave_ability.on_step(
			wave_simulation.battle_context,
			wave_simulation.left,
			wave_simulation.right,
			0,
			0.10
		)
		_check(
			wave_simulation.impact_rings.size() == expected_layers,
			"音速球音波按时序扩散到第 %d 层" % expected_layers
		)
	_check(wave_simulation.particles.is_empty(), "音速球提速改用纯音波扩散，不再喷射爆炸粒子")

func _check_combat_audio_contract() -> void:
	var audio = ProceduralAudioScript.new()
	audio.configure_samples(BallRegistry.audio_samples())
	for kind in ["impact", "body_impact", "wall_impact", "volley", "projectile_hit", "split", "clone_impact", "ram_impact", "blade_slash", "wind_cast", "wind_absorb", "psychic_pulse", "web_attach", "web_trigger", "sniper_aim", "sniper_fire", "sniper_pierce", "sniper_hit", "sniper_wall_split", "fighter_death", "garen_sword_hit", "garen_spin_whoosh"]:
		_check(audio.supports_event(kind), "程序音频支持 %s 战斗事件" % kind)
	_check(ProceduralAudioScript.GENERATOR_BUFFER_LENGTH <= 0.05, "程序音频缓存不超过 50 毫秒")
	_check(ProceduralAudioScript.AUDIO_PROCESS_PRIORITY > 0, "音频混音晚于战斗节点处理同帧事件")
	_check(audio.uses_direct_playback("wall_impact"), "撞墙声绕过持续生成器的预排队缓冲")
	_check(audio.uses_direct_playback("fighter_death"), "死亡声绕过持续生成器的预排队缓冲")
	_check(audio.uses_direct_playback("web_attach") and audio.uses_direct_playback("web_trigger"), "蛛丝结网和越线声绕过持续生成器缓冲")
	for sniper_kind in ["sniper_aim", "sniper_fire", "sniper_pierce", "sniper_hit", "sniper_wall_split"]:
		_check(audio.uses_direct_playback(sniper_kind), "狙击事件 %s 绕过持续生成器缓冲" % sniper_kind)
	_check(is_equal_approx(ProceduralAudioScript.OUTPUT_GAIN_DB, 15.0), "Hasagi 之外的战斗音频默认增加 15 dB 共享输出增益")
	_check(
		is_equal_approx(
			ProceduralAudioScript.output_volume_db(ProceduralAudioScript.PROCEDURAL_BASE_VOLUME_DB),
			8.0
		),
		"程序合成音由原 -7 dB 提升到 +8 dB"
	)
	_check(
		is_equal_approx(ProceduralAudioScript.output_volume_db(0.0), 15.0),
		"未单独修正的自定义采样默认增加 15 dB"
	)
	var impact_profile: Dictionary = audio.event_profile("body_impact")
	_check(float(impact_profile["attack"]) <= 0.001, "大球撞击使用 1 毫秒快速起音")
	_check(float(impact_profile["frequency"]) >= 200.0, "大球撞击主体包含可辨识的中频敲击")
	_check(float(impact_profile["transient"]) >= 0.5, "大球撞击包含清晰的宽频瞬态")
	var wall_profile: Dictionary = audio.event_profile("wall_impact", 0.3)
	_check(float(wall_profile["duration"]) >= 0.12, "撞墙使用较长衰减的闷响")
	_check(float(wall_profile["frequency"]) <= 120.0, "撞墙主体使用低频而非轻敲高频")
	_check(float(wall_profile["frequency"]) > float(wall_profile["frequency_end"]), "撞墙闷响频率向下衰减")
	_check(String(wall_profile["wave"]) == "sine", "撞墙使用圆润正弦波形")
	_check(float(wall_profile["attack"]) <= 0.0005, "撞墙闷响保持半毫秒内快速起音")
	_check(float(wall_profile["transient"]) < float(impact_profile["transient"]), "撞墙瞬态弱于两个大球互撞")
	_check(audio.has_sample_event("blade_slash"), "风剑球 Q 使用模块自带的国服 Hasagi 变声采样")
	_check(audio.sample_event_duration("blade_slash") >= 0.5, "国服 Hasagi 变声采样保留完整可辨识喊声")
	_check(is_equal_approx(audio.sample_event_gain_db("blade_slash"), -10.0), "Hasagi 在自身模块声明 -10 dB 单采样修正以抵消额外共享增益")
	_check(is_equal_approx(audio.sample_output_volume_db("blade_slash", 1.0), 5.0), "Hasagi 相对原音量只提升 5 dB")
	_check(not audio.has_sample_event("wind_cast"), "风剑球 W 不再注册任何台词语音采样")
	var wind_profile: Dictionary = audio.event_profile("wind_cast")
	_check(float(wind_profile["frequency_end"]) > float(wind_profile["frequency"]), "风障展开只使用无台词的上扬合成风声")
	var psychic_profile: Dictionary = audio.event_profile("psychic_pulse")
	_check(float(psychic_profile["frequency_end"]) > float(psychic_profile["frequency"]), "尤里球精神波使用上扬电子扫频")
	_check(float(psychic_profile["duration"]) >= 0.4, "尤里球精神波音效拥有可辨识的持续时间")
	var death_profile: Dictionary = audio.event_profile("fighter_death")
	_check(float(death_profile["duration"]) >= 0.6, "死亡音效有完整的碎裂与低频衰减时长")
	_check(float(death_profile["frequency_end"]) < float(death_profile["frequency"]) * 0.3, "死亡音效使用明显下坠的低频扫音")
	_check(float(death_profile["transient"]) >= 0.8, "死亡音效包含醒目的爆裂瞬态")
	var web_attach_profile: Dictionary = audio.event_profile("web_attach")
	var web_trigger_profile: Dictionary = audio.event_profile("web_trigger")
	_check(float(web_attach_profile["frequency_end"]) > float(web_attach_profile["frequency"]), "撞墙结网使用上扬的蛛丝绷紧音")
	_check(float(web_trigger_profile["frequency_end"]) < float(web_trigger_profile["frequency"]), "敌球越线使用快速下坠的粘连触发音")
	var sniper_aim_profile: Dictionary = audio.event_profile("sniper_aim")
	var sniper_fire_profile: Dictionary = audio.event_profile("sniper_fire")
	var sniper_wall_profile: Dictionary = audio.event_profile("sniper_wall_split")
	_check(float(sniper_aim_profile["frequency_end"]) > float(sniper_aim_profile["frequency"]), "狙击缩圈使用逐渐上扬的锁定音")
	_check(float(sniper_fire_profile["transient"]) >= 0.9 and float(sniper_fire_profile["attack"]) <= 0.0005, "狙击枪声具有无延迟的强瞬态")
	_check(float(sniper_wall_profile["frequency_end"]) > float(sniper_wall_profile["frequency"]), "撞墙散射使用向上炸开的分裂音")
	audio.free()

func _check_fighter_death_presentation() -> void:
	var simulation := BattleSimulationScript.new(20261210, "vampire", "wdc")
	simulation.death_effect_duration = 1.2
	simulation.take_combat_events()
	simulation.right.hp = 8.0
	var applied := simulation.damage(simulation.right, 20.0, simulation.left.accent, simulation.left)
	_check(is_equal_approx(applied, 8.0) and is_zero_approx(simulation.right.hp), "致死伤害结算到败方生命归零")
	_check(simulation.count_entities(1, "fighter_death_vfx") == 1, "败方死亡时生成一个通用高层死亡特效")
	var death_events := simulation.take_combat_events()
	_check(_count_combat_events(death_events, "fighter_death") == 1, "败方死亡时只触发一次专属死亡音效")
	var death_effects := simulation.entity_list(1, "fighter_death_vfx")
	_check(not death_effects.is_empty(), "死亡特效实体可通过通用标签查询")
	if not death_effects.is_empty():
		var death_effect: BallEntity = death_effects[0]
		var initial_progress := float(death_effect.call("animation_progress"))
		death_effect.process_lifetime(0.4)
		_check(float(death_effect.call("animation_progress")) > initial_progress, "死亡碎裂动画随生命周期连续展开")
		_check(not death_effect.is_absorbable() and not death_effect.can_receive_attack(0), "纯表现死亡实体不参与捕获或战斗")
	simulation.damage(simulation.right, 20.0, simulation.left.accent, simulation.left)
	_check(simulation.count_entities(1, "fighter_death_vfx") == 1, "重复命中已死亡本体不会重复生成死亡特效")
	_check(_count_combat_events(simulation.take_combat_events(), "fighter_death") == 0, "重复命中已死亡本体不会重复播放死亡音效")

func _check_wind_swordsman_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("wind_swordsman")
	_check(module.sound_kind == "wind_cast", "风剑球 W 的自动技能音只映射到无台词风声")
	for key in [
		"slash_damage",
		"slash_trigger_range",
		"slash_reach",
		"slash_half_width",
		"slash_cooldown",
		"slash_effect_duration",
		"crack_duration",
		"wall_duration",
		"max_walls",
		"wall_distance",
		"wall_curve_radius",
		"wall_arc_degrees",
		"wall_thickness",
		"wall_activation_lookahead",
		"skill_standstill_duration",
	]:
		_check(module.setting_specs().has(key), "风剑球参数 %s 由自身 Schema 配置" % key)

	var slash_simulation := BattleSimulationScript.new(20260918, "wind_swordsman", "replicator")
	slash_simulation.left.pos = Vector2(260.0, 320.0)
	slash_simulation.right.pos = Vector2(360.0, 320.0)
	slash_simulation.left.velocity = Vector2.ZERO
	slash_simulation.right.velocity = Vector2.ZERO
	var along_slash_entity := TestDamageableEntity.new(1, slash_simulation.left.pos + Vector2(62.0, 0.0), 5.0)
	var off_axis_entity := TestDamageableEntity.new(1, slash_simulation.right.pos + Vector2(0.0, 50.0), 5.0)
	slash_simulation.add_entity(along_slash_entity)
	slash_simulation.add_entity(off_axis_entity)
	var right_hp_before := slash_simulation.right.hp
	slash_simulation.take_combat_events()
	slash_simulation.left_ability.on_step(
		slash_simulation.battle_context,
		slash_simulation.left,
		slash_simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(
		right_hp_before - slash_simulation.right.hp,
		module.settingf("slash_damage")
	), "风剑球贴近对手时沿自身至目标方向自动斩击并造成配置伤害")
	_check(is_equal_approx(along_slash_entity.hp, 100.0 - module.settingf("slash_damage")), "斩击命中风剑球至敌球方向线段上的附属实体")
	_check(is_equal_approx(off_axis_entity.hp, 100.0), "斩击不会继续使用固定屏幕纵向命中")
	_check(int(slash_simulation.stats.get("wind_slashes", 0)) == 1, "贴身指向斩击拥有独立触发统计")
	var slash_effects: Array[BallEntity] = slash_simulation.entity_list(0, "wind_slash_vfx")
	_check(slash_effects.size() == 1, "贴身指向斩击生成球内私有梭形刀光实体")
	if not slash_effects.is_empty():
		_check(slash_effects[0].pos == slash_simulation.left.pos, "梭形刀光从风剑球本体位置起斩")
		_check(slash_effects[0].get("_direction").is_equal_approx(Vector2.RIGHT), "梭形刀光朝当前敌球方向延伸")
		_check(is_equal_approx(slash_effects[0].remaining, module.settingf("slash_effect_duration")), "刀痕按风剑球持久化参数延长显示")
	var ground_cracks: Array[BallEntity] = slash_simulation.entity_list(0, "wind_ground_crack")
	_check(ground_cracks.size() == 1, "指向斩击命中位置生成同方向地面裂痕实体")
	if not ground_cracks.is_empty():
		_check(is_equal_approx(ground_cracks[0].remaining, module.settingf("crack_duration")), "地面裂痕按风剑球配置短暂保留")
		_check(ground_cracks[0].get("_direction").is_equal_approx(Vector2.RIGHT), "地面沟槽沿风剑球至敌球方向破裂")
		_check(ground_cracks[0].pos.is_equal_approx(
			slash_simulation.left.pos + Vector2.RIGHT * module.settingf("slash_reach") * 0.5
		), "地面裂痕与刀光使用同一起点、终点和中心轴")
	_check(
		_count_combat_events(slash_simulation.take_combat_events(), "blade_slash") == 1,
		"贴身指向斩击发送原创高频刀锋音效事件"
	)
	var hp_after_first_slash := slash_simulation.right.hp
	slash_simulation.left_ability.on_step(
		slash_simulation.battle_context,
		slash_simulation.left,
		slash_simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(slash_simulation.right.hp, hp_after_first_slash), "贴身指向斩击遵守自身独立冷却")
	_check(is_zero_approx(
		slash_simulation.left_ability.contact_damage(
			slash_simulation.battle_context,
			slash_simulation.left,
			slash_simulation.right
		)
	), "风剑球普通本体碰撞保持零伤害")

	var standstill_simulation := BattleSimulationScript.new(20261003, "wind_swordsman", "laser")
	standstill_simulation.left.pos = Vector2(260.0, 320.0)
	standstill_simulation.right.pos = Vector2(350.0, 320.0)
	var movement_before_cast := Vector2(180.0, 45.0)
	standstill_simulation.left.velocity = movement_before_cast
	standstill_simulation.left_ability.on_step(
		standstill_simulation.battle_context,
		standstill_simulation.left,
		standstill_simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	var standstill_duration := module.settingf("skill_standstill_duration")
	_check(is_equal_approx(standstill_duration, 1.0), "风剑球默认施法立定时间为 1 秒")
	_check(
		standstill_simulation.left.velocity == Vector2.ZERO
			and is_zero_approx(standstill_simulation.left_ability.speed_multiplier(
				standstill_simulation.battle_context,
				standstill_simulation.left,
				standstill_simulation.right,
				0
			)),
		"风剑球斩击瞬间停止移动并禁用最低速度补偿"
	)
	standstill_simulation.left_ability.before_motion(
		standstill_simulation.battle_context,
		standstill_simulation.left,
		standstill_simulation.right,
		0,
		standstill_duration - 0.01
	)
	_check(standstill_simulation.left.velocity == Vector2.ZERO, "风剑球在完整立定时间内保持静止")
	standstill_simulation.left_ability.before_motion(
		standstill_simulation.battle_context,
		standstill_simulation.left,
		standstill_simulation.right,
		0,
		0.02
	)
	_check(standstill_simulation.left.velocity == Vector2.ZERO, "跨过 1 秒边界的当前物理帧仍保持静止")
	standstill_simulation.left_ability.before_motion(
		standstill_simulation.battle_context,
		standstill_simulation.left,
		standstill_simulation.right,
		0,
		0.0
	)
	_check(
		standstill_simulation.left.velocity.is_equal_approx(movement_before_cast),
		"立定结束后风剑球恢复施法前的运动方向和速度"
	)

	var attachment_simulation := BattleSimulationScript.new(20260921, "wind_swordsman", "replicator")
	attachment_simulation.left.pos = Vector2(260.0, 320.0)
	attachment_simulation.right.pos = Vector2(520.0, 320.0)
	attachment_simulation.left.velocity = Vector2.ZERO
	attachment_simulation.right.velocity = Vector2.ZERO
	var attachment_target := TestDamageableEntity.new(1, Vector2(260.0, 390.0), 5.0)
	attachment_simulation.add_entity(attachment_target)
	var distant_main_hp := attachment_simulation.right.hp
	attachment_simulation.left_ability.on_step(
		attachment_simulation.battle_context,
		attachment_simulation.left,
		attachment_simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(
		attachment_target.hp,
		100.0 - module.settingf("slash_damage")
	), "敌方主球斩不到时，风剑球主动朝最近的可受击附属物挥刀")
	_check(is_equal_approx(attachment_simulation.right.hp, distant_main_hp), "朝附属物挥刀不会隔空扣除未被刀痕覆盖的主球生命")
	var attachment_slashes: Array[BallEntity] = attachment_simulation.entity_list(0, "wind_slash_vfx")
	_check(attachment_slashes.size() == 1, "只有附属物可斩时仍会生成完整刀痕")
	if not attachment_slashes.is_empty():
		_check(attachment_slashes[0].get("_direction").is_equal_approx(Vector2.DOWN), "附属物目标决定真实挥刀方向")
	var attachment_cracks: Array[BallEntity] = attachment_simulation.entity_list(0, "wind_ground_crack")
	_check(attachment_cracks.size() == 1, "朝附属物斩击时同步生成下层地面裂痕")
	if not attachment_cracks.is_empty():
		_check(attachment_cracks[0].pos.is_equal_approx(
			attachment_simulation.left.pos + Vector2.DOWN * module.settingf("slash_reach") * 0.5
		), "朝附属物斩击时刀光与裂痕仍完整重叠")

	var wall_simulation := BattleSimulationScript.new(20260919, "wind_swordsman", "replicator")
	wall_simulation.left.pos = Vector2(250.0, 320.0)
	wall_simulation.right.pos = Vector2(520.0, 320.0)
	wall_simulation.left.velocity = Vector2(170.0, -35.0)
	wall_simulation.left_ability.activate(
		wall_simulation.battle_context,
		wall_simulation.left,
		wall_simulation.right,
		0
	)
	_check(
		_count_combat_events(wall_simulation.take_combat_events(), "blade_slash") == 0,
		"风剑球 W 不会直接发送 Hasagi 语音事件"
	)
	_check(wall_simulation.left.velocity == Vector2.ZERO, "风剑球释放风障时同样立即立定")
	var walls: Array[BallEntity] = wall_simulation.entity_list(0, "wind_wall")
	_check(walls.size() == 1, "风障技能生成一个独立曲面实体")
	if walls.is_empty():
		return
	_check(walls[0].is_absorbable(), "曲面风障继续遵守黑洞可捕获附属物契约")
	var hostile_color := Color("ff824a")
	wall_simulation.add_projectile(
		1,
		Vector2(380.0, 320.0),
		Vector2(-1800.0, 0.0),
		5.0,
		9.0,
		hostile_color,
		2.0,
		"wind_wall_hostile_test"
	)
	var hostile_projectile: BallEntity = wall_simulation.entity_list(1, "projectile")[-1]
	walls[0].call("intercept_projectiles", wall_simulation.battle_context, 0.05)
	_check(hostile_projectile.removed, "敌方高速投射物跨越弧线时也会被连续轨迹拦截")
	_check(hostile_projectile.owner_side == 1, "风障吸收投射物时不改变原所属阵营")
	_check(hostile_projectile.absorption_visual_color() == hostile_color, "风障吸收时不改变投射物原色")
	_check(int(wall_simulation.stats.get("projectiles_blocked", 0)) == 1, "风障拦截进入独立投射物统计")
	_check(
		_count_combat_events(wall_simulation.take_combat_events(), "wind_absorb") == 1,
		"风障吸收投射物时发送尖锐电子收束音效"
	)
	wall_simulation.add_projectile(
		0,
		Vector2(380.0, 320.0),
		Vector2(-1800.0, 0.0),
		5.0,
		9.0,
		Color("8ff5ff"),
		2.0,
		"wind_wall_friendly_test"
	)
	var friendly_projectile: BallEntity = wall_simulation.entity_list(0, "projectile")[-1]
	walls[0].call("intercept_projectiles", wall_simulation.battle_context, 0.05)
	_check(not friendly_projectile.removed, "己方投射物可以穿过自己的风障")
	wall_simulation.add_projectile(
		1,
		Vector2(380.0, 120.0),
		Vector2(-1800.0, 0.0),
		5.0,
		9.0,
		Color.WHITE,
		2.0,
		"wind_wall_off_arc_test"
	)
	var off_arc_projectile: BallEntity = wall_simulation.entity_list(1, "projectile")[-1]
	walls[0].call("intercept_projectiles", wall_simulation.battle_context, 0.05)
	_check(not off_arc_projectile.removed, "未命中弧形几何的敌方投射物不会被错误吸收")

func _check_forced_movement_priority() -> void:
	BallRegistry.configure_settings({
		"wind_swordsman": {"skill_standstill_duration": 3.0},
	})
	var simulation := BattleSimulationScript.new(20261202, "vampire", "wind_swordsman")
	simulation.left.pos = Vector2(280.0, 320.0)
	simulation.right.pos = Vector2(335.0, 320.0)
	var forced_velocity := Vector2(144.0, 36.0)
	simulation.left.velocity = forced_velocity
	simulation.right.velocity = Vector2(-180.0, 24.0)
	simulation.right_ability.activate(
		simulation.battle_context,
		simulation.right,
		simulation.left,
		1
	)
	_check(simulation.right.velocity == Vector2.ZERO, "风剑球无强制控制时仍立即进入三秒测试立定")
	simulation.left_ability.after_contact(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0.0
	)
	_check(
		simulation.battle_context.movement_control_priority(simulation.right)
			== BallStatusEffect.MOVEMENT_CONTROL_PRIORITY_FORCED,
		"吸血鬼吸附以通用强制移动优先级控制目标"
	)
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	var dragged_position := simulation.right.pos
	var dragged_velocity := simulation.right.velocity
	simulation.right_ability.before_motion(
		simulation.battle_context,
		simulation.right,
		simulation.left,
		1,
		BattleSimulation.FIXED_STEP
	)
	_check(
		simulation.right.pos.is_equal_approx(dragged_position)
			and simulation.right.velocity.is_equal_approx(dragged_velocity)
			and dragged_velocity.is_equal_approx(forced_velocity),
		"风剑球施法立定不会覆盖吸血鬼的吸附位置和拖拽速度"
	)
	_check(is_equal_approx(
		simulation.right_ability.speed_multiplier(
			simulation.battle_context,
			simulation.right,
			simulation.left,
			1
		),
		1.0
	), "强制拖拽期间风剑球不再返回零速度倍率")
	for _frame in range(130):
		if not bool(simulation.left_ability.call("is_latching")):
			break
		simulation.left_ability.on_step(
			simulation.battle_context,
			simulation.left,
			simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
	_check(not bool(simulation.left_ability.call("is_latching")), "优先级交互测试中的吸附仍按配置结束")
	_check(
		simulation.has_status(simulation.right, "vampire_latch_release:")
			and simulation.battle_context.movement_control_priority(simulation.right)
				== BallStatusEffect.MOVEMENT_CONTROL_PRIORITY_FORCED,
		"吸附结束的强制弹开同样保持高于能力立定的优先级"
	)
	var release_velocity := simulation.right.velocity
	simulation.right_ability.before_motion(
		simulation.battle_context,
		simulation.right,
		simulation.left,
		1,
		BattleSimulation.FIXED_STEP
	)
	_check(
		simulation.right.velocity.is_equal_approx(release_velocity)
			and release_velocity.length() > 0.0,
		"风剑球剩余立定时间不会吞掉吸血鬼的强制弹开速度"
	)
	BallRegistry.configure_settings({})

func _check_wind_ice_slow_resume() -> void:
	BallRegistry.configure_settings({
		"wind_swordsman": {"skill_standstill_duration": 0.5},
	})
	var simulation := BattleSimulationScript.new(20261205, "wind_swordsman", "plant")
	simulation.left.pos = Vector2(260.0, 320.0)
	simulation.right.pos = Vector2(520.0, 320.0)
	var movement_before_cast := Vector2(180.0, 45.0)
	simulation.left.velocity = movement_before_cast
	simulation.left_ability.activate(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0
	)
	var ice_effect: BallStatusEffect = simulation.apply_status(
		simulation.left,
		PlantIceSlowEffect.new(2.5, 1, 0.65)
	)
	simulation._update_fighter(
		simulation.left,
		simulation.right,
		simulation.left_ability,
		0,
		0.49
	)
	_check(
		simulation.left.velocity == Vector2.ZERO
			and float(ice_effect.get("_speed_cap")) < 0.0,
		"冰冻在风剑立定期间不会把瞬时零速度缓存为整段冰冻上限"
	)
	simulation._update_fighter(
		simulation.left,
		simulation.right,
		simulation.left_ability,
		0,
		0.02
	)
	_check(simulation.left.velocity == Vector2.ZERO, "跨过半秒立定边界的当前帧仍按施法动作保持静止")
	simulation._update_fighter(
		simulation.left,
		simulation.right,
		simulation.left_ability,
		0,
		0.0
	)
	var resumed_velocity := simulation.left.velocity
	var expected_slowed_speed := movement_before_cast.length() * 0.65
	_check(
		is_equal_approx(resumed_velocity.length(), expected_slowed_speed)
			and resumed_velocity.normalized().dot(movement_before_cast.normalized()) > 0.999,
		"立定结束后即使冰冻仍在，风剑也按冰冻倍率恢复原运动方向"
	)
	var position_before_motion := simulation.left.pos
	simulation._update_fighter(
		simulation.left,
		simulation.right,
		simulation.left_ability,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(
		simulation.left.pos.distance_to(position_before_motion) > 0.1,
		"冰冻剩余期间风剑持续移动而不是原地随机抖动或罚站"
	)
	for _frame in range(120):
		simulation._update_fighter(
			simulation.left,
			simulation.right,
			simulation.left_ability,
			0,
			BattleSimulation.FIXED_STEP
		)
	_check(
		not simulation.has_status(simulation.left, "plant_ice_slow_")
			and is_equal_approx(simulation.left.velocity.length(), simulation.left.base_speed),
		"冰冻结束后风剑恢复自身正常速度且不残留零速上限"
	)
	BallRegistry.configure_settings({})

func _check_yuri_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("yuri")
	for key in [
		"control_range",
		"max_control_per_cast",
		"max_controlled_total",
		"controlled_velocity_multiplier",
		"control_backlash_damage",
		"pulse_duration",
		"link_duration",
	]:
		_check(module.setting_specs().has(key), "尤里球参数 %s 由自身 Schema 配置" % key)

	var control_simulation := BattleSimulationScript.new(20260922, "yuri", "replicator")
	control_simulation.left.pos = Vector2(250.0, 320.0)
	control_simulation.right.pos = Vector2(520.0, 320.0)
	control_simulation.left.velocity = Vector2.ZERO
	control_simulation.right.velocity = Vector2.ZERO
	var projectile_color := Color("ff8bd8")
	control_simulation.add_projectile(
		1,
		Vector2(320.0, 320.0),
		Vector2(-200.0, 0.0),
		5.0,
		9.0,
		projectile_color,
		4.0,
		"mind_control_fixture"
	)
	var projectile: BallProjectileEntity = control_simulation.entity_list(1, "projectile")[0]
	var first_target := TestAbsorbableEntity.new(1, Vector2(340.0, 320.0), 6.0, "mind_control_first")
	var second_target := TestAbsorbableEntity.new(1, Vector2(360.0, 320.0), 6.0, "mind_control_second")
	var third_target := TestAbsorbableEntity.new(1, Vector2(380.0, 320.0), 6.0, "mind_control_third")
	first_target.velocity = Vector2(-100.0, 0.0)
	control_simulation.add_entity(first_target)
	control_simulation.add_entity(second_target)
	control_simulation.add_entity(third_target)
	var opponent_hp_before := control_simulation.right.hp
	control_simulation.take_combat_events()
	control_simulation.left_ability.activate(
		control_simulation.battle_context,
		control_simulation.left,
		control_simulation.right,
		0
	)
	_check(not projectile.can_transfer_ownership(), "投射物类型在通用协议层永久拒绝阵营转移")
	_check(projectile.owner_side == 1, "尤里球不会控制范围内最近的敌方投射物")
	_check(projectile.color == projectile_color, "未被控制的投射物保持原色")
	_check(projectile.velocity.x < 0.0, "未被控制的投射物保持原运动方向")
	_check(first_target.owner_side == 0, "尤里球跳过投射物并夺取最近的非投射附属物")
	_check(second_target.owner_side == 0, "单次控制继续夺取第二个最近附属物")
	_check(third_target.owner_side == 1, "单次控制数量上限阻止第三个附属物同时倒戈")
	_check(first_target.velocity.x > 0.0, "被控制的移动附属物立即掉头冲向原阵营")
	_check(
		first_target.absorption_visual_color() == control_simulation.left.accent
			and second_target.absorption_visual_color() == control_simulation.left.accent,
		"被尤里球控制的附属物统一染为尤里紫"
	)
	_check(int(control_simulation.left_ability.call("controlled_count")) == 2, "尤里球私有状态准确记录当前受控物数量")
	_check(int(control_simulation.stats.get("mind_controls", 0)) == 2, "每个成功倒戈对象进入心灵控制统计")
	_check(is_equal_approx(
		opponent_hp_before - control_simulation.right.hp,
		module.settingf("control_backlash_damage") * 2.0
	), "每次所有权夺取都会对原主人造成配置化精神反噬")
	_check(control_simulation.count_entities(0, "psychic_pulse_vfx") == 1, "心灵控制释放独立扩散精神波")
	_check(control_simulation.count_entities(0, "psychic_eye_overlay_vfx") == 1, "尤里施法生成独立顶层眼睛动画")
	_check(control_simulation.count_entities(0, "psychic_link_vfx") == 2, "每个倒戈目标生成独立控制链")
	_check(
		_count_combat_events(control_simulation.take_combat_events(), "psychic_pulse") == 1,
		"成功心灵控制发送原创精神扫频音效"
	)
	_check(is_zero_approx(
		control_simulation.left_ability.contact_damage(
			control_simulation.battle_context,
			control_simulation.left,
			control_simulation.right
		)
	), "尤里球普通本体碰撞保持零伤害")

	var no_target_simulation := BattleSimulationScript.new(20260923, "yuri", "laser")
	no_target_simulation.left.pos = Vector2(250.0, 320.0)
	no_target_simulation.right.pos = Vector2(500.0, 320.0)
	no_target_simulation.left.velocity = Vector2.ZERO
	no_target_simulation.right.velocity = Vector2(-120.0, 40.0)
	var no_target_hp_before := no_target_simulation.right.hp
	var no_target_velocity_before := no_target_simulation.right.velocity
	no_target_simulation.take_combat_events()
	no_target_simulation.left_ability.activate(
		no_target_simulation.battle_context,
		no_target_simulation.left,
		no_target_simulation.right,
		0
	)
	_check(
		is_equal_approx(no_target_simulation.right.hp, no_target_hp_before)
			and no_target_simulation.right.velocity.is_equal_approx(no_target_velocity_before),
		"没有可控制附属物时，尤里球不伤害也不改变敌方主球运动"
	)
	_check(
		no_target_simulation.beams.is_empty()
			and no_target_simulation.impact_rings.is_empty()
			and no_target_simulation.particles.is_empty(),
		"没有可控制附属物时，不生成激光、震荡波、命中特效或粒子"
	)
	_check(
		no_target_simulation.count_entities(0, "psychic_pulse_vfx") == 0
			and no_target_simulation.count_entities(0, "psychic_eye_overlay_vfx") == 0
			and no_target_simulation.count_entities(0, "psychic_link_vfx") == 0,
		"没有可控制附属物时，不生成控制眼睛、精神波或控制链"
	)
	_check(
		_count_combat_events(no_target_simulation.take_combat_events(), "psychic_pulse") == 0,
		"没有可控制附属物时，不播放精神控制音效"
	)

	var captured_simulation := BattleSimulationScript.new(20260924, "yuri", "replicator")
	captured_simulation.left.pos = Vector2(250.0, 320.0)
	captured_simulation.right.pos = Vector2(500.0, 320.0)
	var captured_target := TestAbsorbableEntity.new(1, Vector2(320.0, 320.0), 5.0, "captured_control_fixture")
	captured_simulation.add_entity(captured_target)
	_check(captured_target.disable_for_capture(), "反制夹具先进入黑洞式捕获禁用状态")
	captured_simulation.left_ability.activate(
		captured_simulation.battle_context,
		captured_simulation.left,
		captured_simulation.right,
		0
	)
	_check(captured_target.owner_side == 1, "已经被捕获禁用的对象不能再被尤里球抢夺")

	var orbit_simulation := BattleSimulationScript.new(20260927, "yuri", "replicator")
	orbit_simulation.left.pos = Vector2(190.0, 320.0)
	orbit_simulation.right.pos = Vector2(430.0, 320.0)
	orbit_simulation.left.velocity = Vector2.ZERO
	orbit_simulation.right.velocity = Vector2.ZERO
	orbit_simulation.right_ability.activate(
		orbit_simulation.battle_context,
		orbit_simulation.right,
		orbit_simulation.left,
		1
	)
	var orbit_cannons: Array[BallEntity] = orbit_simulation.entity_list(1, "clone")
	_check(orbit_cannons.size() == 1, "永久控制测试生成一门敌方浮游炮")
	if not orbit_cannons.is_empty():
		var orbit_cannon := orbit_cannons[0]
		var native_orbit_radius: float = BallRegistry.get_module("replicator").settingf("inner_orbit_radius")
		_check(is_equal_approx(
			orbit_cannon.pos.distance_to(orbit_simulation.right.pos),
			native_orbit_radius
		), "浮游炮被控制前围绕原主人使用自身原轨道半径")
		orbit_simulation.left_ability.activate(
			orbit_simulation.battle_context,
			orbit_simulation.left,
			orbit_simulation.right,
			0
		)
		_check(orbit_cannon.owner_side == 0, "尤里球永久夺取浮游炮所有权")
		_check(is_equal_approx(
			orbit_cannon.pos.distance_to(orbit_simulation.left.pos),
			native_orbit_radius
		), "被控制浮游炮立即把尤里球作为新轨道中心")
		var controlled_projectiles_before := orbit_simulation.count_entities(0, "projectile")
		var controlled_cannon_position := orbit_cannon.pos
		orbit_simulation.right_ability.activate(
			orbit_simulation.battle_context,
			orbit_simulation.right,
			orbit_simulation.left,
			1
		)
		var controlled_projectiles: Array[BallEntity] = orbit_simulation.entity_list(0, "projectile")
		_check(
			controlled_projectiles.size() == controlled_projectiles_before + 1,
			"被尤里永久控制的浮游炮继续按原生齐射节奏发射子弹"
		)
		if controlled_projectiles.size() > controlled_projectiles_before:
			var controlled_projectile: BallEntity = controlled_projectiles[-1]
			_check(
				controlled_projectile.owner_side == 0
					and controlled_projectile.pos.is_equal_approx(controlled_cannon_position),
				"受控浮游炮从自身位置发射尤里阵营子弹"
			)
			_check(
				controlled_projectile.velocity.normalized().dot(
					(orbit_simulation.right.pos - controlled_cannon_position).normalized()
				) > 0.98,
				"受控浮游炮改为瞄准原主人阵营"
			)
		orbit_cannon.pos = orbit_simulation.left.pos + Vector2.RIGHT * (
			module.settingf("control_range") + 200.0
		)
		orbit_simulation.right.pos = Vector2(590.0, 590.0)
		orbit_simulation.right_ability.on_step(
			orbit_simulation.battle_context,
			orbit_simulation.right,
			orbit_simulation.left,
			1,
			0.0
		)
		orbit_simulation.left_ability.activate(
			orbit_simulation.battle_context,
			orbit_simulation.left,
			orbit_simulation.right,
			0
		)
		_check(
			orbit_cannon.owner_side == 0
				and int(orbit_simulation.left_ability.call("controlled_count")) == 1,
			"受控物脱离心灵控制范围后阵营和永久控制记录都不复原"
		)
		orbit_cannon.process_step(orbit_simulation.battle_context, 0.0)
		_check(is_equal_approx(
			orbit_cannon.pos.distance_to(orbit_simulation.left.pos),
			native_orbit_radius
		), "脱离控制范围后浮游炮仍回到尤里球的原生轨道")
		var offset_before_rotation: Vector2 = orbit_cannon.pos - orbit_simulation.left.pos
		orbit_simulation.right_ability.before_motion(
			orbit_simulation.battle_context,
			orbit_simulation.right,
			orbit_simulation.left,
			1,
			0.25
		)
		orbit_cannon.process_step(orbit_simulation.battle_context, 0.25)
		var offset_after_rotation: Vector2 = orbit_cannon.pos - orbit_simulation.left.pos
		_check(is_equal_approx(offset_after_rotation.length(), native_orbit_radius), "受控浮游炮旋转时保持原轨道半径")
		_check(not offset_after_rotation.is_equal_approx(offset_before_rotation), "受控浮游炮继续使用原本的环绕速度与运动方式")
		_check(
			orbit_cannon.pos.distance_to(orbit_simulation.right.pos) > native_orbit_radius * 2.0,
			"受控浮游炮不再围绕原主人"
		)

	var clone_collision_simulation := BattleSimulationScript.new(20260928, "yuri", "splitter")
	clone_collision_simulation.left.pos = Vector2(190.0, 320.0)
	clone_collision_simulation.right.pos = Vector2(520.0, 320.0)
	clone_collision_simulation.left.velocity = Vector2.ZERO
	clone_collision_simulation.right.velocity = Vector2.ZERO
	clone_collision_simulation.right_ability.activate(
		clone_collision_simulation.battle_context,
		clone_collision_simulation.right,
		clone_collision_simulation.left,
		1
	)
	var duel_clones: Array[BallEntity] = clone_collision_simulation.entity_list(1, "splitter_clone")
	_check(duel_clones.size() >= 2, "尤里控制碰撞测试生成两个敌方分身")
	if duel_clones.size() >= 2:
		var controlled_clone: BallEntity = duel_clones[0]
		var original_clone: BallEntity = duel_clones[1]
		controlled_clone.pos = Vector2(250.0, 320.0)
		original_clone.pos = Vector2(620.0, 320.0)
		clone_collision_simulation.left_ability.activate(
			clone_collision_simulation.battle_context,
			clone_collision_simulation.left,
			clone_collision_simulation.right,
			0
		)
		_check(
			controlled_clone.owner_side == 0 and original_clone.owner_side == 1,
			"尤里只永久控制范围内的一个分身"
		)
		controlled_clone.pos = Vector2(320.0, 320.0)
		original_clone.pos = Vector2(324.0, 320.0)
		controlled_clone.velocity = Vector2(120.0, 0.0)
		original_clone.velocity = Vector2(-120.0, 0.0)
		controlled_clone.set("_contact_timer", 0.0)
		original_clone.set("_contact_timer", 0.0)
		var controlled_hp_before: float = float(controlled_clone.get("hp"))
		var original_hp_before: float = float(original_clone.get("hp"))
		clone_collision_simulation.right_ability.after_entities_step(
			clone_collision_simulation.battle_context,
			clone_collision_simulation.right,
			clone_collision_simulation.left,
			1,
			0.0
		)
		_check(
			controlled_clone.pos.distance_to(original_clone.pos)
				>= controlled_clone.radius + original_clone.radius - 0.001,
			"被控制分身与原阵营分身仍会发生实体碰撞并分离"
		)
		_check(
			is_equal_approx(
				controlled_hp_before - float(controlled_clone.get("hp")),
				float(original_clone.entity_contact_damage())
			) and is_equal_approx(
				original_hp_before - float(original_clone.get("hp")),
				float(controlled_clone.entity_contact_damage())
			),
			"倒戈分身与原阵营分身碰撞时互相正确扣血"
		)
		_check(
			int(clone_collision_simulation.stats.get("clone_entity_contact_hits", 0)) == 1,
			"倒戈分身碰撞只结算一次"
		)

	var deterministic_a := BattleSimulationScript.new(20260925, "yuri", "splitter")
	var deterministic_b := BattleSimulationScript.new(20260925, "yuri", "splitter")
	_run_to_finish(deterministic_a, false)
	_run_to_finish(deterministic_b, false)
	_check(deterministic_a.snapshot() == deterministic_b.snapshot(), "尤里球的目标选择与所有权转移可按种子完全重放")

func _prepare_contact(simulation: BattleSimulation) -> void:
	var minimum_distance := simulation.left.radius + simulation.right.radius
	simulation.left.pos = Vector2(280.0, 320.0)
	simulation.right.pos = Vector2(280.0 + minimum_distance - 1.0, 320.0)
	simulation.left.velocity = Vector2(160.0, 0.0)
	simulation.right.velocity = Vector2(-160.0, 0.0)

func _check_plant_growth_cycle() -> void:
	var module: BallModule = BallRegistry.get_module("plant")
	_check(is_equal_approx(module.cooldown, 5.0), "植物球默认每 5 秒种下一颗种子")
	for key in [
		"max_plants",
		"seed_radius",
		"plant_max_hp",
		"plant_contact_damage",
		"plant_contact_interval",
		"growth_delay",
		"sunflower_growth_weight",
		"fire_pea_growth_weight",
		"ice_pea_growth_weight",
		"gatling_pea_growth_weight",
		"projectile_spawn_gap",
		"projectile_boundary_padding",
		"fire_pea_damage",
		"fire_burn_damage",
		"fire_burn_tick_interval",
		"fire_burn_duration",
		"ice_pea_damage",
		"ice_slow_multiplier",
		"gatling_fire_interval",
		"sun_launch_interval",
		"sun_travel_duration",
		"sun_arc_height",
		"sun_pickup_heal",
		"planting_icon_duration",
		"growth_animation_duration",
	]:
		_check(module.setting_specs().has(key), "植物球参数 %s 由自身 Schema 配置" % key)
	for removed_key in [
		"seed_max_hp",
		"sunflower_chance",
		"first_growth_delay",
		"second_growth_delay",
		"basic_pea_damage",
		"sun_bolt_interval",
		"sun_heal_interval",
		"sun_pickup_interval",
		"placement_margin",
		"placement_attempts",
	]:
		_check(not module.setting_specs().has(removed_key), "植物球不再保留废弃参数 %s" % removed_key)
	var default_simulation := BattleSimulationScript.new(20261101, "plant", "laser")
	_check(is_equal_approx(default_simulation.left.ability_timer, 5.0), "植物球第一颗种子也等待完整 5 秒")
	_check(
		is_zero_approx(default_simulation.left_ability.contact_damage(
			default_simulation.battle_context,
			default_simulation.left,
			default_simulation.right
		)),
		"植物球本体普通碰撞不造成伤害"
	)
	_check(
		is_equal_approx(module.settingf("sunflower_growth_weight"), 3.0)
		and is_equal_approx(module.settingf("fire_pea_growth_weight"), 1.0)
		and is_equal_approx(module.settingf("ice_pea_growth_weight"), 1.0)
		and is_equal_approx(module.settingf("gatling_pea_growth_weight"), 1.0),
		"四类默认发育权重保持向日葵 50%、三类豌豆各约 16.7%"
	)
	var exclusive_growth_forms := [
		{"weight_key": "sunflower_growth_weight", "form": "sunflower"},
		{"weight_key": "fire_pea_growth_weight", "form": "pea_fire"},
		{"weight_key": "ice_pea_growth_weight", "form": "pea_ice"},
		{"weight_key": "gatling_pea_growth_weight", "form": "pea_gatling"},
	]
	for exclusive_index in range(exclusive_growth_forms.size()):
		var exclusive_case: Dictionary = exclusive_growth_forms[exclusive_index]
		var exclusive_settings := {
			"cooldown": 60.0,
			"max_plants": 1,
			"growth_delay": 0.1,
			"sunflower_growth_weight": 0.0,
			"fire_pea_growth_weight": 0.0,
			"ice_pea_growth_weight": 0.0,
			"gatling_pea_growth_weight": 0.0,
		}
		exclusive_settings[String(exclusive_case["weight_key"])] = 1.0
		BallRegistry.configure_settings({"plant": exclusive_settings})
		var exclusive_simulation := BattleSimulationScript.new(
			20261130 + exclusive_index,
			"plant",
			"laser"
		)
		exclusive_simulation.left_ability.activate(
			exclusive_simulation.battle_context,
			exclusive_simulation.left,
			exclusive_simulation.right,
			0
		)
		for _frame in range(2):
			exclusive_simulation.step(0.05)
		var exclusive_plants: Array[BallEntity] = exclusive_simulation.entity_list(0, "plant_growth")
		_check(
			exclusive_plants.size() == 1
			and String(exclusive_plants[0].call("form_name")) == String(exclusive_case["form"]),
			"单独启用%s时种子必定发育为对应植物" % String(exclusive_case["weight_key"])
		)
	BallRegistry.configure_settings({})

	BallRegistry.configure_settings({
		"plant": {
			"cooldown": 60.0,
			"max_plants": 1,
			"growth_delay": 0.1,
			"growth_animation_duration": 0.1,
			"sunflower_growth_weight": 1.0,
			"fire_pea_growth_weight": 0.0,
			"ice_pea_growth_weight": 0.0,
			"gatling_pea_growth_weight": 0.0,
			"sun_launch_interval": 0.1,
			"sun_travel_duration": 0.1,
			"sun_pickup_heal": 10.0,
			"sun_pickup_lifetime": 20.0,
		}
	})
	var sunflower_simulation := BattleSimulationScript.new(20261102, "plant", "laser")
	var planting_origin := sunflower_simulation.left.pos
	sunflower_simulation.left_ability.activate(
		sunflower_simulation.battle_context,
		sunflower_simulation.left,
		sunflower_simulation.right,
		0
	)
	var sunflower_plants: Array[BallEntity] = sunflower_simulation.entity_list(0, "plant_growth")
	_check(sunflower_plants.size() == 1, "植物球种植生成一个独立种子实体")
	var planting_overlays: Array[BallEntity] = sunflower_simulation.entity_list(0, "planting_icon_overlay_vfx")
	_check(planting_overlays.size() == 1, "每次成功种植都会生成植物嫩芽施法图标")
	if not planting_overlays.is_empty():
		var planting_overlay: BallEntity = planting_overlays[0]
		_check(planting_overlay.draws_above_balls() and planting_overlay.draw_layer > 100, "种植图标位于球体和球内血量上方的最高实体图层")
		sunflower_simulation.left.pos += Vector2(18.0, -12.0)
		planting_overlay.process_step(sunflower_simulation.battle_context, 0.0)
		_check(planting_overlay.pos.is_equal_approx(sunflower_simulation.left.pos), "种植图标在动画期间始终居中跟随植物球")
		var overlay_duration: float = planting_overlay.remaining
		var start_scale: float = float(planting_overlay.call("animation_scale"))
		planting_overlay.process_lifetime(overlay_duration * 0.5)
		var peak_scale: float = float(planting_overlay.call("animation_scale"))
		planting_overlay.process_lifetime(overlay_duration * 0.5)
		var end_scale: float = float(planting_overlay.call("animation_scale"))
		_check(peak_scale > start_scale and peak_scale > end_scale, "种植图标执行先放大再缩小的施法动画")
	if not sunflower_plants.is_empty():
		var sunflower: BallEntity = sunflower_plants[0]
		_check(sunflower.pos.is_equal_approx(planting_origin), "种子固定种在技能触发瞬间的植物球脚下")
		_check(String(sunflower.call("form_name")) == "seed", "新种下的实体从种子形态开始")
		_check(not sunflower.can_receive_attack(1) and not sunflower.can_receive_attack(0), "种子阶段不可被任何阵营攻击")
		_check(sunflower.is_absorbable() and sunflower.can_transfer_ownership(), "种子接入通用捕获、吞噬与控制契约")
		var seed_damage: float = sunflower_simulation.battle_context.damage_entity(
			sunflower,
			999.0,
			Color.WHITE,
			1
		)
		_check(is_zero_approx(seed_damage) and not sunflower.removed, "攻击命中种子时不扣血也不摧毁种子")
		for _frame in range(2):
			sunflower_simulation.step(0.05)
		_check(String(sunflower.call("form_name")) == "sunflower", "种子直接一次发育为向日葵")
		var growth_start_scale: float = float(sunflower.call("growth_animation_scale"))
		sunflower_simulation.left.hp = 50.0
		sunflower_simulation.step(0.05)
		var growth_peak_scale: float = float(sunflower.call("growth_animation_scale"))
		sunflower_simulation.step(0.05)
		var growth_end_scale: float = float(sunflower.call("growth_animation_scale"))
		_check(
			growth_start_scale < 1.0
			and growth_peak_scale > 1.0
			and is_equal_approx(growth_end_scale, 1.0),
			"成熟植物从小尺寸破土长出、轻微过冲后稳定到正常尺寸"
		)
		_check(is_equal_approx(sunflower_simulation.left.hp, 50.0), "向日葵自身不再治疗主球或附近植物")
		_check(int(sunflower_simulation.stats.get("projectiles_spawned", 0)) == 0, "向日葵不再发射攻击型阳光弹")
		var sun_pickups: Array[BallEntity] = sunflower_simulation.entity_list(0, "plant_sun_pickup")
		_check(sun_pickups.size() == 1, "向日葵把可拾取阳光抛向地图随机点")
		if not sun_pickups.is_empty():
			var sun: BallEntity = sun_pickups[0]
			var launch_position := sun.pos
			var landing_position: Vector2 = sun.call("landing_position")
			_check(not bool(sun.call("is_landed")) and launch_position.is_equal_approx(sunflower.pos), "阳光从向日葵位置开始飞行")
			sunflower_simulation.left.pos = Vector2.ZERO
			sun.process_step(sunflower_simulation.battle_context, 0.05)
			_check(not sun.pos.is_equal_approx(launch_position), "阳光沿抛物线向随机落点移动")
			sun.process_step(sunflower_simulation.battle_context, 0.05)
			_check(bool(sun.call("is_landed")) and sun.pos.is_equal_approx(landing_position), "阳光到达随机点后停止移动")
			var landed_position := sun.pos
			sun.process_step(sunflower_simulation.battle_context, 0.05)
			_check(sun.pos.is_equal_approx(landed_position), "落地阳光保持静止等待拾取")
			sunflower_simulation.left.hp = 40.0
			sunflower_simulation.left.pos = sun.pos
			sun.process_step(sunflower_simulation.battle_context, 0.0)
			_check(is_equal_approx(sunflower_simulation.left.hp, 50.0), "主球拾取阳光准确回复 10 点生命")
			_check(sun.removed, "阳光被成功拾取后立即清理")
		var damage_applied: float = sunflower_simulation.battle_context.damage_entity(
			sunflower,
			50.0,
			Color.WHITE,
			1
		)
		_check(damage_applied > 0.0 and sunflower.removed, "成熟植物受击扣除自身生命并可被摧毁")

	BallRegistry.configure_settings({
		"plant": {
			"cooldown": 60.0,
			"max_plants": 1,
			"growth_delay": 0.1,
			"sunflower_growth_weight": 0.0,
			"fire_pea_growth_weight": 1.0,
			"ice_pea_growth_weight": 1.0,
			"gatling_pea_growth_weight": 1.0,
			"fire_fire_interval": 0.1,
			"ice_fire_interval": 0.1,
			"gatling_fire_interval": 0.1,
			"pea_projectile_speed": 20.0,
			"pea_projectile_lifetime": 5.0,
		}
	})
	var growth_a := BattleSimulationScript.new(20261103, "plant", "hammer")
	var growth_b := BattleSimulationScript.new(20261103, "plant", "hammer")
	for simulation: BattleSimulation in [growth_a, growth_b]:
		simulation.left_ability.activate(
			simulation.battle_context,
			simulation.left,
			simulation.right,
			0
		)
		for _frame in range(5):
			simulation.step(0.05)
	var evolved_a: Array[BallEntity] = growth_a.entity_list(0, "plant_growth")
	var evolved_b: Array[BallEntity] = growth_b.entity_list(0, "plant_growth")
	if not evolved_a.is_empty() and not evolved_b.is_empty():
		var form_a := String(evolved_a[0].call("form_name"))
		var form_b := String(evolved_b[0].call("form_name"))
		_check(form_a in ["pea_fire", "pea_ice", "pea_gatling"], "种子直接随机发育为三个成熟豌豆品种之一")
		_check(form_a != "pea_basic", "植物球完全移除初级豌豆形态")
		_check(form_a == form_b and evolved_a[0].pos.is_equal_approx(evolved_b[0].pos), "植物选点与随机发育可按种子完全重放")
		_check(int(growth_a.stats.get("projectiles_spawned", 0)) > 0, "高级豌豆射手按各自射速持续开火")
		var controlled_plant: BallEntity = evolved_a[0]
		_check(controlled_plant.transfer_ownership(1, growth_a.right), "成熟植物可通过通用所有权契约被永久控制")
		controlled_plant.set_ownership_visual_color(Color("b45cff"))
		controlled_plant.set("_action_timer", 0.0)
		controlled_plant.process_step(growth_a.battle_context, 0.05)
		_check(
			growth_a.count_entities(1, "plant_projectile") > 0,
			"倒戈后的豌豆射手保持原能力并为新阵营继续开火"
		)
		_check(
			controlled_plant.absorption_visual_color() == Color("b45cff"),
			"倒戈植物通过通用阵营色契约切换视觉颜色"
		)
	else:
		_check(false, "植物球可生成用于直接发育检查的成熟豌豆射手")

	var fire_simulation := BattleSimulationScript.new(20261104, "plant", "sonic")
	fire_simulation.left.pos = Vector2(120.0, 320.0)
	fire_simulation.right.pos = Vector2(320.0, 320.0)
	fire_simulation.right.velocity = Vector2.ZERO
	var fire_hp_before: float = fire_simulation.right.hp
	var fire_projectile: BallEntity = PlantPeaProjectileEntity.new(
		0,
		Vector2(270.0, 320.0),
		Vector2(300.0, 0.0),
		5.0,
		8.0,
		Color("ff6724"),
		2.0,
		"fire",
		1.0,
		0.0,
		1.0,
		1.0,
		4.0,
		20.0
	)
	fire_simulation.add_entity(fire_projectile)
	fire_projectile.process_step(fire_simulation.battle_context, 0.2)
	_check(fire_projectile.removed, "火豌豆命中后像非穿透弹丸一样消除")
	_check(fire_simulation.has_status(fire_simulation.right, "burn_0_plant_fire_pea"), "火豌豆命中主球后施加可复用燃烧状态")
	_check(is_equal_approx(fire_hp_before - fire_simulation.right.hp, 8.0), "火豌豆先结算配置的直接命中伤害")
	var hp_before_burn_tick: float = fire_simulation.right.hp
	for _frame in range(20):
		fire_simulation.step(0.05)
	_check(is_equal_approx(hp_before_burn_tick - fire_simulation.right.hp, 1.0), "火豌豆默认燃烧每秒准确扣除 1 点生命")
	_check(int(fire_simulation.stats.get("burn_damage_ticks", 0)) == 1, "燃烧伤害按独立计时器结算")

	var reusable_burn_simulation := BattleSimulationScript.new(20261114, "plant", "laser")
	var caller_defined_burn: BallStatusEffect = BurnStatusEffectScript.new(
		2.0,
		0,
		3.5,
		0.5,
		"reusable_test",
		Color("ff9a32")
	)
	reusable_burn_simulation.apply_status(reusable_burn_simulation.right, caller_defined_burn)
	var reusable_hp_before: float = reusable_burn_simulation.right.hp
	for _frame in range(11):
		reusable_burn_simulation.step(0.05)
	_check(is_equal_approx(reusable_hp_before - reusable_burn_simulation.right.hp, 3.5), "通用燃烧状态使用调用球注入的伤害与间隔，不写死植物球数值")
	_check(reusable_burn_simulation.particles.size() > 0, "燃烧状态持续生成可见火粒子")

	var ice_simulation := BattleSimulationScript.new(20261105, "plant", "sonic")
	ice_simulation.left.pos = Vector2(120.0, 320.0)
	ice_simulation.right.pos = Vector2(320.0, 320.0)
	ice_simulation.right.velocity = Vector2(200.0, 0.0)
	var ice_projectile: BallEntity = PlantPeaProjectileEntity.new(
		0,
		Vector2(270.0, 320.0),
		Vector2(300.0, 0.0),
		5.0,
		1.0,
		Color("73e9ff"),
		2.0,
		"ice",
		0.5,
		2.0,
		0.0,
		1.0,
		0.0,
		20.0
	)
	ice_simulation.add_entity(ice_projectile)
	ice_projectile.process_step(ice_simulation.battle_context, 0.2)
	_check(ice_projectile.removed, "冰豌豆命中后像非穿透弹丸一样消除")
	_check(ice_simulation.battle_context.has_status(ice_simulation.right, "plant_ice_slow_"), "冰豌豆命中主球后施加减速状态")
	var speed_before_slow := ice_simulation.right.velocity.length()
	ice_simulation.step(BattleSimulation.FIXED_STEP)
	_check(ice_simulation.right.velocity.length() <= speed_before_slow * 0.51, "冰豌豆减速倍率实际限制目标速度")

	var capture_simulation := BattleSimulationScript.new(20261106, "plant", "black_hole")
	capture_simulation.left_ability.activate(
		capture_simulation.battle_context,
		capture_simulation.left,
		capture_simulation.right,
		0
	)
	var captured_seeds: Array[BallEntity] = capture_simulation.entity_list(0, "plant_growth")
	if not captured_seeds.is_empty():
		var captured_seed: BallEntity = captured_seeds[0]
		_check(captured_seed.disable_for_capture(), "黑洞可通过通用契约捕获植物种子")
		captured_seed.process_step(capture_simulation.battle_context, 30.0)
		_check(String(captured_seed.call("form_name")) == "seed", "被捕获种子会禁用成长与后续能力")
		_check(captured_seed.absorb(capture_simulation.battle_context, 1, capture_simulation.right.pos), "被捕获种子可被黑洞完全吞噬")
	else:
		_check(false, "植物球可生成用于捕获反制检查的种子")
	BallRegistry.configure_settings({})
	var representative_opponents := [
		{"id": "hammer", "label": "近战"},
		{"id": "laser", "label": "远程"},
		{"id": "splitter", "label": "附属物"},
	]
	for index in range(representative_opponents.size()):
		var representative: Dictionary = representative_opponents[index]
		var representative_simulation := BattleSimulationScript.new(
			20261120 + index,
			"plant",
			String(representative["id"])
		)
		_run_to_finish(representative_simulation, false)
		var ability_counts: Dictionary = representative_simulation.stats["abilities"]
		_check(representative_simulation.finished, "植物球对战%s球能正常结束或完成时限裁决" % representative["label"])
		_check(int(ability_counts["plant"]) > 0, "植物球对战%s球时确实执行种植能力" % representative["label"])
		_check(
			float(representative_simulation.stats["damage_to_left"])
				+ float(representative_simulation.stats["damage_to_right"]) > 0.0,
			"植物球对战%s球能产生真实战斗结果" % representative["label"]
		)

func _check_plant_clone_entity_collision() -> void:
	BallRegistry.configure_settings({
		"plant": {
			"max_plants": 1,
			"growth_delay": 0.1,
			"plant_max_hp": 20.0,
			"plant_contact_damage": 3.0,
			"plant_contact_interval": 0.32,
			"sunflower_growth_weight": 1.0,
			"fire_pea_growth_weight": 0.0,
			"ice_pea_growth_weight": 0.0,
			"gatling_pea_growth_weight": 0.0,
		},
		"splitter": {
			"clone_max_hp": 20.0,
			"clone_impact_damage": 4.0,
			"damage_split_chance": 0.0,
		},
	})
	var simulation := BattleSimulationScript.new(20261201, "plant", "splitter")
	simulation.left_ability.activate(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0
	)
	simulation.right_ability.activate(
		simulation.battle_context,
		simulation.right,
		simulation.left,
		1
	)
	var plants: Array[BallEntity] = simulation.entity_list(0, "plant_growth")
	var clones: Array[BallEntity] = simulation.entity_list(1, "splitter_clone")
	_check(plants.size() == 1 and clones.size() >= 2, "植物与分身实体碰撞测试生成双方附属物")
	if not plants.is_empty() and clones.size() >= 2:
		var plant: BallEntity = plants[0]
		var clone: BallEntity = clones[0]
		clones[1].pos = Vector2(80.0, 80.0)
		plant.pos = Vector2(320.0, 320.0)
		clone.pos = plant.pos
		clone.velocity = Vector2(120.0, 0.0)
		var seed_clone_position := clone.pos
		var seed_clone_hp := float(clone.get("hp"))
		simulation.right_ability.after_entities_step(
			simulation.battle_context,
			simulation.right,
			simulation.left,
			1,
			0.0
		)
		_check(
			not plant.participates_in_entity_collision()
				and clone.pos.is_equal_approx(seed_clone_position)
				and is_equal_approx(float(clone.get("hp")), seed_clone_hp),
			"不可受击种子阶段不会阻挡或伤害分身"
		)
		plant.process_step(simulation.battle_context, 0.11)
		_check(plant.participates_in_entity_collision(), "种子成熟后启用通用附属实体碰撞体")
		var stationary_plant_position := Vector2(320.0, 320.0)
		plant.pos = stationary_plant_position
		clone.pos = plant.pos - Vector2(plant.radius + clone.radius - 2.0, 0.0)
		clone.velocity = Vector2(120.0, 0.0)
		clone.set("_contact_timer", 0.0)
		plant.set("_entity_contact_timer", 0.0)
		var plant_hp_before := float(plant.get("hp"))
		var clone_hp_before := float(clone.get("hp"))
		simulation.take_combat_events()
		simulation.right_ability.after_entities_step(
			simulation.battle_context,
			simulation.right,
			simulation.left,
			1,
			0.0
		)
		_check(
			plant.pos.is_equal_approx(stationary_plant_position)
				and clone.pos.distance_to(plant.pos) >= plant.radius + clone.radius - 0.001
				and clone.velocity.x < 0.0,
			"成熟植物保持原种植点，分身碰撞后完成分离和反弹"
		)
		_check(
			is_equal_approx(plant_hp_before - float(plant.get("hp")), 4.0)
				and is_equal_approx(clone_hp_before - float(clone.get("hp")), 3.0),
			"成熟植物承受分身伤害，分身同时承受植物配置的接触伤害"
		)
		_check(
			int(simulation.stats.get("clone_entity_contact_hits", 0)) == 1
				and _count_combat_events(simulation.take_combat_events(), "clone_impact") == 1,
			"植物与分身的一次接触只结算一次并播放撞击音效"
		)
		var plant_hp_after := float(plant.get("hp"))
		var clone_hp_after := float(clone.get("hp"))
		clone.pos = plant.pos - Vector2(plant.radius + clone.radius - 1.0, 0.0)
		clone.velocity = Vector2(120.0, 0.0)
		simulation.right_ability.after_entities_step(
			simulation.battle_context,
			simulation.right,
			simulation.left,
			1,
			0.0
		)
		_check(
			is_equal_approx(float(plant.get("hp")), plant_hp_after)
				and is_equal_approx(float(clone.get("hp")), clone_hp_after),
			"接触冷却期间重复重叠不会连续多次扣血"
		)
	BallRegistry.configure_settings({})

func _check_plant_fighter_collision() -> void:
	BallRegistry.configure_settings({
		"plant": {
			"cooldown": 60.0,
			"max_plants": 1,
			"growth_delay": 0.1,
			"plant_max_hp": 40.0,
			"plant_contact_damage": 3.0,
			"plant_contact_interval": 0.32,
			"sunflower_growth_weight": 1.0,
			"fire_pea_growth_weight": 0.0,
			"ice_pea_growth_weight": 0.0,
			"gatling_pea_growth_weight": 0.0,
		},
		"sonic": {
			"body_impact_damage": 9.0,
		},
	})
	var sonic_simulation := BattleSimulationScript.new(20261203, "plant", "sonic")
	sonic_simulation.left_ability.activate(
		sonic_simulation.battle_context,
		sonic_simulation.left,
		sonic_simulation.right,
		0
	)
	var sonic_plants: Array[BallEntity] = sonic_simulation.entity_list(0, "plant_growth")
	_check(sonic_plants.size() == 1, "大球碰撞测试生成一株植物")
	if not sonic_plants.is_empty():
		var plant: BallEntity = sonic_plants[0]
		plant.pos = Vector2(320.0, 320.0)
		sonic_simulation.right.pos = plant.pos - Vector2(
			plant.radius + sonic_simulation.right.radius - 1.0,
			0.0
		)
		sonic_simulation.right.velocity = Vector2(300.0, 0.0)
		var seed_position: Vector2 = sonic_simulation.right.pos
		var seed_velocity: Vector2 = sonic_simulation.right.velocity
		sonic_simulation._resolve_fighter_entity_collisions()
		_check(
			sonic_simulation.right.pos.is_equal_approx(seed_position)
				and sonic_simulation.right.velocity.is_equal_approx(seed_velocity),
			"不可受击种子不会阻挡或改变大球运动"
		)
		plant.process_step(sonic_simulation.battle_context, 0.11)
		_check(plant.participates_in_fighter_collision(), "成熟植物启用通用大球碰撞体")
		sonic_simulation.right_ability.activate(
			sonic_simulation.battle_context,
			sonic_simulation.right,
			sonic_simulation.left,
			1
		)
		var stationary_position := Vector2(320.0, 320.0)
		plant.pos = stationary_position
		plant.velocity = Vector2.ZERO
		plant.set("_entity_contact_timer", 0.0)
		sonic_simulation.right.pos = plant.pos - Vector2(
			plant.radius + sonic_simulation.right.radius - 2.0,
			0.0
		)
		sonic_simulation.right.velocity = Vector2(360.0, 0.0)
		var plant_hp_before: float = float(plant.get("hp"))
		var sonic_hp_before := sonic_simulation.right.hp
		var sonic_damage: float = sonic_simulation.right_ability.contact_damage(
			sonic_simulation.battle_context,
			sonic_simulation.right,
			plant
		)
		sonic_simulation.take_combat_events()
		sonic_simulation._resolve_fighter_entity_collisions()
		_check(
			plant.pos.is_equal_approx(stationary_position)
				and sonic_simulation.right.pos.distance_to(plant.pos)
					>= sonic_simulation.right.radius + plant.radius - 0.001
				and sonic_simulation.right.velocity.x < 0.0,
			"成熟植物保持扎根，撞上的大球完成分离、反弹并改变轨迹"
		)
		_check(
			is_equal_approx(plant_hp_before - float(plant.get("hp")), sonic_damage)
				and is_equal_approx(
					sonic_hp_before - sonic_simulation.right.hp,
					BallRegistry.get_module("plant").settingf("plant_contact_damage")
				),
			"音速球按自身累计倍率伤害植物，植物按自身接触伤害反击"
		)
		_check(
			int(sonic_simulation.stats.get("fighter_entity_contact_hits", 0)) == 1
				and _count_combat_events(sonic_simulation.take_combat_events(), "body_impact") == 1,
			"大球与植物的一次接触只结算一次并立即发出碰撞音效"
		)
		var plant_hp_after: float = float(plant.get("hp"))
		var sonic_hp_after := sonic_simulation.right.hp
		sonic_simulation.right.pos = plant.pos - Vector2(
			plant.radius + sonic_simulation.right.radius - 1.0,
			0.0
		)
		sonic_simulation.right.velocity = Vector2(360.0, 0.0)
		sonic_simulation._resolve_fighter_entity_collisions()
		_check(
			is_equal_approx(float(plant.get("hp")), plant_hp_after)
				and is_equal_approx(sonic_simulation.right.hp, sonic_hp_after),
			"成熟植物接触冷却期间不会重复连续扣血"
		)

	BallRegistry.configure_settings({
		"plant": {
			"cooldown": 60.0,
			"max_plants": 1,
			"growth_delay": 0.1,
			"plant_max_hp": 30.0,
			"plant_contact_damage": 0.0,
			"sunflower_growth_weight": 1.0,
			"fire_pea_growth_weight": 0.0,
			"ice_pea_growth_weight": 0.0,
			"gatling_pea_growth_weight": 0.0,
		},
	})
	var vampire_simulation := BattleSimulationScript.new(20261204, "plant", "vampire")
	vampire_simulation.left_ability.activate(
		vampire_simulation.battle_context,
		vampire_simulation.left,
		vampire_simulation.right,
		0
	)
	var vampire_plants: Array[BallEntity] = vampire_simulation.entity_list(0, "plant_growth")
	_check(vampire_plants.size() == 1, "吸血鬼吸附测试生成一株植物")
	if not vampire_plants.is_empty():
		var victim_plant: BallEntity = vampire_plants[0]
		victim_plant.process_step(vampire_simulation.battle_context, 0.11)
		victim_plant.pos = Vector2(320.0, 320.0)
		victim_plant.set("_entity_contact_timer", 0.0)
		vampire_simulation.right.pos = victim_plant.pos + Vector2(
			victim_plant.radius + vampire_simulation.right.radius - 2.0,
			0.0
		)
		vampire_simulation.right.velocity = Vector2(-180.0, 0.0)
		vampire_simulation.right.hp = 50.0
		vampire_simulation._resolve_fighter_entity_collisions()
		_check(
			bool(vampire_simulation.right_ability.call("is_latching_entity"))
				and vampire_simulation.has_status(
					vampire_simulation.right,
					"vampire_latch_invulnerability"
				),
			"吸血鬼碰到成熟植物后启动同一套无敌吸附"
		)
		_check(
			vampire_simulation.count_entities(1, "vampire_latch_tether") == 1
				and is_equal_approx(
					vampire_simulation.right.pos.distance_to(victim_plant.pos),
					vampire_simulation.right.radius
						+ victim_plant.radius
						+ BallRegistry.get_module("vampire").settingf("latch_gap")
				),
			"植物被拖到吸血鬼口器前方并显示持续血线"
		)
		var victim_hp_before: float = float(victim_plant.get("hp"))
		vampire_simulation.right_ability.on_step(
			vampire_simulation.battle_context,
			vampire_simulation.right,
			vampire_simulation.left,
			1,
			0.61
		)
		_check(
			is_equal_approx(
				victim_hp_before - float(victim_plant.get("hp")),
				BallRegistry.get_module("vampire").settingf("latch_drain_damage")
			)
				and is_equal_approx(
					vampire_simulation.right.hp,
					50.0 + BallRegistry.get_module("vampire").settingf("latch_drain_damage")
				),
			"吸血鬼按配置周期抽取植物生命并回复自身"
		)
		for _frame in range(4):
			if not bool(vampire_simulation.right_ability.call("is_latching_entity")):
				break
			vampire_simulation.right_ability.on_step(
				vampire_simulation.battle_context,
				vampire_simulation.right,
				vampire_simulation.left,
				1,
				0.4
			)
		_check(
			not bool(vampire_simulation.right_ability.call("is_latching_entity"))
				and not vampire_simulation.has_status(
					vampire_simulation.right,
					"vampire_latch_invulnerability"
				),
			"植物吸附在配置时长后解除并清理吸血鬼无敌状态"
		)
	BallRegistry.configure_settings({})

func _check_wdc_abilities() -> void:
	var module: BallModule = BallRegistry.get_module("wdc")
	_check(module.display_name == "WDC", "WDC 使用独立公开名称并由注册表自动发现")
	for key in [
		"skill_duration",
		"damage_max",
		"weight_0_10",
		"weight_11_20",
		"weight_21_30",
		"weight_31_40",
		"weight_41_50",
		"grid_fade_duration",
		"cast_icon_duration",
	]:
		_check(module.setting_specs().has(key), "WDC 参数 %s 由自身 Schema 配置" % key)
	_check(
		module.settingf("weight_0_10") > module.settingf("weight_11_20")
			and module.settingf("weight_11_20") > module.settingf("weight_21_30")
			and module.settingf("weight_21_30") > module.settingf("weight_31_40")
			and module.settingf("weight_31_40") > module.settingf("weight_41_50"),
		"WDC 默认权重随伤害区间升高而递减"
	)
	BallRegistry.configure_settings({
		"wdc": {
			"cooldown": 60.0,
			"skill_duration": 0.2,
			"damage_max": 50,
			"weight_0_10": 0.0,
			"weight_11_20": 0.0,
			"weight_21_30": 0.0,
			"weight_31_40": 0.0,
			"weight_41_50": 1.0,
		}
	})
	var deterministic_a := BattleSimulationScript.new(20261206, "wdc", "laser")
	var deterministic_b := BattleSimulationScript.new(20261206, "wdc", "laser")
	deterministic_a.left_ability.activate(
		deterministic_a.battle_context,
		deterministic_a.left,
		deterministic_a.right,
		0
	)
	deterministic_b.left_ability.activate(
		deterministic_b.battle_context,
		deterministic_b.left,
		deterministic_b.right,
		0
	)
	var values_a: Array[int] = deterministic_a.left_ability.call("current_values")
	var values_b: Array[int] = deterministic_b.left_ability.call("current_values")
	_check(values_a.size() == 9 and values_a == values_b, "WDC 九格独立数值可按同一种子完全重放")
	for value: int in values_a:
		_check(value >= 41 and value <= 50, "WDC 单档权重覆盖时只生成 41～50 的整数伤害")
	var grids: Array[BallEntity] = deterministic_a.entity_list(0, "wdc_grid")
	_check(grids.size() == 1, "WDC 发动技能后只生成一张九宫格地图")
	if not grids.is_empty():
		var grid: BallEntity = grids[0]
		_check(not grid.is_absorbable() and not grid.can_be_captured(), "WDC 地图是非实体地形表现，不会被黑洞捕获或吞噬")
		deterministic_a.left.pos = Vector2(190.0, 100.0)
		deterministic_a.right.pos = Vector2(242.0, 100.0)
		deterministic_a.left.velocity = Vector2.ZERO
		deterministic_a.right.velocity = Vector2.ZERO
		var contact_point := (deterministic_a.left.pos + deterministic_a.right.pos) * 0.5
		_check(
			int(grid.call("cell_index_at", deterministic_a.left.pos)) == 0
				and int(grid.call("cell_index_at", contact_point)) == 1,
			"WDC 碰撞取实际接触点所在格，而不是取 WDC 球心所在格"
		)
		var expected_damage := float(grid.call("damage_at", contact_point))
		var opponent_hp_before := deterministic_a.right.hp
		deterministic_a._resolve_collision()
		_check(
			is_equal_approx(opponent_hp_before - deterministic_a.right.hp, expected_damage),
			"WDC 技能期间的真实本体碰撞伤害等于接触点九宫格数值"
		)
	for _frame in range(20):
		deterministic_a.step(BattleSimulation.FIXED_STEP)
	_check(
		not bool(deterministic_a.left_ability.call("is_grid_active"))
			and deterministic_a.count_entities(0, "wdc_grid") == 0
			and is_zero_approx(deterministic_a.left_ability.contact_damage(
				deterministic_a.battle_context,
				deterministic_a.left,
				deterministic_a.right
			)),
		"WDC 持续时间结束后清理地图并恢复为无碰撞伤害的普通球"
	)
	BallRegistry.configure_settings({})

func _check_replicator_dual_ring_formation() -> void:
	var module: BallModule = BallRegistry.get_module("replicator")
	var max_cannons := module.settingi("max_cannons")
	var inner_capacity := module.settingi("inner_ring_capacity")
	_check(max_cannons == 22, "浮游炮数量上限默认配置为 22 门")
	_check(inner_capacity == 8, "浮游炮内圈容量默认配置为 8 门")
	_check(max_cannons - inner_capacity == 14, "浮游炮外圈默认容纳其余 14 门")
	var simulation := BattleSimulationScript.new(20260906, "replicator", "laser")
	simulation.left.pos = Vector2(320.0, 320.0)
	simulation.right.pos = Vector2(580.0, 320.0)
	for _activation in range(max_cannons):
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
		module.settingf("inner_orbit_radius"),
		"内圈"
	)
	_check_circular_ring(
		outer_ring,
		simulation.left.pos,
		module.settingf("outer_orbit_radius"),
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
	simulation.take_combat_events()
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
	var volley_events := simulation.take_combat_events()
	_check(_count_combat_events(volley_events, "volley") == 1, "23 发齐射只触发一次浮游炮发射音效")
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
	var module: BallModule = BallRegistry.get_module("splitter")
	_check(module.settingi("max_clones") == 100, "分身球数量上限默认配置为 100")
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
	var split_events := simulation.take_combat_events()
	_check(_count_combat_events(split_events, "split") == 1, "一次分裂只触发一次分裂音效")
	var clones: Array[BallEntity] = simulation.entity_list(0, "splitter_clone")
	_check(clones.size() == 2, "分身球首次激活生成两个独立小球")
	_check(is_equal_approx(
		simulation.left_ability.contact_damage(simulation.battle_context, simulation.left, simulation.right),
		5.0
	), "分身球本体撞击伤害固定为 5")
	if clones.size() < 2:
		return
	var clone := clones[0]
	clones[1].pos = Vector2(580.0, 100.0)
	_check(is_equal_approx(clone.radius, module.settingf("clone_radius")), "分身读取配置中的独立碰撞半径")
	_check(is_equal_approx(float(clone.get("hp")), 10.0), "分身拥有默认 10 点独立生命值")
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
	simulation.take_combat_events()
	clone.process_step(simulation.battle_context, 0.0)
	_check(is_equal_approx(
		target_hp_before - simulation.right.hp,
		module.settingf("clone_impact_damage") * simulation.damage_scale
	), "分身撞击伤害固定为 2 并走统一伤害倍率")
	_check(is_equal_approx(float(clone.get("hp")), clone_hp_before - module.settingf("clone_impact_wear")), "分身碰撞后按配置独立掉血")
	_check(int(simulation.stats.get("clone_contact_hits", 0)) == 1, "分身碰撞拥有独立命中统计")
	_check(
		_count_combat_events(simulation.take_combat_events(), "clone_impact") == 1,
		"分身撞到敌方本体时触发独立撞击音效"
	)
	var main_contact := BattleSimulationScript.new(20260907, "splitter", "laser")
	_prepare_contact(main_contact)
	main_contact.take_combat_events()
	main_contact._resolve_collision()
	_check(
		_count_combat_events(main_contact.take_combat_events(), "ram_impact") == 1,
		"分身球本体撞到敌方球时触发较重的撞击音效"
	)
	while simulation.count_entities(0, "splitter_clone") < 4:
		simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	simulation.left_ability.after_entities_step(simulation.battle_context, simulation.left, simulation.right, 0, 0.0)
	clones = simulation.entity_list(0, "splitter_clone")
	_check(SplitterCloneEntity.HEALTH_BARS_PER_ROW == 1, "分身血条每行固定排列一个")
	for index in range(clones.size()):
		_check(int(clones[index].call("health_bar_index")) == index, "存活分身血条按紧凑顺序排列")
	clone.call("receive_collision_damage", simulation.battle_context, clone.get("max_hp"))
	_check(clone.removed and is_zero_approx(float(clone.get("hp"))), "分身生命耗尽后独立死亡")
	simulation.step(0.0)
	_check(not simulation.entities.has(clone), "死亡分身由通用实体生命周期清理")

	var mirror_simulation := BattleSimulationScript.new(20260929, "splitter", "splitter")
	mirror_simulation.left_ability.activate(
		mirror_simulation.battle_context,
		mirror_simulation.left,
		mirror_simulation.right,
		0
	)
	mirror_simulation.right_ability.activate(
		mirror_simulation.battle_context,
		mirror_simulation.right,
		mirror_simulation.left,
		1
	)
	var left_clones: Array[BallEntity] = mirror_simulation.entity_list(0, "splitter_clone")
	var right_clones: Array[BallEntity] = mirror_simulation.entity_list(1, "splitter_clone")
	_check(left_clones.size() >= 2 and right_clones.size() >= 2, "双分身球碰撞测试生成两组独立分身")
	if left_clones.size() >= 2 and right_clones.size() >= 2:
		left_clones[0].pos = Vector2(300.0, 320.0)
		right_clones[0].pos = Vector2(304.0, 320.0)
		left_clones[1].pos = Vector2(100.0, 100.0)
		right_clones[1].pos = Vector2(600.0, 500.0)
		left_clones[0].set("_contact_timer", 0.0)
		right_clones[0].set("_contact_timer", 0.0)
		mirror_simulation.left_ability.after_entities_step(
			mirror_simulation.battle_context,
			mirror_simulation.left,
			mirror_simulation.right,
			0,
			0.0
		)
		mirror_simulation.right_ability.after_entities_step(
			mirror_simulation.battle_context,
			mirror_simulation.right,
			mirror_simulation.left,
			1,
			0.0
		)
		_check(
			int(mirror_simulation.stats.get("clone_entity_contact_hits", 0)) == 1,
			"两颗分身球各自生成的分身仍跨生成组碰撞且只结算一次"
		)

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
	projectile_simulation.take_combat_events()
	projectile.process_step(projectile_simulation.battle_context, 0.2)
	_check(projectile.removed, "非穿透投射物命中分身后立即消除")
	_check(is_equal_approx(
		struck_hp_before - float(struck_clone.get("hp")),
		4.0 * projectile_simulation.damage_scale
	), "敌方投射物按统一伤害倍率扣除分身生命")
	_check(is_equal_approx(projectile_simulation.left.hp, main_hp_before), "被分身挡住的非穿透投射物不会继续命中本体")
	_check(
		_count_combat_events(projectile_simulation.take_combat_events(), "projectile_hit") == 1,
		"浮游炮投射物命中分身时触发命中音效"
	)

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
		var expected_beam_damage := minf(first_hp_before, BallRegistry.get_module("laser").settingf("laser_damage") * beam_simulation.damage_scale)
		_check(is_equal_approx(first_hp_before - float(beam_clones[0].get("hp")), expected_beam_damage), "穿透激光会扣除路径上第一个分身生命")
		_check(is_equal_approx(second_hp_before - float(beam_clones[1].get("hp")), expected_beam_damage), "穿透激光会继续命中路径上的后续分身")
		_check(is_equal_approx(float(beam_clones[2].get("hp")), off_beam_hp_before), "攻击不会主动改为追踪光束外的分身")

	var area_simulation := BattleSimulationScript.new(20260904, "splitter", "flame")
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
		var expected_contact_damage: float = minf(
			contact_hp_before,
			sonic_contact_damage * contact_simulation.damage_scale
			+ BallRegistry.get_module("splitter").settingf("clone_impact_wear")
		)
		_check(is_equal_approx(
			contact_hp_before - float(contact_clone.get("hp")),
			expected_contact_damage
		), "具备本体撞击能力的敌球碰到分身时会结算能力伤害")

func _check_black_hole_orbit_force() -> void:
	var simulation := BattleSimulationScript.new(20260822, "black_hole", "heaven")
	_check(is_equal_approx(simulation.left.cooldown, 6.3), "黑洞技能发动间隔为原来 4.2 秒的 1.5 倍")
	_check(
		is_zero_approx(BallRegistry.get_module("black_hole").settingf("orbit_inward_speed_min")),
		"黑洞径向控制不允许用负吸入速度产生斥力"
	)
	_check(is_equal_approx(
		simulation.left_ability.speed_multiplier(simulation.battle_context, simulation.left, simulation.right, 0),
		1.0
	), "黑洞技能未发动时保持正常速度")
	simulation.left.pos = Vector2(320.0, 320.0)
	simulation.right.pos = Vector2(540.0, 320.0)
	simulation.left.velocity = Vector2.ZERO
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
	var initial_outward := (simulation.right.pos - simulation.left.pos).normalized()
	_check(
		(simulation.right.velocity - simulation.left.velocity).dot(initial_outward) < 0.0,
		"黑洞把目标牵引向轨道半径"
	)
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

	var close_simulation := BattleSimulationScript.new(20260914, "black_hole", "heaven")
	close_simulation.left.pos = Vector2(320.0, 320.0)
	close_simulation.right.pos = Vector2(410.0, 320.0)
	close_simulation.left.velocity = Vector2(80.0, 35.0)
	close_simulation.right.velocity = close_simulation.left.velocity
	close_simulation.left_ability.activate(
		close_simulation.battle_context,
		close_simulation.left,
		close_simulation.right,
		0
	)
	var close_initial_distance := close_simulation.right.pos.distance_to(close_simulation.left.pos)
	var farthest_close_distance := close_initial_distance
	for _frame in range(int(ceil(2.35 / BattleSimulation.FIXED_STEP))):
		close_simulation.left_ability.before_motion(
			close_simulation.battle_context,
			close_simulation.left,
			close_simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
		close_simulation.left_ability.on_step(
			close_simulation.battle_context,
			close_simulation.left,
			close_simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
		close_simulation.left.pos += close_simulation.left.velocity * BattleSimulation.FIXED_STEP
		close_simulation.right.pos += close_simulation.right.velocity * BattleSimulation.FIXED_STEP
		farthest_close_distance = maxf(
			farthest_close_distance,
			close_simulation.right.pos.distance_to(close_simulation.left.pos)
		)
	_check(
		farthest_close_distance <= close_initial_distance + 0.01,
		"近距离目标的收缩轨道不会反向扩张"
	)
	_check(
		close_simulation.right.pos.distance_to(close_simulation.left.pos) < close_initial_distance - 4.0,
		"近距离目标仍会边绕行边靠近黑洞"
	)

func _check_black_hole_wall_damage() -> void:
	var simulation := BattleSimulationScript.new(20260823, "black_hole", "heaven")
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	simulation.right.pos = Vector2(
		simulation.arena_size().x - simulation.right.radius - 0.25,
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
	_check(int(simulation.stats.get("objects_captured", 0)) == 4, "持续区域、锚点、附属物和分身统一进入捕获轨道")
	for entity in [zone, anchor, edge_object, clone]:
		_check(entity.is_captured(), "%s 被黑洞捕获并禁用" % entity.tags[0])
		_check(entity.owner_side == 1, "%s 被捕获后保留原阵营" % entity.tags[0])
		_check(not entity.removed, "%s 被捕获后不会瞬间消失" % entity.tags[0])
	_check(zone.pos.distance_to(simulation.left.pos) < zone_distance_before, "持续区域沿收缩轨道被吸向黑洞")
	_check(anchor.pos.distance_to(simulation.left.pos) < anchor_distance_before, "敌方附属物沿收缩轨道被吸向黑洞")
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
	_check(anchor.removed, "黑洞移除范围内的敌方附属物")
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
	var second_pair := BattleSimulationScript.new(20260825, "vampire", "wdc")
	_check(is_equal_approx(second_pair.max_battle_time, 120.0), "所有球组合默认时限均为两分钟")
	var configured_battle := BattleSimulationScript.new(20260825, "splitter", "heaven", 75.0)
	_check(is_equal_approx(configured_battle.max_battle_time, 75.0), "调用方可以覆盖单局时限")

func _check_global_settings_configuration() -> void:
	var test_path := "user://ability_ball_global_settings_test.json"
	var configuration = GlobalGameSettingsScript.new({
		"battle_time_seconds": 95,
		"arena_width": 900,
		"arena_height": 500,
		"recording_fps": 48,
		"result_reveal_delay_seconds": 1.7,
	})
	_check(configuration.settingi("battle_time_seconds") == 95, "全局设置保存默认对局时限")
	_check(configuration.arena_size() == Vector2(900.0, 500.0), "全局设置保存实际竞技场宽高")
	_check(configuration.settingi("recording_fps") == 48, "全局设置保存可选录制帧率")
	_check(is_equal_approx(configuration.settingf("result_reveal_delay_seconds"), 1.7), "全局设置保存胜负揭晓延迟")
	var simulation := BattleSimulationScript.new(
		20260912,
		"splitter",
		"heaven",
		configuration.settingf("battle_time_seconds"),
		configuration.arena_size()
	)
	_check(is_equal_approx(simulation.max_battle_time, 95.0), "全局时限进入新对局")
	_check(simulation.arena_size() == Vector2(900.0, 500.0), "自定义竞技场尺寸进入模拟器")
	_check(_inside_arena(simulation.left, simulation.arena_size()), "缩放后的左侧出生点位于自定义竞技场")
	_check(_inside_arena(simulation.right, simulation.arena_size()), "缩放后的右侧出生点位于自定义竞技场")
	simulation.left.pos = Vector2(899.0, 250.0)
	simulation.left.velocity = Vector2(300.0, 0.0)
	simulation.step(BattleSimulation.FIXED_STEP)
	_check(
		simulation.left.pos.x <= simulation.arena_size().x - simulation.left.radius,
		"自定义宽度成为真实墙面碰撞边界"
	)
	var ray_end := simulation.ray_to_arena_edge(Vector2(450.0, 250.0), Vector2.RIGHT)
	_check(is_equal_approx(ray_end.x, 900.0), "射线与技能查询使用自定义竞技场边界")
	var snapshot: Dictionary = configuration.settings_snapshot()
	_check(GlobalSettingsStoreScript.save_settings(snapshot, test_path) == OK, "全局设置能够写入独立持久化文件")
	var loaded = GlobalGameSettingsScript.new(GlobalSettingsStoreScript.load_settings(test_path))
	_check(loaded.settings_snapshot() == snapshot, "全局设置保存后可以无损读回")
	var reloaded_simulation := BattleSimulationScript.new(
		20260913,
		"laser",
		"black_hole",
		loaded.settingf("battle_time_seconds"),
		loaded.arena_size()
	)
	_check(reloaded_simulation.arena_size() == Vector2(900.0, 500.0), "全局竞技场设置跨组合生效")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var normalized = GlobalGameSettingsScript.new({
		"battle_time_seconds": 2,
		"arena_width": 9999,
		"arena_height": "invalid",
		"recording_fps": 999,
		"result_reveal_delay_seconds": 99.0,
	})
	_check(normalized.settingi("battle_time_seconds") == 15, "全局时限按 Schema 下限收敛")
	_check(normalized.settingi("arena_width") == 1920, "竞技场宽度按 Schema 上限收敛")
	_check(normalized.settingi("arena_height") == 640, "非法竞技场高度恢复默认值")
	_check(normalized.settingi("recording_fps") == 120, "录制帧率按 Schema 上限收敛")
	_check(is_equal_approx(normalized.settingf("result_reveal_delay_seconds"), 5.0), "胜负揭晓延迟按 Schema 上限收敛")

func _check_visual_rng_isolation() -> void:
	var baseline := BattleSimulationScript.new(20260826, "splitter", "heaven")
	var extra_effects := BattleSimulationScript.new(20260826, "splitter", "heaven")
	extra_effects.spawn_particles(Vector2(320.0, 320.0), Color.WHITE, 100, 300.0)
	for _frame in range(600):
		baseline.step(BattleSimulation.FIXED_STEP)
		extra_effects.step(BattleSimulation.FIXED_STEP)
	_check(baseline.snapshot() == extra_effects.snapshot(), "增减纯视觉粒子不会改变游戏轨迹或胜负规则")

func _check_settings_configuration() -> void:
	var test_path := "user://ability_ball_settings_test.json"
	BallRegistry.configure_settings({
		"splitter": {
			"max_hp": 145.0,
			"max_clones": 7,
			"clone_max_hp": 25.0,
			"body_impact_damage": 9.0,
		},
		"replicator": {
			"max_cannons": 3,
			"projectile_damage": 17.0,
		},
		"black_hole": {
			"orbit_inward_speed_min": -72.0,
		},
	})
	_check(
		is_zero_approx(BallRegistry.get_module("black_hole").settingf("orbit_inward_speed_min")),
		"旧配置中的负径向速度会被归一化为零，不再恢复斥力"
	)
	var splitter_simulation := BattleSimulationScript.new(20260908, "splitter", "laser")
	_check(is_equal_approx(splitter_simulation.left.max_hp, 145.0), "自定义本体生命值进入新对局")
	var splitter_other_matchup := BattleSimulationScript.new(20260910, "splitter", "heaven")
	_check(
		is_equal_approx(splitter_other_matchup.left.max_hp, 145.0),
		"同一球切换对手后继续使用自己的配置"
	)
	_check(is_equal_approx(splitter_other_matchup.right.max_hp, 100.0), "对手继续使用自己的独立配置")
	_check(is_equal_approx(
		splitter_simulation.left_ability.contact_damage(
			splitter_simulation.battle_context,
			splitter_simulation.left,
			splitter_simulation.right
		),
		9.0
	), "自定义本体撞击伤害进入能力实例")
	for _activation in range(4):
		splitter_simulation.left_ability.activate(
			splitter_simulation.battle_context,
			splitter_simulation.left,
			splitter_simulation.right,
			0
		)
	var custom_clones := splitter_simulation.entity_list(0, "splitter_clone")
	_check(custom_clones.size() == 7, "自定义分身上限限制实际生成数量")
	if not custom_clones.is_empty():
		_check(is_equal_approx(float(custom_clones[0].get("max_hp")), 25.0), "自定义附属物生命值进入分身实体")
	var replicator_simulation := BattleSimulationScript.new(20260909, "replicator", "laser")
	for _activation in range(5):
		replicator_simulation.left_ability.activate(
			replicator_simulation.battle_context,
			replicator_simulation.left,
			replicator_simulation.right,
			0
		)
	_check(replicator_simulation.count_entities(0, "clone") == 3, "自定义浮游炮上限限制实际炮数")
	var projectiles := replicator_simulation.entity_list(0, "projectile")
	_check(
		not projectiles.is_empty()
		and is_equal_approx(float(projectiles[-1].get("damage_amount")), 17.0),
		"自定义子弹攻击力进入投射物"
	)
	var snapshot := BallRegistry.settings_snapshot()
	var save_error := BallSettingsStoreScript.save_settings(snapshot, test_path)
	_check(save_error == OK, "球参数能够写入持久化文件")
	var loaded := BallSettingsStoreScript.load_settings(test_path)
	BallRegistry.configure_settings(loaded)
	_check(BallRegistry.settings_snapshot() == snapshot, "持久化球参数经 Schema 归一化后可以无损读回")
	var reloaded_matchup := BattleSimulationScript.new(20260911, "splitter", "vampire")
	_check(is_equal_approx(reloaded_matchup.left.max_hp, 145.0), "持久化重载后球配置继续进入其他组合")
	_check(is_equal_approx(reloaded_matchup.right.max_hp, 100.0), "持久化重载不会把配置串给另一种球")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	BallRegistry.configure_settings({"splitter": {"max_hp": -5.0, "max_clones": 999}})
	_check(is_equal_approx(BallRegistry.get_module("splitter").max_hp, 1.0), "非法生命值按 Schema 下限收敛")
	_check(BallRegistry.get_module("splitter").settingi("max_clones") == 100, "非法分身上限按 Schema 上限收敛")
	BallRegistry.configure_settings({})
	for ball_id in BallRegistry.ids():
		_check(is_equal_approx(BallRegistry.get_module(ball_id).max_hp, 100.0), "%s 恢复默认后生命值为 100" % ball_id)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _count_combat_events(events: Array[Dictionary], kind: String) -> int:
	var count := 0
	for event in events:
		if String(event.get("kind", "")) == kind:
			count += 1
	return count
