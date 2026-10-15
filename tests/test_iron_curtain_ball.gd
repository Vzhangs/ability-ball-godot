extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

class DamageableFixtureEntity:
	extends BallEntity

	var hp := 20.0

	func _init(spawn_side: int, spawn_position: Vector2) -> void:
		owner_side = spawn_side
		pos = spawn_position
		radius = 9.0
		tags = PackedStringArray(["iron_curtain_test_fixture"])

	func can_receive_attack(source_side: int) -> bool:
		return source_side != owner_side

	func receive_attack(_battle, amount: float, _source_side: int, _hit_color: Color) -> float:
		var applied := minf(hp, maxf(0.0, amount))
		hp -= applied
		if hp <= 0.0:
			removed = true
		return applied

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	_check_default_contract()
	_check_protection_field_and_attachment_invulnerability()
	_check_transformation_projectile_and_universal_hazard()
	_check_transform_world_stop()
	_check_determinism()
	_check_representative_matchups()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_IRON_CURTAIN_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_IRON_CURTAIN_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_default_contract() -> void:
	var module: BallModule = BallRegistry.get_module("iron_curtain")
	_check(module != null and module.display_name == "铁龙球", "铁龙球作为一阶段由注册表自动发现并使用公开名称")
	_check(module.setting_specs().size() == 27, "铁龙球的基础、铁幕、变身、粒子炮与失控区域数值全部进入独立 Schema")
	_check(is_equal_approx(module.max_hp, 100.0), "铁龙球默认生命为 100")
	_check(is_equal_approx(module.cooldown, 7.0), "二阶段圆形铁幕默认每 7 秒释放")
	_check(is_equal_approx(module.settingf("dragon_fire_interval"), 3.6), "一阶段铁龙粒子炮默认每 3.6 秒发射")
	_check(is_equal_approx(module.settingf("invulnerability_duration"), 3.0), "友军无敌默认持续 3 秒")
	_check(is_equal_approx(module.settingf("hazard_damage_interval"), 0.5), "失控铁幕默认每 0.5 秒结算")
	_check(is_equal_approx(module.settingf("hazard_damage"), 2.0), "失控铁幕默认每次造成 2 点伤害")
	_check(is_equal_approx(module.settingf("projectile_impact_damage"), 10.0), "铁龙大型能量弹默认直接造成 10 点伤害")
	_check(is_equal_approx(module.settingf("transform_world_stop_duration"), 1.0), "铁龙变为铁幕时默认停止整个战场 1 秒")
	_check(module.sound_kind.is_empty(), "双形态技能不再通过同一个自动激活音冒充两种声音")
	_check(module.audio_samples().has("iron_curtain_activation"), "模块注册红警铁幕激活短采样")
	var audio_spec: Dictionary = module.audio_samples()["iron_curtain_activation"]
	var stream := audio_spec.get("stream") as AudioStream
	_check(stream != null and stream.get_length() > 1.7 and stream.get_length() < 2.0, "铁幕音效使用约 1.85 秒的短采样")
	_check(is_equal_approx(float(audio_spec.get("gain_db")), -19.0), "铁幕展开声从原增益单独降低 5 dB")
	_check(module.audio_samples().has("iron_dragon_fire"), "铁龙粒子炮注册独立于铁幕展开的发射音效")
	var fire_audio_spec: Dictionary = module.audio_samples()["iron_dragon_fire"]
	var fire_stream := fire_audio_spec.get("stream") as AudioStream
	_check(fire_stream != null and fire_stream.get_length() > 0.55 and fire_stream.get_length() < 0.7, "铁龙开炮使用约 0.62 秒的短促粒子炮采样")
	_check(module.audio_samples().has("iron_curtain_transform"), "铁龙变为铁幕拥有独立于周期技能的专用音频事件")
	var transform_audio_spec: Dictionary = module.audio_samples()["iron_curtain_transform"]
	var transform_stream := transform_audio_spec.get("stream") as AudioStream
	_check(
		transform_stream != null
		and transform_stream.get_length() > 1.3
		and transform_stream.get_length() < 1.7,
		"铁龙变为铁幕使用约 1.5 秒的低沉铁幕能量采样"
	)
	var ability: BallAbility = module.create_ability()
	_check(is_zero_approx(ability.contact_damage(null, null, null)), "铁龙球与铁幕球的普通本体碰撞都不造成伤害")

func _check_protection_field_and_attachment_invulnerability() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270881, "iron_curtain", "test_ball")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(260.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = simulation.fighter_for_side(simulation.teams[0].team_id).pos + Vector2(70.0, 0.0)
	var allied_attachment := DamageableFixtureEntity.new(0, simulation.fighter_for_side(simulation.teams[0].team_id).pos + Vector2(35.0, 0.0))
	var hostile_attachment := DamageableFixtureEntity.new(1, simulation.fighter_for_side(simulation.teams[0].team_id).pos + Vector2(-42.0, 0.0))
	simulation.add_entity(allied_attachment)
	simulation.add_entity(hostile_attachment)
	simulation.fighter_for_side(simulation.teams[0].team_id).hp = 40.0
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("is_curtain_form")), "只有变身后的二阶段铁幕球才会释放保护铁幕")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0
	)
	var deployment_events := simulation.take_combat_events()
	_check(_has_combat_event(deployment_events, "iron_curtain_activation"), "二阶段铁幕展开只播放降音后的铁幕能量声")
	_check(not _has_combat_event(deployment_events, "iron_dragon_fire"), "二阶段铁幕展开不会误播铁龙粒子炮声")
	var fields: Array[BallEntity] = simulation.entity_list(0, "iron_curtain_protection_field")
	_check(fields.size() == 1, "技能释放后只生成一片圆形保护铁幕")
	var field: BallEntity = fields[0]
	_check(field.pos.is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).pos), "圆形铁幕固定生成在释放瞬间的本体位置")
	field.process_step(simulation.battle_context, 0.0)
	_check(simulation.has_status(simulation.fighter_for_side(simulation.teams[0].team_id), "iron_curtain_invulnerability"), "区域内友军主球获得通用无敌状态")
	_check(simulation.has_status(allied_attachment, "iron_curtain_invulnerability"), "区域内友军附属物获得同一通用无敌状态")
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[1].team_id), "iron_curtain_invulnerability"), "敌方主球不会获得铁幕无敌")
	var protected_hp := allied_attachment.hp
	var blocked := simulation.damage_entity(allied_attachment, 9.0, Color.WHITE, 1)
	_check(is_zero_approx(blocked) and is_equal_approx(allied_attachment.hp, protected_hp), "附属物金盾会实际阻断伤害而不只是显示图标")
	var enemy_fighter_hp := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	var enemy_attachment_hp := hostile_attachment.hp
	field.process_step(simulation.battle_context, 0.5)
	_check(is_equal_approx(enemy_fighter_hp - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 1.0), "保护铁幕每 0.5 秒对区域内敌方主球造成 1 点伤害")
	_check(is_equal_approx(enemy_attachment_hp - hostile_attachment.hp, 1.0), "保护铁幕同样伤害区域内敌方附属物")
	_check(is_equal_approx(allied_attachment.hp, protected_hp), "保护铁幕不会伤害己方附属物")
	simulation._update_status_effects(allied_attachment, 3.1)
	var applied_after_expiry := simulation.damage_entity(allied_attachment, 4.0, Color.WHITE, 1)
	_check(is_equal_approx(applied_after_expiry, 4.0), "3 秒无敌结束后附属物恢复正常受击")

func _check_transformation_projectile_and_universal_hazard() -> void:
	BallRegistry.configure_settings({
		"iron_curtain": {
			"transform_hp_percent": 40.0,
			"hazard_zone_radius": 100.0,
			"hazard_zone_duration": 4.0,
			"hazard_damage_interval": 0.5,
			"hazard_damage": 2.0,
			"projectile_impact_damage": 10.0,
		},
	})
	var simulation := BattleSimulationScript.new(20270882, "iron_curtain", "test_ball")
	_check(not bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("is_curtain_form")), "开局处于铁龙一阶段而不是铁幕二阶段")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).display_name == "铁龙球", "开局战场公开名称为铁龙球")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).color == Color("30343a") and simulation.fighter_for_side(simulation.teams[0].team_id).accent == Color("ff3e32"), "开局使用铁龙球的深装甲与红色能量配色")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(520.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(620.0, 320.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0
	)
	var fire_events := simulation.take_combat_events()
	_check(_has_combat_event(fire_events, "iron_dragon_fire"), "一阶段铁龙开炮播放独立粒子炮声")
	_check(not _has_combat_event(fire_events, "iron_curtain_activation"), "一阶段铁龙开炮不会误播铁幕展开声")
	var projectiles: Array[BallEntity] = simulation.entity_list(0, "iron_dragon_projectile")
	_check(projectiles.size() == 1, "铁龙形态主动技能生成一枚大型能量弹")
	var projectile: BallEntity = projectiles[0]
	_check(is_equal_approx(projectile.radius, 13.0), "大型能量弹使用可配置的 13 像素半径")
	_check(projectile.is_absorbable() and not projectile.can_transfer_ownership(), "大型能量弹可被黑洞吞噬但不能被心灵控制改阵营")
	var right_hp_before_impact := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	projectile.pos = Vector2(560.0, 320.0)
	projectile.velocity = Vector2(390.0, 0.0)
	projectile.process_step(simulation.battle_context, 0.1)
	_check(projectile.removed, "大型能量弹命中敌方主球后立即消失")
	_check(is_equal_approx(right_hp_before_impact - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 10.0), "大型能量弹命中敌方主球直接造成 10 点伤害")
	var hostile_blocker := DamageableFixtureEntity.new(1, Vector2(500.0, 320.0))
	simulation.add_entity(hostile_blocker)
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(400.0, 320.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0)
	projectiles = simulation.entity_list(0, "iron_dragon_projectile")
	var attachment_projectile: BallEntity = projectiles.back()
	attachment_projectile.process_step(simulation.battle_context, 0.1)
	_check(attachment_projectile.removed, "大型能量弹被敌方附属物阻挡后立即消失")
	_check(is_equal_approx(hostile_blocker.hp, 10.0), "大型能量弹以完整直击伤害命中敌方附属物")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(520.0, 100.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(300.0, 500.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(simulation.battle_context, simulation.fighter_for_side(simulation.teams[0].team_id), simulation.fighter_for_side(simulation.teams[1].team_id), 0)
	projectiles = simulation.entity_list(0, "iron_dragon_projectile")
	var exhausted_projectile: BallEntity = projectiles.back()
	exhausted_projectile.pos = Vector2(620.0, 100.0)
	exhausted_projectile.velocity = Vector2(390.0, 0.0)
	exhausted_projectile.process_step(simulation.battle_context, 0.1)
	_check(exhausted_projectile.removed, "大型能量弹撞墙后立即消失")
	var hazards: Array[BallEntity] = simulation.entity_list(0, "iron_curtain_hazard_field")
	_check(hazards.size() == 3, "大型能量弹命中主球、附属物或墙壁时都会各生成一片失控铁幕")
	var hazard: BallEntity = hazards.back()
	_check(String(hazard.call("field_mode")) == "hazard", "弹着区域明确使用无差别伤害形态")
	_check(is_equal_approx(float(hazard.call("damage_value")), 2.0), "落地铁幕使用独立的每跳伤害")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = hazard.pos + Vector2(-25.0, 0.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = hazard.pos + Vector2(25.0, 0.0)
	var allied_attachment := DamageableFixtureEntity.new(0, hazard.pos + Vector2(0.0, 28.0))
	var hostile_attachment := DamageableFixtureEntity.new(1, hazard.pos + Vector2(0.0, -28.0))
	simulation.add_entity(allied_attachment)
	simulation.add_entity(hostile_attachment)
	var left_hp := simulation.fighter_for_side(simulation.teams[0].team_id).hp
	var right_hp := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	hazard.process_step(simulation.battle_context, 0.5)
	_check(is_equal_approx(left_hp - simulation.fighter_for_side(simulation.teams[0].team_id).hp, 2.0), "失控铁幕会伤害铁龙球自己")
	_check(is_equal_approx(right_hp - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 2.0), "失控铁幕会伤害敌方主球")
	_check(is_equal_approx(allied_attachment.hp, 18.0), "失控铁幕会伤害己方附属物")
	_check(is_equal_approx(hostile_attachment.hp, 18.0), "失控铁幕会伤害敌方附属物")
	_check(not simulation.has_status(simulation.fighter_for_side(simulation.teams[0].team_id), "iron_curtain_invulnerability"), "失控铁幕不会给任何目标附加无敌")
	_check(hazard.is_absorbable() and not hazard.can_transfer_ownership(), "失控铁幕可被黑洞吞噬但不改变阵营")
	simulation.fighter_for_side(simulation.teams[0].team_id).hp = 40.0
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("is_curtain_form")), "生命到达阈值后只在球内状态机永久进入铁幕二阶段")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).display_name == "铁幕球", "变身后战场公开名称同步改为铁幕球")
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).color == Color("851a21") and simulation.fighter_for_side(simulation.teams[0].team_id).accent == Color("ff4938"), "变身后主球配色切为铁幕红色能量核心")
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).ability_timer, 7.0), "变身后等待完整铁幕释放间隔而不立刻连放")
	_check(bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("transform_animation_active")), "变为铁幕后启动可持续观察的球内变身动画")
	_check(simulation.impact_rings.size() >= 4 and simulation.particles.size() >= 50, "变身同时生成聚合、爆闪和装甲重组特效")
	var transform_events := simulation.take_combat_events()
	_check(_has_combat_event(transform_events, "iron_curtain_transform"), "变身瞬间只触发铁幕形态专用音频事件")
	_check(not _has_combat_event(transform_events, "iron_curtain_activation"), "变身不冒充普通周期技能的音频事件")

func _check_transform_world_stop() -> void:
	BallRegistry.configure_settings({
		"iron_curtain": {
			"transform_hp_percent": 40.0,
			"transform_animation_duration": 1.0,
			"transform_world_stop_duration": 1.0,
		},
	})
	var simulation := BattleSimulationScript.new(20270884, "iron_curtain", "test_ball")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(180.0, 250.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(500.0, 390.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(120.0, 35.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(-95.0, -28.0)
	var fixture := DamageableFixtureEntity.new(1, Vector2(420.0, 180.0))
	fixture.velocity = Vector2(-70.0, 45.0)
	fixture.remaining = 5.0
	simulation.add_entity(fixture)
	var timed_status := BallStatusEffect.new()
	timed_status.key = "world_stop_fixture"
	timed_status.remaining = 2.0
	simulation.fighter_for_side(simulation.teams[1].team_id).status_effects.append(timed_status)
	simulation.fighter_for_side(simulation.teams[0].team_id).hp = 40.0
	simulation.step(BattleSimulation.FIXED_STEP)
	_check(bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("is_curtain_form")), "世界停止由铁龙进入铁幕二阶段的变身触发")
	_check(is_equal_approx(simulation.world_stop_remaining(), 1.0), "到达阈值的同一帧立即申请 1 秒世界停止")
	_check(simulation.world_stop_source_fighter_uid() == simulation.fighter_for_side(simulation.teams[0].team_id).fighter_uid, "世界停止记录真正发起变身的主球 UID")
	_check(int(simulation.stats.get("iron_curtain_world_stops", 0)) == 1, "单次变身只记录一次世界停止")
	var frozen_elapsed := simulation.elapsed
	var frozen_left_position := simulation.fighter_for_side(simulation.teams[0].team_id).pos
	var frozen_right_position := simulation.fighter_for_side(simulation.teams[1].team_id).pos
	var frozen_fixture_position := fixture.pos
	var frozen_fixture_lifetime := fixture.remaining
	var frozen_status_remaining := timed_status.remaining
	var frozen_left_timer := simulation.fighter_for_side(simulation.teams[0].team_id).ability_timer
	var frozen_right_timer := simulation.fighter_for_side(simulation.teams[1].team_id).ability_timer
	for _frame in range(60):
		simulation.step(BattleSimulation.FIXED_STEP)
	_check(is_zero_approx(simulation.world_stop_remaining()), "60 个固定帧后世界停止精确结束")
	_check(is_equal_approx(simulation.elapsed, frozen_elapsed), "世界停止期间不推进对局计时")
	_check(
		simulation.fighter_for_side(simulation.teams[0].team_id).pos.is_equal_approx(frozen_left_position)
		and simulation.fighter_for_side(simulation.teams[1].team_id).pos.is_equal_approx(frozen_right_position),
		"世界停止期间所有主球的位置与轨迹完全冻结"
	)
	_check(
		fixture.pos.is_equal_approx(frozen_fixture_position)
		and is_equal_approx(fixture.remaining, frozen_fixture_lifetime),
		"世界停止期间附属物和投射物不移动也不消耗生命周期"
	)
	_check(is_equal_approx(timed_status.remaining, frozen_status_remaining), "世界停止期间状态效果计时冻结")
	_check(
		is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).ability_timer, frozen_left_timer)
		and is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).ability_timer, frozen_right_timer),
		"世界停止期间双方技能冷却均不推进"
	)
	_check(not simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).transform_animation_active(), "发起者的变身动画在静止世界中继续播放并正常完成")
	_check(simulation.impact_rings.is_empty() and simulation.particles.is_empty(), "世界停止时玩法冻结但变身环和粒子仍按表现时间完成清理")
	simulation.step(BattleSimulation.FIXED_STEP)
	_check(simulation.elapsed > frozen_elapsed, "世界停止结束后的下一帧恢复对局计时")
	_check(
		not simulation.fighter_for_side(simulation.teams[0].team_id).pos.is_equal_approx(frozen_left_position)
		and not simulation.fighter_for_side(simulation.teams[1].team_id).pos.is_equal_approx(frozen_right_position)
		and not fixture.pos.is_equal_approx(frozen_fixture_position),
		"世界停止结束后主球与附属物同步恢复运动"
	)
	_check(timed_status.remaining < frozen_status_remaining, "世界停止结束后状态效果恢复计时")

func _check_determinism() -> void:
	BallRegistry.configure_settings({})
	var first := BattleSimulationScript.new(20270883, "iron_curtain", "test_ball")
	var replay := BattleSimulationScript.new(20270883, "iron_curtain", "test_ball")
	first.fighter_for_side(first.teams[0].team_id).hp = 39.0
	replay.fighter_for_side(replay.teams[0].team_id).hp = 39.0
	for _frame in range(300):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
	_check(first.snapshot() == replay.snapshot(), "铁龙开炮、铁幕变身和领域伤害在相同种子下可完全重放")
	_check(bool(first._ability_for_fighter(first.fighter_for_side(first.teams[0].team_id)).call("is_curtain_form")) and bool(replay._ability_for_fighter(replay.fighter_for_side(replay.teams[0].team_id)).call("is_curtain_form")), "确定性重放中的双方实例都进入铁幕二阶段")
	_check(first.count_entities(0, "iron_dragon_projectile") == replay.count_entities(0, "iron_dragon_projectile"), "确定性重放保持相同的大型能量弹数量")
	_check(first.count_entities(0, "iron_curtain_hazard_field") == replay.count_entities(0, "iron_curtain_hazard_field"), "确定性重放保持相同的失控铁幕数量")

func _check_representative_matchups() -> void:
	BallRegistry.configure_settings({})
	var opponent_roles := {
		"garen": "近战武器球",
		"sniper": "远程投射物球",
		"splitter": "高密度附属物球",
	}
	var seed_offset := 0
	for opponent_id: String in opponent_roles:
		var simulation := BattleSimulationScript.new(
			20270890 + seed_offset,
			"iron_curtain",
			opponent_id
		)
		seed_offset += 1
		# 世界停止期间战斗时间不推进，因此允许物理步数高于战斗时限对应帧数。
		var max_frames := ceili(simulation.max_battle_time / BattleSimulation.FIXED_STEP) * 2 + 2
		for _frame in range(max_frames):
			if simulation.finished:
				break
			simulation.step(BattleSimulation.FIXED_STEP)
		_check(simulation.finished, "铁龙/铁幕球对%s能正常结束或进入硬时限裁决" % opponent_roles[opponent_id])
		_check(
			int(simulation.stats["abilities"].get("iron_curtain", 0)) > 0,
			"铁龙/铁幕球对%s会真实发动能力" % opponent_roles[opponent_id]
		)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _has_combat_event(events: Array[Dictionary], event_kind: String) -> bool:
	for event: Dictionary in events:
		if String(event.get("kind", "")) == event_kind:
			return true
	return false
