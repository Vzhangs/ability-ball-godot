extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const BattleViewScript := preload("res://scripts/ui/battle_view.gd")

var failures: Array[String] = []

class TestDamageableEntity extends BallEntity:
	var hp := 20.0

	func _init(spawn_owner_side: int, spawn_position: Vector2) -> void:
		owner_side = spawn_owner_side
		pos = spawn_position
		radius = 8.0
		tags = PackedStringArray(["blade_dancer_test_target"])

	func can_receive_attack(source_side: int) -> bool:
		return not removed and is_hostile_to(source_side)

	func receive_attack(
		_battle,
		amount: float,
		source_side: int,
		_hit_color: Color
	) -> float:
		if not can_receive_attack(source_side) or amount <= 0.0:
			return 0.0
		var applied := minf(hp, amount)
		hp -= applied
		if hp <= 0.0:
			removed = true
		return applied

class ForcedMovementEffect extends BallStatusEffect:
	func _init() -> void:
		key = "blade_dancer_test_forced_movement"
		remaining = 1.0

	func movement_control_priority() -> int:
		return MOVEMENT_CONTROL_PRIORITY_FORCED

func _init() -> void:
	_check_module_contract()
	_check_initial_fan_and_contact_gating()
	_check_attachment_damage()
	_check_dash_lock_afterimages_and_spin()
	_check_forced_movement_priority()
	_check_yuri_permanent_blade_control()
	_check_dash_audio_event_routing()
	_check_representative_matchups()
	_check_determinism()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_BLADE_DANCER_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_BLADE_DANCER_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_module_contract() -> void:
	BallRegistry.configure_settings({})
	var module: BallModule = BallRegistry.get_module("blade_dancer")
	_check(module != null and module.display_name == "女刀球", "女刀球由注册表自动发现")
	_check(is_equal_approx(module.max_hp, 100.0), "女刀球默认生命值为 100")
	_check(is_equal_approx(module.cooldown, 3.0), "女刀球默认每 3 秒突进一次")
	for key in [
		"blade_count", "blade_length", "blade_width", "blade_orbit_radius",
		"fan_arc_degrees", "blade_tilt_degrees", "blade_orbit_speed_degrees", "blade_damage",
		"dash_speed", "dash_damage", "dash_max_duration", "blade_spin_delay", "blade_spin_duration",
		"blade_spin_turns", "dash_afterimage_interval", "dash_afterimage_duration",
	]:
		_check(module.setting_specs().has(key), "女刀球参数 %s 由自身 Schema 配置" % key)
	_check(module.settingi("blade_count") == 6, "女刀球默认出生自带 6 把刀")
	_check(is_equal_approx(module.settingf("blade_tilt_degrees"), 45.0), "六把刀默认采用统一 45° 切角")
	_check(is_equal_approx(module.settingf("blade_damage"), 3.0), "每把刀默认接触伤害为 3")
	_check(is_equal_approx(module.settingf("dash_damage"), 6.0), "突进默认撞击伤害为 6")
	_check(is_equal_approx(module.settingf("blade_spin_delay"), 0.25), "突进后默认等待 0.25 秒再旋转刀阵")
	_check(module.audio_samples().size() == 1, "女刀球只保留刀刃擦切采样")
	_check(module.sound_kind == "wind_cast", "女刀球突进只保留非语音破空提示")
	_check(module.audio_samples().has("blade_dancer_blade_slice"), "女刀球注册独立刀刃擦切采样")
	var blade_slice_spec: Dictionary = module.audio_samples()["blade_dancer_blade_slice"]
	var blade_slice_stream := blade_slice_spec.get("stream") as AudioStream
	_check(
		blade_slice_stream != null
		and blade_slice_stream.get_length() >= 0.18
		and blade_slice_stream.get_length() <= 0.23,
		"刀刃擦切采样保持约 0.20 秒的短促反馈"
	)
	_check(
		is_equal_approx(float(blade_slice_spec.get("gain_db", 0.0)), -14.0),
		"多把刀连续命中时使用独立安全音量修正"
	)
	_check(
		String(module.formatted_ability_description()).contains("尤里球可以逐把永久控制"),
		"观众简介明确说明刀刃可被尤里永久控制"
	)

func _check_initial_fan_and_contact_gating() -> void:
	BallRegistry.configure_settings({
		"blade_dancer": {
			"blade_orbit_speed_degrees": 0.0,
		}
	})
	var simulation := BattleSimulationScript.new(20270871, "blade_dancer", "test_ball")
	var blades: Array[BallEntity] = simulation.entity_list(0, "blade_dancer_blade")
	_check(blades.size() == 6, "开局立即生成六把常驻独立刀刃实体")
	var positions: Dictionary = {}
	for blade: BallEntity in blades:
		positions[Vector2(blade.pos).snapped(Vector2.ONE * 0.01)] = true
		_check(blade.remaining < 0.0, "出生刀刃默认无限存在")
		_check(blade.is_absorbable(), "刀刃可被黑洞捕获吞噬")
		_check(blade.can_transfer_ownership(), "刀刃公开通用所有权转移能力")
		var radial_direction := (blade.pos - simulation.fighter_for_side(simulation.teams[0].team_id).pos).normalized()
		var blade_direction := Vector2(blade.call("blade_direction"))
		_check(
			is_equal_approx(radial_direction.angle_to(blade_direction), deg_to_rad(45.0)),
			"每把刀在各自扇形槽位上保持 45° 切入倾角"
		)
	_check(positions.size() == 6, "六把刀在展开扇形中占据不同位置")

	var blade: BallEntity = blades[2]
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = blade.pos
	var first_hp := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	simulation.take_combat_events()
	blade.process_step(simulation.battle_context, 0.0)
	_check(is_equal_approx(first_hp - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 3.0), "单把刀第一次接触敌球造成 3 点伤害")
	var first_hit_events := simulation.take_combat_events()
	_check(
		_count_combat_events(first_hit_events, "blade_dancer_blade_slice") == 1,
		"刀刃第一次擦到敌方主球时播放一次专属擦切声"
	)
	_check(
		_count_combat_events(first_hit_events, "projectile_hit") == 0,
		"刀刃命中不再冒充通用投射物命中声"
	)
	var held_hp := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	blade.process_step(simulation.battle_context, 0.0)
	_check(is_equal_approx(held_hp, simulation.fighter_for_side(simulation.teams[1].team_id).hp), "同一把刀持续贴住目标不会逐帧重复扣血")
	_check(simulation.take_combat_events().is_empty(), "刀刃持续贴住主球时不会重复刷擦切声")
	simulation.fighter_for_side(simulation.teams[1].team_id).pos += Vector2(200.0, 0.0)
	blade.process_step(simulation.battle_context, 0.06)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = blade.pos
	var reentry_hp := simulation.fighter_for_side(simulation.teams[1].team_id).hp
	blade.process_step(simulation.battle_context, 0.0)
	_check(is_equal_approx(reentry_hp - simulation.fighter_for_side(simulation.teams[1].team_id).hp, 3.0), "目标离开刀刃后再次接触会重新受伤")
	_check(
		_count_combat_events(simulation.take_combat_events(), "blade_dancer_blade_slice") == 1,
		"主球离开后再次擦到刀刃会重新播放擦切声"
	)

func _check_attachment_damage() -> void:
	BallRegistry.configure_settings({
		"blade_dancer": {
			"blade_count": 1,
			"blade_orbit_speed_degrees": 0.0,
		}
	})
	var simulation := BattleSimulationScript.new(20270872, "blade_dancer", "test_ball")
	var blade: BallEntity = simulation.entity_list(0, "blade_dancer_blade")[0]
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(620.0, 80.0)
	var attachment := TestDamageableEntity.new(1, blade.pos)
	simulation.add_entity(attachment)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0
	)
	simulation.take_combat_events()
	_check(
		is_zero_approx(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).contact_damage(
			simulation.battle_context,
			simulation.fighter_for_side(simulation.teams[0].team_id),
			attachment
		)),
		"突进本体伤害只认锁定主球，附属物伤害由刀刃自身结算"
	)
	blade.process_step(simulation.battle_context, 0.0)
	_check(is_equal_approx(attachment.hp, 17.0), "刀刃接触敌方可受击附属物同样造成 3 点伤害")
	_check(
		_count_combat_events(simulation.take_combat_events(), "blade_dancer_blade_slice") == 1,
		"刀刃擦到可受击附属物时同样播放专属擦切声"
	)
	var held_hp := attachment.hp
	blade.process_step(simulation.battle_context, 0.0)
	_check(is_equal_approx(held_hp, attachment.hp), "刀刃持续贴住同一附属物也只结算一次")
	_check(simulation.take_combat_events().is_empty(), "刀刃持续贴住附属物时不会重复刷擦切声")

func _check_dash_lock_afterimages_and_spin() -> void:
	BallRegistry.configure_settings({
		"blade_dancer": {
			"dash_speed": 920.0,
			"dash_damage": 3.0,
			"dash_max_duration": 0.55,
			"blade_spin_delay": 0.25,
		}
	})
	var simulation := BattleSimulationScript.new(20270873, "blade_dancer", "test_ball")
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(110.0, 150.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(430.0, 150.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0
	)
	for event: Dictionary in simulation.take_combat_events():
		_check(String(event.get("kind", "")) != "blade_slash", "女刀球破空声不会误触发风剑球 Hasagi 采样")
	_check(bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("dash_active")), "技能发动后进入硬锁突进状态")
	_check(
		int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("dash_target_uid")) == simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid,
		"突进锁定释放瞬间选中的敌方主球身份"
	)
	_check(
		simulation.count_entities(0, "blade_dancer_afterimage") >= 1,
		"突进起手立即生成球体残影"
	)
	for blade: BallEntity in simulation.entity_list(0, "blade_dancer_blade"):
		_check(not bool(blade.call("spin_active")), "突进起手时刀阵不会同步旋转")
	_check(bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("spin_pending")), "突进起手建立独立的延迟旋转时序")
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(430.0, 390.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).before_motion(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	var expected_direction := (simulation.fighter_for_side(simulation.teams[1].team_id).pos - simulation.fighter_for_side(simulation.teams[0].team_id).pos).normalized()
	_check(
		simulation.fighter_for_side(simulation.teams[0].team_id).velocity.normalized().is_equal_approx(expected_direction),
		"目标移动后突进每帧重新朝同一锁定目标追踪"
	)
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).velocity.length(), 920.0), "突进使用可配置高速速度")
	_check(
		is_equal_approx(
			simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).contact_damage(
				simulation.battle_context,
				simulation.fighter_for_side(simulation.teams[0].team_id),
				simulation.fighter_for_side(simulation.teams[1].team_id)
			),
			3.0
		),
		"突进只对锁定目标开放 3 点本体撞击伤害"
	)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		0.1
	)
	for blade: BallEntity in simulation.entity_list(0, "blade_dancer_blade"):
		_check(not bool(blade.call("spin_active")), "突进开始 0.1 秒时刀阵仍保持普通巡游")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).after_contact(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		3.0
	)
	_check(not bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("dash_active")), "突进撞到锁定目标后立即收束")
	_check(
		is_zero_approx(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).contact_damage(
			simulation.battle_context,
			simulation.fighter_for_side(simulation.teams[0].team_id),
			simulation.fighter_for_side(simulation.teams[1].team_id)
		)),
		"突进结束后主球恢复默认无碰撞伤害"
	)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		0.14
	)
	for blade: BallEntity in simulation.entity_list(0, "blade_dancer_blade"):
		_check(not bool(blade.call("spin_active")), "突进提前命中后仍等待完整旋转延迟")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		0.02
	)
	_check(not bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("spin_pending")), "累计到 0.25 秒后延迟旋转进入执行阶段")
	for blade: BallEntity in simulation.entity_list(0, "blade_dancer_blade"):
		_check(bool(blade.call("spin_active")), "延迟结束后每把仍属女刀球的刀开始快旋一圈")

func _check_forced_movement_priority() -> void:
	BallRegistry.configure_settings({})
	var simulation := BattleSimulationScript.new(20270874, "blade_dancer", "test_ball")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0
	)
	simulation.fighter_for_side(simulation.teams[0].team_id).status_effects.append(ForcedMovementEffect.new())
	var forced_velocity := Vector2(-117.0, 63.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = forced_velocity
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).before_motion(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(simulation.fighter_for_side(simulation.teams[0].team_id).velocity.is_equal_approx(forced_velocity), "强制拖拽优先级高于女刀球自身突进")
	_check(bool(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("dash_active")), "被强制拖拽时突进暂停而不是丢失锁定状态")
	_check(
		is_equal_approx(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).speed_multiplier(
			simulation.battle_context,
			simulation.fighter_for_side(simulation.teams[0].team_id),
			simulation.fighter_for_side(simulation.teams[1].team_id),
			0
		), 1.0),
		"强制拖拽期间女刀球不抬高公共速度上限"
	)

func _check_yuri_permanent_blade_control() -> void:
	BallRegistry.configure_settings({
		"blade_dancer": {
			"blade_count": 1,
			"blade_orbit_speed_degrees": 0.0,
		},
		"yuri": {
			"control_range": 1000.0,
			"max_control_per_cast": 1,
		},
	})
	var simulation := BattleSimulationScript.new(20270875, "blade_dancer", "yuri")
	var blade: BallEntity = simulation.entity_list(0, "blade_dancer_blade")[0]
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = blade.pos + Vector2(12.0, 0.0)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[1].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[1].team_id),
		simulation.fighter_for_side(simulation.teams[0].team_id),
		1
	)
	_check(blade.owner_side == 1, "尤里球能够把单把刀永久改为己方阵营")
	_check(blade.owner_fighter_uid == simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid, "受控刀刃锚定到具体尤里球而非模糊阵营")
	_check(int(blade.call("orbit_owner_uid")) == simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid, "受控刀刃改为环绕尤里球")
	_check(
		blade.absorption_visual_color().is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).accent),
		"受控刀刃通过通用所有权视觉覆写显示尤里颜色"
	)
	var before_position := blade.pos
	simulation.fighter_for_side(simulation.teams[1].team_id).pos += Vector2(19.0, -11.0)
	blade.process_step(simulation.battle_context, 0.1)
	_check(
		is_equal_approx(blade.pos.distance_to(simulation.fighter_for_side(simulation.teams[1].team_id).pos), 48.0),
		"受控刀刃保持女刀球原有贴身环绕规则并转到尤里身边"
	)
	_check(not blade.pos.is_equal_approx(before_position), "受控刀刃位置由新主人持续驱动")
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0
	)
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).on_step(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		0,
		0.3
	)
	_check(not bool(blade.call("spin_active")), "原女刀球延迟旋转也不会再控制已被尤里夺走的刀")

func _check_dash_audio_event_routing() -> void:
	BallRegistry.configure_settings({})
	var view := BattleViewScript.new()
	view.size = BattleViewScript.DEFAULT_VIEW_SIZE
	view.start_battle(20270879, "blade_dancer", "test_ball")
	var event_kinds: Array[String] = []
	view.combat_event.connect(func(kind: String, _strength: float) -> void:
		event_kinds.append(kind)
	)
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).ability_timer = 0.0
	view.simulation.step(BattleSimulationScript.FIXED_STEP)
	view.call("_check_combat_events")
	_check(
		event_kinds.count("wind_cast") == 1,
		"女刀球每次突进只向音频层发送一次非语音破空事件"
	)
	for event_kind in event_kinds:
		_check(not event_kind.contains("voice"), "女刀球突进不会再发送语音事件")
	view.call("_check_combat_events")
	_check(
		event_kinds.count("wind_cast") == 1,
		"没有新突进时不会重复播放破空提示"
	)
	view.free()

func _check_representative_matchups() -> void:
	BallRegistry.configure_settings({})
	for opponent_id in ["garen", "sniper", "plant"]:
		var simulation := BattleSimulationScript.new(20270880, "blade_dancer", opponent_id)
		for _step in range(int(6.0 / BattleSimulationScript.FIXED_STEP)):
			if simulation.finished:
				break
			simulation.step(BattleSimulationScript.FIXED_STEP)
		_check(
			int(simulation.stats["abilities"].get("blade_dancer", 0)) >= 1,
			"女刀球对战 %s 时会在默认冷却后正常突进" % opponent_id
		)
		_check(
			simulation.count_entities(0, "blade_dancer_blade") >= 1,
			"女刀球对战 %s 时刀阵实体保持正常运行" % opponent_id
		)

func _check_determinism() -> void:
	BallRegistry.configure_settings({})
	var first := BattleSimulationScript.new(20270876, "blade_dancer", "test_ball")
	var second := BattleSimulationScript.new(20270876, "blade_dancer", "test_ball")
	for _frame in range(420):
		first.step(BattleSimulation.FIXED_STEP)
		second.step(BattleSimulation.FIXED_STEP)
	_check(first.snapshot() == second.snapshot(), "女刀球同种子固定步长结果完全确定")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _count_combat_events(events: Array[Dictionary], kind: String) -> int:
	var count := 0
	for event: Dictionary in events:
		if String(event.get("kind", "")) == kind:
			count += 1
	return count
