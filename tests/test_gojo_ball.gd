extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const ProjectileEntityScript := preload("res://scripts/balls/core/projectile_entity.gd")

class DamageableFixtureEntity:
	extends BallEntity

	var hp := 20.0

	func _init(spawn_side: int, spawn_position: Vector2) -> void:
		owner_side = spawn_side
		pos = spawn_position
		radius = 9.0
		tags = PackedStringArray(["gojo_test_fixture"])

	func can_receive_attack(source_side: int) -> bool:
		return not removed and is_hostile_to(source_side)

	func receive_attack(
		_battle,
		amount: float,
		source_side: int,
		_hit_color: Color
	) -> float:
		if not can_receive_attack(source_side):
			return 0.0
		var applied := minf(hp, maxf(0.0, amount))
		hp -= applied
		if hp <= 0.0:
			removed = true
		return applied

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_module_contract()
	_check_voice_timing()
	_check_random_aimed_techniques()
	_check_natural_orb_forces()
	_check_force_falloff()
	_check_touching_purple_fusion()
	_check_technique_repeated_contacts()
	_check_purple_impact_explosion()
	_check_attachment_damage()
	_check_blue_attraction_red_repulsion_and_purple_erasure()
	_check_contact_and_projectile_damage()
	_check_low_hp_does_not_heal()
	_check_once_per_battle_domain_trigger()
	_check_same_team_gojo_ownership_isolation()
	_check_persistent_settings_isolation()
	_check_determinism()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_GOJO_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_GOJO_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_module_contract() -> void:
	var module: BallModule = BallRegistry.get_module("gojo")
	_check(module != null and module.display_name == "五条悟球", "五条悟球由目录模块自动发现")
	_check(is_equal_approx(module.max_hp, 100.0), "五条悟球默认生命为 100")
	_check(is_equal_approx(module.cooldown, 2.3), "五条悟球默认每 2.3 秒释放一次术式")
	for key in [
		"blue_damage", "red_damage", "purple_damage", "purple_explosion_radius", "purple_explosion_duration", "blue_cast_probability",
		"maximum_blue_orbs", "maximum_red_orbs", "maximum_purple_orbs", "orb_hit_interval",
		"blue_force_acceleration", "red_force_acceleration", "red_impact_impulse",
		"purple_erase_radius",
		"domain_minimum_elapsed", "domain_trigger_range", "domain_duration",
	]:
		_check(module.setting_specs().has(key), "五条悟球配置 Schema 包含 %s" % key)
	_check(module.ability_description.contains("苍") and module.ability_description.contains("赫") \
		and module.ability_description.contains("茈") \
		and module.ability_description.contains("无量空处"),
		"公开简介完整说明术式与领域")
	var audio_samples := module.audio_samples()
	_check(audio_samples.size() == 4, "四种主动招式各自声明独立纯人声采样")
	_check(not audio_samples.has("gojo_domain_bgm"), "五条悟球不再注册领域背景音乐")
	var ability: BallAbility = module.create_ability()
	_check(is_zero_approx(ability.contact_damage(null, null, null)), "五条悟球普通本体碰撞无伤害")
	_check(module.create_visual(ability) is BallVisual, "五条悟球装载独立角色视觉")

func _check_voice_timing() -> void:
	var samples: Dictionary = BallRegistry.get_module("gojo").audio_samples()
	var expected := {
		"gojo_blue_voice": {"minimum": 0.8, "maximum": 1.0, "gain_db": -9.0},
		"gojo_red_voice": {"minimum": 0.8, "maximum": 1.0, "gain_db": -9.0},
		"gojo_purple_voice": {"minimum": 0.8, "maximum": 1.0, "gain_db": -8.0},
		"gojo_domain_voice": {"minimum": 0.8, "maximum": 1.0, "gain_db": -7.0},
	}
	for event_kind: String in expected:
		var spec: Dictionary = samples.get(event_kind, {})
		var stream := spec.get("stream") as AudioStreamOggVorbis
		_check(stream != null, "%s 装载独立原声采样" % event_kind)
		if stream == null:
			continue
		var limits: Dictionary = expected[event_kind]
		_check(stream.get_length() >= float(limits.minimum) \
			and stream.get_length() <= float(limits.maximum),
			"%s 的导入音频时长在 0.8 秒至 1 秒之间" % event_kind)
		_check(not stream.loop and not bool(spec.get("loop", false)),
			"%s 只播放一次，不循环" % event_kind)
		_check(is_equal_approx(float(spec.get("gain_db", 0.0)), float(limits.gain_db)),
			"%s 保持原事件混音音量" % event_kind)

func _spawn_orb(simulation, kind: String) -> BallEntity:
	return simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("_spawn_technique_orb",
		simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, kind)

func _check_random_aimed_techniques() -> void:
	BallRegistry.configure_settings({})
	var sequence: Array[String] = []
	var simulation := BattleSimulationScript.new(20261013, "gojo", "test_ball")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(320.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(550.0, 320.0)
	var has_repeat := false
	for index in range(32):
		for orb: BallEntity in simulation.entity_list(0, "gojo_technique_orb"):
			orb.pos = Vector2(100.0, 320.0)
		simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0)
		var kind: String = simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("last_cast_kind")
		sequence.append(kind)
		var orbs := simulation.entity_list(0, "gojo_orb_%s" % kind)
		var emitted: BallEntity = orbs.back()
		_check(emitted.velocity.normalized().is_equal_approx(Vector2.RIGHT),
			"苍赫均瞄准敌人，不转向背后的己方术式")
		_check(emitted.pos.x > simulation.fighter_for_side(simulation.teams[0].team_id).pos.x, "术式在朝敌人的一侧出生")
		if index > 0 and sequence[index - 1] == kind:
			has_repeat = true
	_check(sequence.has("blue") and sequence.has("red") and has_repeat,
		"默认随机序列包含苍赫和连续同招，不固定交替")
	var replay := BattleSimulationScript.new(20261013, "gojo", "test_ball")
	for kind: String in sequence:
		replay._ability_for_fighter(replay.fighter_for_side(replay.teams[0].team_id)).activate(replay.battle_context, replay.fighter_for_side(replay.teams[0].team_id), replay.fighter_for_side(replay.teams[1].team_id), 0)
		_check(replay._ability_for_fighter(replay.fighter_for_side(replay.teams[0].team_id)).call("last_cast_kind") == kind, "同种子随机出招可重放")
	for probability in [0.0, 1.0]:
		BallRegistry.configure_settings({"gojo": {"blue_cast_probability": probability}})
		var configured := BattleSimulationScript.new(57, "gojo", "test_ball")
		for _index in range(4):
			configured._ability_for_fighter(configured.fighter_for_side(configured.teams[0].team_id)).activate(configured.battle_context, configured.fighter_for_side(configured.teams[0].team_id), configured.fighter_for_side(configured.teams[1].team_id), 0)
			_check(configured._ability_for_fighter(configured.fighter_for_side(configured.teams[0].team_id)).call("last_cast_kind") == ("blue" if probability == 1.0 else "red"),
				"苍释放概率边界配置有效")

func _check_natural_orb_forces() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20261014, "gojo", "test_ball")
	var blue := _spawn_orb(simulation, "blue")
	var red := _spawn_orb(simulation, "red")
	var second_red := _spawn_orb(simulation, "red")
	var second_blue := _spawn_orb(simulation, "blue")
	var far_red := _spawn_orb(simulation, "red")
	var captured_red := _spawn_orb(simulation, "red")
	var ally_red := _spawn_orb(simulation, "red")
	ally_red.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
	blue.pos = Vector2(250.0, 320.0)
	red.pos = Vector2(310.0, 320.0)
	second_red.pos = Vector2(350.0, 320.0)
	second_blue.pos = Vector2(290.0, 320.0)
	far_red.pos = Vector2(580.0, 320.0)
	captured_red.pos = Vector2(330.0, 320.0)
	ally_red.pos = Vector2(340.0, 320.0)
	captured_red.disable_for_capture()
	var orbs := [blue, red, second_red, second_blue, far_red, captured_red, ally_red]
	for orb: BallEntity in orbs:
		orb.velocity = Vector2.ZERO
	blue.process_step(simulation.battle_context, 0.02)
	_check(red.velocity.x < 0.0 and second_red.velocity.x < 0.0 and second_blue.velocity.x < 0.0,
		"苍同时吸引范围内所有自己的苍赫，不挑最近目标配对")
	_check(far_red.velocity == Vector2.ZERO, "范围外的赫不受远程融合牵引")
	_check(captured_red.velocity == Vector2.ZERO and ally_red.velocity == Vector2.ZERO,
		"自己的力场不会拉动被捕获术式或队友术式")
	for orb: BallEntity in orbs:
		orb.velocity = Vector2.ZERO
	red.process_step(simulation.battle_context, 0.02)
	_check(blue.velocity.x < 0.0 and second_blue.velocity.x < 0.0 and second_red.velocity.x > 0.0,
		"赫自然排斥两侧范围内的苍赫，不把苍拉向自己")
	_check(far_red.velocity == Vector2.ZERO and captured_red.velocity == Vector2.ZERO \
		and ally_red.velocity == Vector2.ZERO, "赫同样遵守范围、捕获与归属边界")
	for orb: BallEntity in orbs:
		orb.velocity = Vector2.ZERO
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, 0.02)
	for orb: BallEntity in orbs:
		_check(orb.velocity == Vector2.ZERO, "能力计时不额外改变术式轨迹")

func _check_touching_purple_fusion() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270891, "gojo", "test_ball")
	var blue := _spawn_orb(simulation, "blue")
	var red := _spawn_orb(simulation, "red")
	blue.pos = Vector2(410.0, 320.0)
	red.pos = blue.pos + Vector2(blue.radius + red.radius + 1.0, 0.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_entities_step(simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, BattleSimulation.FIXED_STEP)
	_check(simulation.count_entities(0, "gojo_orb_purple") == 0, "苍赫未接触时不能提前融合")
	red.pos = blue.pos + Vector2(blue.radius + red.radius, 0.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_entities_step(simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, BattleSimulation.FIXED_STEP)
	_check(blue.removed and red.removed, "融合消耗真正相撞的苍赫")
	_check(simulation.count_entities(0, "gojo_orb_purple") == 1, "实际接触后生成一枚茈")
	_check(int(simulation.stats.get("gojo_purple_fusions", 0)) == 1, "红蓝融合只记录一次")
	var purple: BallEntity = simulation.entity_list(0, "gojo_orb_purple")[0]
	_check(purple.is_absorbable() and not purple.can_transfer_ownership(), "茈可被黑洞吞噬但不能被尤里控制")

func _check_force_falloff() -> void:
	BallRegistry.configure_settings({})
	for kind in ["blue", "red"]:
		var simulation := BattleSimulationScript.new(20261016, "gojo", "test_ball")
		var orb := _spawn_orb(simulation, kind)
		orb.pos = Vector2(320.0, 320.0)
		orb.velocity = Vector2.ZERO
		simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(600.0, 600.0)
		var near := DamageableFixtureEntity.new(1, orb.pos + Vector2(40.0, 0.0))
		var edge := DamageableFixtureEntity.new(1, orb.pos + Vector2(140.0, 0.0))
		var outside := DamageableFixtureEntity.new(1, orb.pos + Vector2(220.0, 0.0))
		for target in [near, edge, outside]:
			simulation.add_entity(target)
		orb.process_step(simulation.battle_context, 0.05)
		_check(near.velocity.length() > edge.velocity.length() and edge.velocity.length() > 0.0,
			"苍赫力场在中心较强、靠边缘更弱")
		_check(outside.velocity == Vector2.ZERO, "范围外的目标不会被苍赫力场推动")
		var upper_bound := simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("%s_force_acceleration" % kind) * 0.05
		_check(near.velocity.length() <= upper_bound, "力场实际加速不会超过配置强度")
		_check(near.velocity.x < 0.0 if kind == "blue" else near.velocity.x > 0.0,
			"减弱后的力场仍分别保持引力和斥力方向")

func _check_technique_repeated_contacts() -> void:
	BallRegistry.configure_settings({})
	for kind in ["blue", "red"]:
		var simulation := BattleSimulationScript.new(20270892, "gojo", "test_ball")
		var orb := _spawn_orb(simulation, kind)
		simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(500.0, 250.0)
		var fixture := DamageableFixtureEntity.new(1, Vector2(500.0, 430.0))
		fixture.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
		simulation.add_entity(fixture)
		var amount := simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("%s_damage" % kind)
		for target in [simulation.fighter_for_side(simulation.teams[1].team_id), fixture]:
			var hp_before: float = target.hp
			_drive_orb_into(orb, target, simulation.battle_context)
			_check(is_equal_approx(hp_before - target.hp, amount), "苍赫首次接触主球或附属物正常造成伤害")
			_drive_orb_into(orb, target, simulation.battle_context)
			_check(is_equal_approx(hp_before - target.hp, amount), "命中间隔内再次接触同一目标不会重复扣血")
			_rest_orb(orb, simulation.battle_context, 0.4)
			_drive_orb_into(orb, target, simulation.battle_context)
			_check(is_equal_approx(hp_before - target.hp, amount * 2.0), "同一枚苍赫分开后再次撞击同一目标可以继续伤害")
			_rest_orb(orb, simulation.battle_context, 0.4)
			orb.pos = target.pos - Vector2(target.radius + orb.radius + 3.0, 0.0)
			orb.velocity = Vector2(400.0, 0.0)
			orb.process_step(simulation.battle_context, 0.0075)
			orb.velocity = Vector2.ZERO
			orb.process_step(simulation.battle_context, 0.5)
			_check(is_equal_approx(hp_before - target.hp, amount * 3.0), "持续贴住目标即使命中间隔已过也不会连续扣血")
			_rest_orb(orb, simulation.battle_context, 0.01)
			_drive_orb_into(orb, target, simulation.battle_context)
			_check(is_equal_approx(hp_before - target.hp, amount * 4.0), "重新脱离接触后仍可继续命中主球或附属物")
		_check(not orb.removed, "苍赫重复命中后仍留在场上")
		orb.pos = Vector2(orb.radius + 2.0, 180.0)
		orb.velocity = Vector2(-245.0, 0.0)
		orb.process_step(simulation.battle_context, 0.05)
		_check(not orb.removed and orb.velocity.x > 0.0, "苍赫仍可撞墙反弹")

func _rest_orb(orb: BallEntity, battle, duration: float) -> void:
	orb.pos = Vector2(160.0, 100.0)
	orb.velocity = Vector2.ZERO
	orb.process_step(battle, duration)

func _make_purple(simulation) -> BallEntity:
	var blue := _spawn_orb(simulation, "blue")
	var red := _spawn_orb(simulation, "red")
	blue.pos = Vector2(320.0, 240.0)
	red.pos = blue.pos
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_entities_step(simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0, BattleSimulation.FIXED_STEP)
	return simulation.entity_list(0, "gojo_orb_purple")[0]

func _check_purple_impact_explosion() -> void:
	BallRegistry.configure_settings({})
	for hit_attachment in [false, true]:
		var simulation := BattleSimulationScript.new(20261014, "gojo", "test_ball")
		var purple := _make_purple(simulation)
		simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(100.0, 100.0)
		simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(500.0, 300.0)
		simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2.ZERO
		var direct := DamageableFixtureEntity.new(1, Vector2(350.0, 300.0))
		if hit_attachment:
			simulation.add_entity(direct)
		var target = direct if hit_attachment else simulation.fighter_for_side(simulation.teams[1].team_id)
		var nearby := DamageableFixtureEntity.new(1, target.pos + Vector2(0.0, 150.0))
		var outside := DamageableFixtureEntity.new(1, Vector2(600.0, 570.0))
		var allied := DamageableFixtureEntity.new(0, nearby.pos)
		for fixture in [nearby, outside, allied]:
			simulation.add_entity(fixture)
		purple.pos = target.pos - Vector2(100.0, 0.0)
		purple.velocity = Vector2(2000.0, 0.0)
		var hp_before: float = target.hp
		simulation.take_combat_events()
		purple.process_step(simulation.battle_context, 0.2)
		_check(purple.removed and purple.velocity == Vector2.ZERO, "紫首次命中后立即消失并停止飞行")
		_check(is_equal_approx(hp_before - target.hp, 18.0), "直接目标只承受一次爆炸伤害，不叠加直击")
		_check(is_equal_approx(nearby.hp, 2.0), "扩大后的爆炸能伤害远处敌方附属物")
		_check(is_equal_approx(outside.hp, 20.0) and is_equal_approx(allied.hp, 20.0), "爆炸不伤害范围外目标或友军")
		if hit_attachment:
			_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).hp, simulation.fighter_for_side(simulation.teams[1].team_id).max_hp - 18.0), "附属物先触发爆炸，后方范围内主球承受一次溅射")
		_check(int(simulation.stats.get("gojo_purple_explosions", 0)) == 1, "一次碰撞只触发一次爆炸")
		var effects := simulation.entity_list(0, "gojo_purple_explosion_vfx")
		_check(effects.size() == 1, "紫命中时生成独立爆炸演出")
		if effects.size() == 1:
			var effect: BallEntity = effects[0]
			_check(effect.draw_layer <= 0 and not effect.is_absorbable() and not effect.can_be_captured(),
				"爆炸演出不遮挡本体，不参与吞噬或捕获")
			effect.process_lifetime(0.9)
			_check(not effect.removed, "爆炸经过明显停留后仍可见")
			effect.process_lifetime(0.6)
			_check(effect.removed, "爆炸演出在配置时长后清理")
		_check(_count_combat_events(simulation.take_combat_events(), "projectile_hit") == 1, "爆炸只播放一次命中音")
		purple.process_step(simulation.battle_context, 0.2)
		_check(is_equal_approx(target.hp, hp_before - 18.0) and is_equal_approx(nearby.hp, 2.0), "消失的紫不残留重复伤害")
		_check(int(simulation.stats.get("gojo_purple_explosions", 0)) == 1, "消失后不再触发爆炸")
	var lifecycle := BattleSimulationScript.new(20261015, "gojo", "test_ball")
	var wall_orb := _make_purple(lifecycle)
	wall_orb.pos = Vector2(wall_orb.radius + 1.0, 100.0)
	wall_orb.velocity = Vector2(-365.0, 0.0)
	wall_orb.process_step(lifecycle.battle_context, 0.01)
	_check(not wall_orb.removed and wall_orb.velocity.x > 0.0, "紫未命中敌人时仍可撞墙反弹")
	wall_orb.remaining = 0.001
	wall_orb.process_step(lifecycle.battle_context, 0.01)
	_check(wall_orb.removed and int(lifecycle.stats.get("gojo_purple_explosions", 0)) == 0, "自然到期直接清理，不凭空爆炸")
	var captured := _make_purple(lifecycle)
	captured.disable_for_capture()
	captured.pos = lifecycle.fighter_for_side(lifecycle.teams[1].team_id).pos
	captured.process_step(lifecycle.battle_context, 0.1)
	_check(int(lifecycle.stats.get("gojo_purple_explosions", 0)) == 0, "被捕获的紫不会引爆")
	var resolved := BattleSimulationScript.new(20261016, "gojo", "test_ball")
	resolved.fighter_for_side(resolved.teams[1].team_id).pos = Vector2(400.0, 320.0)
	resolved.fighter_for_side(resolved.teams[1].team_id).hp = 18.0
	var fatal := _make_purple(resolved)
	fatal.pos = Vector2(340.0, 320.0)
	fatal.velocity = Vector2(400.0, 0.0)
	fatal.process_step(resolved.battle_context, 0.1)
	for _frame in range(100):
		resolved.step(BattleSimulation.FIXED_STEP)
	_check(resolved.finished and resolved.count_entities(0, "gojo_purple_explosion_vfx") == 0,
		"击杀结束对局后爆炸仍会自然消散并清理")

func _drive_orb_into(orb: BallEntity, target, battle) -> void:
	orb.pos = target.pos - Vector2(target.radius + orb.radius + 3.0, 0.0)
	orb.velocity = Vector2(400.0, 0.0)
	orb.process_step(battle, 0.05)

func _check_attachment_damage() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270893, "gojo", "test_ball")
	var blue := _spawn_orb(simulation, "blue")
	var fixture := DamageableFixtureEntity.new(1, Vector2(430.0, 300.0))
	fixture.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
	simulation.add_entity(fixture)
	blue.pos = fixture.pos - Vector2(fixture.radius + blue.radius + 3.0, 0.0)
	blue.velocity = Vector2(245.0, 0.0)
	blue.process_step(simulation.battle_context, 0.05)
	_check(is_equal_approx(fixture.hp, 18.0), "苍同样命中并伤害敌方附属单位")
	_check(not blue.removed, "苍被附属单位阻挡后仍按持续弹射规则存在")

func _check_blue_attraction_red_repulsion_and_purple_erasure() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270901, "gojo", "test_ball")
	var blue := _spawn_orb(simulation, "blue")
	blue.pos = Vector2(360.0, 320.0)
	blue.velocity = Vector2.ZERO
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(470.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(0.0, 188.0)
	blue.process_step(simulation.battle_context, 0.1)
	_check(simulation.fighter_for_side(simulation.teams[1].team_id).velocity.x < -1.0, "苍在命中前就持续把敌方主球拉向自身")
	var fixture := DamageableFixtureEntity.new(1, Vector2(455.0, 350.0))
	fixture.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
	fixture.velocity = Vector2(0.0, 80.0)
	simulation.add_entity(fixture)
	blue.process_step(simulation.battle_context, 0.1)
	_check(fixture.velocity.x < -1.0, "苍的引力同样作用于敌方附属单位")
	var red := _spawn_orb(simulation, "red")
	red.pos = Vector2(360.0, 320.0)
	red.velocity = Vector2.ZERO
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(470.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(0.0, 188.0)
	red.process_step(simulation.battle_context, 0.1)
	_check(simulation.fighter_for_side(simulation.teams[1].team_id).velocity.x > 1.0, "赫在命中前持续向外排斥敌方主球")
	blue.pos = Vector2(350.0, 250.0)
	red.pos = blue.pos
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_entities_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	var purple: BallEntity = simulation.entity_list(0, "gojo_orb_purple")[0]
	var hostile_projectile: BallEntity = ProjectileEntityScript.new(
		1,
		purple.pos + Vector2(8.0, 0.0),
		Vector2(-120.0, 0.0),
		4.0,
		5.0,
		Color("ff5d5d"),
		2.0,
		"gojo_purple_erase_fixture"
	)
	hostile_projectile.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
	simulation.add_entity(hostile_projectile)
	purple.process_step(simulation.battle_context, 0.01)
	_check(hostile_projectile.removed, "茈会抹除毁灭半径内的敌方投射物")

func _check_contact_and_projectile_damage() -> void:
	BallRegistry.configure_settings({"wdc": {
		"weight_0_10": 0.0, "weight_11_20": 0.0, "weight_21_30": 0.0,
		"weight_31_40": 0.0, "weight_41_50": 1.0,
	}})
	for gojo_on_left in [true, false]:
		var simulation := BattleSimulationScript.new(
			20270894, "gojo" if gojo_on_left else "wdc", "wdc" if gojo_on_left else "gojo"
		)
		var gojo = simulation.fighter_for_side(simulation.teams[0].team_id) if gojo_on_left else simulation.fighter_for_side(simulation.teams[1].team_id)
		var wdc = simulation.fighter_for_side(simulation.teams[1].team_id) if gojo_on_left else simulation.fighter_for_side(simulation.teams[0].team_id)
		var gojo_ability: BallAbility = simulation.ability_for_fighter(gojo)
		var wdc_ability: BallAbility = simulation.ability_for_fighter(wdc)
		gojo.pos = Vector2(300.0, 320.0)
		wdc.pos = gojo.pos + Vector2(50.0, 0.0)
		gojo.velocity = Vector2(180.0, 0.0)
		wdc.velocity = Vector2(-260.0, 0.0)
		var hostile: BallEntity = ProjectileEntityScript.new(
			wdc.team_id, gojo.pos + Vector2(70.0, 0.0), Vector2(-300.0, 0.0),
			5.0, 8.0, Color("ff6b55"), 3.0, "gojo_test_hostile"
		)
		hostile.owner_fighter_uid = wdc.fighter_uid
		simulation.add_entity(hostile)
		gojo_ability.before_motion(simulation.battle_context, gojo, wdc, gojo.team_id, BattleSimulation.FIXED_STEP)
		_check(wdc.velocity == Vector2(-260.0, 0.0), "敌方主球接近五条悟时保持自身速度")
		_check(hostile.velocity == Vector2(-300.0, 0.0), "敌方投射物接近五条悟时保持自身速度")
		wdc_ability.activate(simulation.battle_context, wdc, gojo, wdc.team_id)
		var expected_damage := wdc_ability.contact_damage(simulation.battle_context, wdc, gojo)
		var gojo_hp: float = gojo.hp
		var wdc_hp: float = wdc.hp
		simulation._resolve_fighter_pair(simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id))
		_check(expected_damage > 0.0 and is_equal_approx(gojo_hp - gojo.hp, expected_damage),
			"五条悟在任一阵营均完整承受 WDC 接触格的撞击伤害")
		_check(is_equal_approx(wdc.hp, wdc_hp), "五条悟普通本体碰撞不会对 WDC 造成伤害")
		gojo_hp = gojo.hp
		hostile.process_step(simulation.battle_context, 0.25)
		_check(hostile.removed and is_equal_approx(gojo_hp - gojo.hp, 8.0),
			"近身敌人发射的投射物命中五条悟后正常扣血并消失")
	BallRegistry.configure_settings({})

func _check_low_hp_does_not_heal() -> void:
	BallRegistry.configure_settings({"gojo": {"domain_minimum_elapsed": 120.0}})
	var simulation := BattleSimulationScript.new(20270902, "gojo", "test_ball")
	simulation.fighter_for_side(simulation.teams[0].team_id).ability_timer = 100.0
	simulation.fighter_for_side(simulation.teams[1].team_id).ability_timer = 100.0
	for hp in [40.0, 35.0, 20.0, 1.0]:
		simulation.fighter_for_side(simulation.teams[0].team_id).hp = hp
		for _frame in range(60):
			simulation.step(BattleSimulation.FIXED_STEP)
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).hp, hp), "五条悟降至不同低血量后均不会自动回血")
	_check(is_zero_approx(float(simulation.stats["healing"])), "低血量不会产生治疗结算")
	_check(_count_combat_events(simulation.take_combat_events(), "healing") == 0, "低血量不会播放治疗音效")

func _check_once_per_battle_domain_trigger() -> void:
	BallRegistry.configure_settings({
		"gojo": {
			"domain_minimum_elapsed": 0.0,
			"domain_trigger_range": 1000.0,
			"domain_radius": 260.0,
			"domain_duration": 0.6,
			"domain_damage_per_tick": 2.0,
			"domain_tick_interval": 0.1,
		},
	})
	var domain_simulation := BattleSimulationScript.new(20270903, "gojo", "test_ball")
	domain_simulation.fighter_for_side(domain_simulation.teams[0].team_id).pos = Vector2(300.0, 320.0)
	domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id).pos = Vector2(450.0, 320.0)
	domain_simulation.take_combat_events()
	domain_simulation._ability_for_fighter(domain_simulation.fighter_for_side(domain_simulation.teams[0].team_id)).on_step(
		domain_simulation.battle_context,
		domain_simulation.fighter_for_side(domain_simulation.teams[0].team_id),
		domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(bool(domain_simulation._ability_for_fighter(domain_simulation.fighter_for_side(domain_simulation.teams[0].team_id)).call("unlimited_void_used")), "敌人进入触发距离后展开一次无量空处")
	_check(domain_simulation.count_entities(0, "gojo_unlimited_void") == 1, "无量空处生成真实持续领域")
	var domain_audio_events := domain_simulation.take_combat_events()
	_check(
		_count_combat_events(domain_audio_events, "gojo_domain_voice") == 1,
		"领域展开时播放无量空处纯人声语音"
	)
	_check(_count_combat_events(domain_audio_events, "gojo_domain_bgm") == 0,
		"领域展开不再启动任何背景音乐")
	var domain: BallEntity = domain_simulation.entity_list(0, "gojo_unlimited_void")[0]
	domain.process_step(domain_simulation.battle_context, 0.01)
	_check(domain_simulation.battle_context.has_status(domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id), "gojo_unlimited_void"), "领域给敌方主球施加行动压制状态")
	var position_before: Vector2 = domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id).pos
	var hp_before: float = domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id).hp
	domain_simulation.step(0.05)
	domain_simulation.step(0.05)
	_check(domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id).pos.distance_to(position_before) < 2.0, "无量空处让敌方主球近乎停滞")
	_check(domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id).hp < hp_before, "无量空处按间隔持续造成伤害")
	domain_simulation._ability_for_fighter(domain_simulation.fighter_for_side(domain_simulation.teams[0].team_id)).on_step(
		domain_simulation.battle_context,
		domain_simulation.fighter_for_side(domain_simulation.teams[0].team_id),
		domain_simulation.fighter_for_side(domain_simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(domain_simulation.count_entities(0, "gojo_unlimited_void") == 1, "无量空处一局只能展开一次")
	_check(_count_combat_events(domain_simulation.take_combat_events(), "gojo_domain_bgm") == 0,
		"后续领域判定同样不会产生背景音乐事件")

func _check_same_team_gojo_ownership_isolation() -> void:
	BallRegistry.configure_settings({})
	var setup = BattleSetupScript.team_brawl(["gojo", "gojo"], ["test_ball"])
	var simulation := BattleSimulationScript.new(20270898, setup, 30.0, Vector2(720.0, 640.0))
	var allies := simulation.fighters_for_team(0)
	_check(allies.size() == 2, "双方大混战可同时生成两个同阵营五条悟球")
	var first_ability: BallAbility = simulation.ability_for_fighter(allies[0])
	var second_ability: BallAbility = simulation.ability_for_fighter(allies[1])
	var enemy = simulation.fighters_for_team(1)[0]
	first_ability.call("_spawn_technique_orb", simulation.battle_context, allies[0], enemy, 0, "blue")
	second_ability.call("_spawn_technique_orb", simulation.battle_context, allies[1], enemy, 0, "blue")
	first_ability.call("_spawn_technique_orb", simulation.battle_context, allies[0], enemy, 0, "red")
	var first_blue: BallEntity = null
	var second_blue: BallEntity = null
	var first_red: BallEntity = null
	for orb: BallEntity in simulation.entity_list(0, "gojo_orb_blue"):
		if orb.owner_fighter_uid == allies[0].fighter_uid:
			first_blue = orb
		elif orb.owner_fighter_uid == allies[1].fighter_uid:
			second_blue = orb
	for orb: BallEntity in simulation.entity_list(0, "gojo_orb_red"):
		if orb.owner_fighter_uid == allies[0].fighter_uid:
			first_red = orb
	_check(first_blue != null and second_blue != null and first_red != null, "同队双方术式实体均保留真实创建者归属")
	if first_blue == null or second_blue == null or first_red == null:
		return
	first_blue.pos = Vector2(360.0, 300.0)
	first_red.pos = first_blue.pos
	second_blue.pos = first_blue.pos
	first_ability.after_entities_step(
		simulation.battle_context,
		allies[0],
		enemy,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(not second_blue.removed, "一名五条悟的红蓝融合不会吃掉队友的苍")
	var purple_orbs := simulation.entity_list(0, "gojo_orb_purple")
	_check(
		purple_orbs.size() == 1 and purple_orbs[0].owner_fighter_uid == allies[0].fighter_uid,
		"融合生成的茈仍归触发融合的具体主球所有"
	)

func _check_persistent_settings_isolation() -> void:
	BallRegistry.configure_settings({
		"gojo": {
			"max_hp": 188.0,
			"speed": 322.0,
			"radius": 35.0,
			"cooldown": 1.15,
			"purple_damage": 27.0,
			"blue_cast_probability": 0.7,
			"purple_explosion_radius": 115.0,
		},
	})
	var wdc_match := BattleSimulationScript.new(20270895, "gojo", "wdc")
	var plant_match := BattleSimulationScript.new(20270896, "gojo", "plant")
	for simulation in [wdc_match, plant_match]:
		_check(is_equal_approx(simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("blue_cast_probability"), 0.7), "随机出招概率跨对手保持一致")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).max_hp, 188.0), "五条悟球生命配置跨对手保持一致")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).base_speed, 322.0), "五条悟球速度配置跨对手保持一致")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).radius, 35.0), "五条悟球体积配置跨对手保持一致")
		_check(is_equal_approx(simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("purple_damage"), 27.0), "茈伤害配置跨对手保持一致")
		_check(is_equal_approx(simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("purple_explosion_radius"), 115.0), "茈爆炸半径配置跨对手保持一致")
	_check(is_equal_approx(wdc_match.fighter_for_side(wdc_match.teams[1].team_id).max_hp, 100.0), "五条悟球配置不会串改 WDC")
	_check(is_equal_approx(plant_match.fighter_for_side(plant_match.teams[1].team_id).max_hp, 100.0), "五条悟球配置不会串改植物球")

func _check_determinism() -> void:
	BallRegistry.configure_settings({})
	var first := BattleSimulationScript.new(20270897, "gojo", "plant")
	var replay := BattleSimulationScript.new(20270897, "gojo", "plant")
	for _frame in range(1500):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
		if first.finished and replay.finished:
			break
	_check(first.snapshot() == replay.snapshot(), "五条悟球相同种子和配置可完全重放")
	_check(
		first.count_entities(0, "gojo_technique_orb") == replay.count_entities(0, "gojo_technique_orb"),
		"确定性重放保持相同的术式球数量"
	)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _count_combat_events(events: Array[Dictionary], kind: String) -> int:
	var count := 0
	for event: Dictionary in events:
		if String(event.get("kind", "")) == kind:
			count += 1
	return count
