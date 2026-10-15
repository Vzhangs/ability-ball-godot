extends SceneTree

const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
const Knockback := preload("res://scripts/balls/creeper/knockback_effect.gd")
var failures: Array[String] = []

class TargetEntity extends BallEntity:
	var hp := 100.0
	func _init(side: int, position: Vector2) -> void:
		owner_side = side
		pos = position
		radius = 10.0
	func can_receive_attack(side: int) -> bool:
		return is_hostile_to(side) and not removed
	func receive_attack(_battle, amount: float, _side: int, _color: Color) -> float:
		var applied := minf(hp, amount)
		hp -= applied
		return applied
	func participates_in_fighter_collision() -> bool:
		return true
	func fighter_collision_inverse_mass() -> float:
		return 1.0
	func can_resolve_fighter_contact(side: int) -> bool:
		return is_hostile_to(side)

func _init() -> void:
	BallRegistry.configure_settings({})
	var s := Simulation.new(812, "creeper", "test_ball")
	var events: Array[String] = []
	s.fighter_for_side(s.teams[0].team_id).pos = Vector2(300, 320)
	s.fighter_for_side(s.teams[1].team_id).pos = Vector2(350, 320)
	s._resolve_fighter_pair(s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id))
	_check(s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).is_armed(), "真实碰撞点燃")
	_check(s.fighter_for_side(s.teams[1].team_id).hp == 1000.0, "点燃不造成即时撞伤")
	for frame in range(59):
		s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).before_motion(s.battle_context, s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id), 0, Simulation.FIXED_STEP)
		s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).after_contact(s.battle_context, s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id), 0.0)
	_check(s.fighter_for_side(s.teams[1].team_id).hp == 1000.0 and s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).is_armed(), "引信未满一秒不炸，重复接触不重置")
	var entity := TargetEntity.new(1, Vector2(390, 320))
	var friendly := TargetEntity.new(0, Vector2(390, 320))
	s.add_entity(entity)
	s.add_entity(friendly)
	s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).before_motion(s.battle_context, s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id), 0, Simulation.FIXED_STEP)
	_check(s.fighter_for_side(s.teams[1].team_id).hp == 976.0 and entity.hp == 76.0, "满一秒对主球与附属物各结算一次爆炸")
	_check(s.fighter_for_side(s.teams[0].team_id).hp == 100.0 and friendly.hp == 100.0, "不自伤不伤友军")
	for event in s.take_combat_events():
		events.append(event.kind)
	_check(events.count("creeper_fuse") == 1 and events.count("creeper_explosion") == 1, "引信及爆炸音各触发一次")
	var original_velocity: Vector2 = s.fighter_for_side(s.teams[1].team_id).velocity
	var start: Vector2 = s.fighter_for_side(s.teams[1].team_id).pos
	for frame in range(15):
		s._update_status_effects(s.fighter_for_side(s.teams[1].team_id), Simulation.FIXED_STEP)
	_check(is_equal_approx(s.fighter_for_side(s.teams[1].team_id).pos.x - start.x, 150.0), "击退速度乘持续时间为真实位移，不被主球速度上限截断")
	_check(s.fighter_for_side(s.teams[1].team_id).velocity == original_velocity, "击退不遗留速度所有权或过期恢复")
	s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).after_contact(s.battle_context, s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id), 0.0)
	_check(not s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).is_armed(), "恢复期间不重新点燃")
	s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).before_motion(s.battle_context, s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id), 0, 2.0)
	s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).after_contact(s.battle_context, s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id), 0.0)
	_check(s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).is_armed(), "恢复结束可再触发")
	s.fighter_for_side(s.teams[1].team_id).pos = Vector2(610, 610)
	s._ability_for_fighter(s.fighter_for_side(s.teams[0].team_id)).before_motion(s.battle_context, s.fighter_for_side(s.teams[0].team_id), s.fighter_for_side(s.teams[1].team_id), 0, 1.0)
	_check(s.fighter_for_side(s.teams[1].team_id).hp == 976.0, "拉开距离能躲避爆炸")
	var e := Simulation.new(813, "creeper", "test_ball")
	e.fighter_for_side(e.teams[0].team_id).pos = Vector2(300, 320)
	e.fighter_for_side(e.teams[1].team_id).pos = Vector2(580, 580)
	e.add_entity(TargetEntity.new(1, Vector2(330, 320)))
	e._resolve_fighter_entity_collisions()
	_check(e._ability_for_fighter(e.fighter_for_side(e.teams[0].team_id)).is_armed(), "附属物真实碰撞同样点燃")
	e.fighter_for_side(e.teams[0].team_id).hp = 0.0
	e._ability_for_fighter(e.fighter_for_side(e.teams[0].team_id)).before_motion(e.battle_context, e.fighter_for_side(e.teams[0].team_id), e.fighter_for_side(e.teams[1].team_id), 0, 2.0)
	_check(int(e.stats.get("creeper_explosions", 0)) == 0, "引爆前死亡不会爆炸")
	var overrides := {"creeper": {"fuse_duration": 0.3, "blast_radius": 240.0,
		"blast_damage": 31.0, "knockback_speed": 900.0, "knockback_duration": 0.4}}
	var path := "user://creeper-test-settings.json"
	_check(BallSettingsStore.save_settings(overrides, path) == OK, "配置保存")
	BallRegistry.configure_settings(BallSettingsStore.load_settings(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for opponent in ["sonic", "sniper", "plant"]:
		var first := Simulation.new(814, "creeper", opponent)
		var replay := Simulation.new(814, "creeper", opponent)
		_check(first.module_for_fighter(first.fighter_for_side(first.teams[0].team_id)).settingf("blast_damage") == 31.0, "重载后配置跨对手生效")
		for frame in range(7201):
			first.step(Simulation.FIXED_STEP)
			replay.step(Simulation.FIXED_STEP)
			if first.finished and replay.finished:
				break
		_check(first.finished, "代表性对局结束")
		_check(first.snapshot() == replay.snapshot(), "代表性对局确定性重放")
		_check(int(first.stats.get("creeper_explosions", 0)) > 0, "代表性对局发生爆炸")
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_CREEPER_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
