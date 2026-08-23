extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

const SKILL_SYMBOLS := {
	"rook": "車",
	"cannon": "炮",
	"elephant": "象",
	"marshal": "帅",
	"guard": "士",
}
const WEIGHT_KEYS := [
	"rook_weight",
	"cannon_weight",
	"elephant_weight",
	"marshal_weight",
	"guard_weight",
]

var failures: Array[String] = []

class TestCollidableEntity extends BallEntity:
	var hp := 100.0
	var _contact_ready := true

	func _init(spawn_owner: int, spawn_position: Vector2, spawn_radius: float) -> void:
		owner_side = spawn_owner
		pos = spawn_position
		radius = spawn_radius
		tags = PackedStringArray(["chess_test_collidable"])

	func participates_in_entity_collision() -> bool:
		return not removed

	func entity_collision_inverse_mass() -> float:
		return 1.0

	func entity_contact_damage() -> float:
		return 2.0

	func entity_contact_color() -> Color:
		return Color("57d7ff")

	func can_resolve_entity_contact(other: BallEntity) -> bool:
		return other != null and other.owner_side != owner_side and _contact_ready

	func begin_entity_contact(_other: BallEntity) -> void:
		_contact_ready = false

	func can_receive_attack(source_side: int) -> bool:
		return not removed and is_hostile_to(source_side)

	func receive_attack(_battle, amount: float, source_side: int, _hit_color: Color) -> float:
		if not can_receive_attack(source_side) or amount <= 0.0:
			return 0.0
		var applied := minf(hp, amount)
		hp -= applied
		return applied

func _init() -> void:
	_check_module_contract()
	_check_rook_skill()
	_check_cannon_skill()
	_check_elephant_skill()
	_check_marshal_skill()
	_check_guard_skill()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_CHESS_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_CHESS_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_module_contract() -> void:
	BallRegistry.configure_settings({})
	var module: BallModule = BallRegistry.get_module("chess")
	_check(module != null and module.display_name == "象棋球", "象棋球由注册表自动发现并使用独立公开名称")
	for key in [
		"rook_weight", "cannon_weight", "elephant_weight", "marshal_weight", "guard_weight",
		"cast_icon_duration", "rook_windup_duration", "rook_dash_speed", "rook_damage",
		"rook_entity_damage", "rook_max_duration", "rook_lane_width_multiplier",
		"rook_front_length", "rook_carry_duration", "rook_wall_damage",
		"cannon_damage", "cannon_explosion_radius", "cannon_projectile_speed",
		"cannon_projectile_radius", "cannon_projectile_lifetime", "cannon_shot_count",
		"cannon_shot_interval", "cannon_muzzle_flash_duration", "cannon_blast_duration",
		"elephant_start_speed", "elephant_path_speed", "elephant_damage", "elephant_laps",
		"elephant_path_margin", "marshal_instant_heal", "marshal_regen_duration",
		"marshal_regen_per_tick", "marshal_regen_interval", "guard_summon_count",
		"guard_max_hp", "guard_radius", "guard_contact_damage", "guard_contact_interval",
		"guard_orbit_radius", "guard_orbit_speed",
	]:
		_check(module.setting_specs().has(key), "象棋球参数 %s 由自身 Schema 配置" % key)
	_check(is_equal_approx(module.max_hp, 100.0), "象棋球默认生命值为 100")
	_check(is_equal_approx(module.settingf("guard_max_hp"), 10.0), "士默认独立生命值为 10")

func _check_rook_skill() -> void:
	_force_skill("rook", {
		"cooldown": 3.25,
		"rook_windup_duration": 0.3,
		"rook_dash_speed": 720.0,
		"rook_damage": 20.0,
		"rook_entity_damage": 7.0,
		"rook_lane_width_multiplier": 1.25,
		"rook_front_length": 72.0,
		"rook_carry_duration": 0.35,
		"rook_wall_damage": 12.0,
	})
	var simulation := BattleSimulationScript.new(20270101, "chess", "heaven")
	simulation.left.pos = Vector2(100.0, 220.0)
	simulation.right.pos = Vector2(430.0, 220.0)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	_check_cast(simulation, "rook")
	_check(not simulation.left_ability.automatic_activation_enabled(), "車突进未结束时不会被过短的自定义间隔中途覆盖")
	_check(is_equal_approx(simulation.left.cooldown, 3.25), "技能间隔 a 使用象棋球自己的持久化配置")
	_check(Vector2(simulation.left_ability.call("rook_target_snapshot")).is_equal_approx(Vector2(430.0, 220.0)), "車蓄力开始时先瞄准敌球当前位置")
	_check(String(simulation.left_ability.call("rook_phase")) == "windup", "車发动后先进入可配置前摇而不立即突进")
	_check(simulation.left.velocity.is_zero_approx(), "車默认在 0.3 秒前摇期间原地蓄势")
	_check(is_zero_approx(simulation.left_ability.contact_damage(simulation.battle_context, simulation.left, simulation.right)), "車前摇期间本体碰撞不造成突进伤害")
	simulation.right.pos = Vector2(430.0, 480.0)
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.29
	)
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.29
	)
	_check(String(simulation.left_ability.call("rook_phase")) == "windup" and simulation.left.velocity.is_zero_approx(), "車在前摇结束前一帧仍保持蓄势")
	_check(Vector2(simulation.left_ability.call("rook_target_snapshot")).is_equal_approx(Vector2(430.0, 480.0)), "車在前摇期间持续更新瞄准而不是锁死旧位置")
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.01
	)
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.01
	)
	_check(String(simulation.left_ability.call("rook_phase")) == "dash", "車累计前摇 0.3 秒后才切换为突进")
	var expected_direction := (Vector2(430.0, 480.0) - Vector2(100.0, 220.0)).normalized()
	_check(simulation.left.velocity.normalized().is_equal_approx(expected_direction), "車在起步瞬间锁定前摇末尾目标位置")
	_check(is_equal_approx(simulation.left.velocity.length(), 720.0), "車起步后使用可配置高速直线冲锋")
	_check(int(simulation.stats.get("chess_rook_launches", 0)) == 1, "車实际起步只记录一次独立突进释放")

	# 加宽车头会碾压通用可受击附属物，且同一趟冲锋只伤害一次并继续前进。
	simulation.right.pos = Vector2(620.0, 60.0)
	var crush_target := TestCollidableEntity.new(
		1,
		simulation.left.pos + expected_direction * 52.0,
		8.0
	)
	simulation.add_entity(crush_target)
	var crush_hp_before := crush_target.hp
	simulation.left_ability.after_entities_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(crush_hp_before - crush_target.hp, 7.0), "車的加宽车头按独立配置碾压可受击附属物")
	_check(bool(simulation.left_ability.call("rook_active")) and String(simulation.left_ability.call("rook_phase")) == "dash", "車撞到附属物后不会终止直线冲锋")
	simulation.left_ability.after_entities_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(crush_hp_before - crush_target.hp, 7.0), "同一趟車冲锋不会对同一附属物逐帧重复碾压")

	# 主球在车头范围内时优先受击，并进入可配置顶行状态。
	_force_skill("rook", {
		"rook_windup_duration": 0.0,
		"rook_dash_speed": 720.0,
		"rook_damage": 20.0,
		"rook_entity_damage": 7.0,
		"rook_lane_width_multiplier": 1.25,
		"rook_front_length": 72.0,
		"rook_carry_duration": 0.35,
		"rook_wall_damage": 12.0,
	})
	var carry_simulation := BattleSimulationScript.new(20270106, "chess", "heaven")
	carry_simulation.left.pos = Vector2(100.0, 320.0)
	carry_simulation.right.pos = Vector2(220.0, 320.0)
	carry_simulation.left_ability.activate(
		carry_simulation.battle_context,
		carry_simulation.left,
		carry_simulation.right,
		0
	)
	var main_hp_before := carry_simulation.right.hp
	carry_simulation.left_ability.after_entities_step(
		carry_simulation.battle_context,
		carry_simulation.left,
		carry_simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(main_hp_before - carry_simulation.right.hp, 20.0), "車的加宽车头优先命中主球并造成可配置主伤害")
	_check(String(carry_simulation.left_ability.call("rook_phase")) == "carry", "車命中主球后进入顶行阶段而不是立即结束")
	_check(carry_simulation.has_status(carry_simulation.right, "chess_rook_carry"), "被撞主球由象棋球私有强制移动状态顶行")
	carry_simulation._update_status_effects(carry_simulation.right, 0.1)
	_check(carry_simulation.right.velocity.x > 700.0 and absf(carry_simulation.right.velocity.y) <= 0.001, "顶行状态压过目标自己的普通移动并保持冲锋方向")

	# 顶到墙面时追加一次伤害与冲击并立即释放双方。
	carry_simulation.right.pos = Vector2(
		carry_simulation.arena_size().x - carry_simulation.right.radius + 2.0,
		320.0
	)
	carry_simulation.right.velocity = Vector2(720.0, 0.0)
	var wall_hp_before := carry_simulation.right.hp
	carry_simulation._resolve_wall(carry_simulation.right)
	carry_simulation.left_ability.after_entities_step(
		carry_simulation.battle_context,
		carry_simulation.left,
		carry_simulation.right,
		0,
		BattleSimulation.FIXED_STEP
	)
	_check(is_equal_approx(wall_hp_before - carry_simulation.right.hp, 12.0), "車把主球顶到墙上时追加可配置墙击伤害")
	_check(int(carry_simulation.stats.get("chess_rook_wall_hits", 0)) == 1, "一次顶墙只结算一次車墙击")
	_check(not bool(carry_simulation.left_ability.call("rook_active")), "車顶墙结算后结束冲锋并清理顶行状态")
	_check(not carry_simulation.has_status(carry_simulation.right, "chess_rook_carry"), "車结束后目标不残留强制移动状态")
	_check(carry_simulation.left_ability.automatic_activation_enabled(), "車完整收束后恢复下一次棋令调度")

func _check_cannon_skill() -> void:
	_force_skill("cannon", {
		"cannon_damage": 16.0,
		"cannon_explosion_radius": 82.0,
		"cannon_shot_count": 2,
		"cannon_shot_interval": 0.24,
	})
	var simulation := BattleSimulationScript.new(20270102, "chess", "heaven")
	simulation.left.pos = Vector2(100.0, 320.0)
	simulation.right.pos = Vector2(500.0, 320.0)
	var splash_target := TestCollidableEntity.new(1, Vector2(540.0, 320.0), 9.0)
	simulation.add_entity(splash_target)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	_check_cast(simulation, "cannon")
	var cannonballs: Array[BallEntity] = simulation.entity_list(0, "chess_cannonball")
	_check(cannonballs.size() == 1, "炮发动时立即发射第一枚象棋球私有炮弹")
	_check(int(simulation.left_ability.call("cannon_shots_remaining")) == 1, "第一炮后保留一发短间隔连发状态")
	_check(not simulation.left_ability.automatic_activation_enabled(), "双炮尚未打完时不会被下一次棋令覆盖")
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.24
	)
	cannonballs = simulation.entity_list(0, "chess_cannonball")
	_check(cannonballs.size() == 2, "炮按可配置短间隔连续发射两枚炮弹")
	_check(int(simulation.left_ability.call("cannon_shots_remaining")) == 0, "第二炮发出后连发状态立即收束")
	_check(simulation.left_ability.automatic_activation_enabled(), "双炮完成后恢复下一次棋令调度")
	_check(int(simulation.stats.get("chess_cannon_shots", 0)) == 2, "两发炮弹分别进入象棋球私有射击统计")
	_check(simulation.count_entities(0, "chess_cannon_muzzle_vfx") == 2, "每发炮弹各自生成高层炮口焰")
	if cannonballs.is_empty():
		return
	var cannonball := cannonballs[0]
	_check(cannonball.is_absorbable() and not cannonball.can_transfer_ownership(), "炮弹可被捕获吞噬但不会被心灵控制改阵营")
	_check(is_equal_approx(float(cannonball.call("explosion_radius")), 82.0), "炮弹使用可配置爆炸半径")
	cannonball.pos = simulation.right.pos
	cannonball.velocity = Vector2.ZERO
	var fighter_hp_before := simulation.right.hp
	var entity_hp_before := splash_target.hp
	cannonball.process_step(simulation.battle_context, 0.0)
	_check(cannonball.removed, "炮弹命中后立即爆炸并清理弹体")
	_check(is_equal_approx(fighter_hp_before - simulation.right.hp, 16.0), "炮弹范围爆炸伤害敌方主球")
	_check(is_equal_approx(entity_hp_before - splash_target.hp, 16.0), "炮弹范围爆炸同时伤害范围内敌方附属物")
	_check(int(simulation.stats.get("chess_cannon_explosions", 0)) == 1, "炮弹爆炸进入象棋球独立统计")
	var blast_effects: Array[BallEntity] = simulation.entity_list(0, "chess_cannon_blast_vfx")
	_check(blast_effects.size() == 1 and blast_effects[0].draws_above_balls(), "炮弹命中生成压在球体上方的独立范围爆炸演出")

func _check_elephant_skill() -> void:
	_force_skill("elephant", {
		"elephant_start_speed": 900.0,
		"elephant_path_speed": 1200.0,
		"elephant_damage": 9.0,
		"elephant_laps": 2,
	})
	var simulation := BattleSimulationScript.new(20270103, "chess", "laser")
	simulation.left.pos = Vector2(130.0, 120.0)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	_check_cast(simulation, "elephant")
	_check(not simulation.left_ability.automatic_activation_enabled(), "象未跑完两圈时不会被下一次棋令中途打断")
	_check(simulation.has_status(simulation.left, "chess_elephant_invulnerability"), "象从归位开始即复用通用无敌状态和金盾标识")
	var hp_before := simulation.left.hp
	var blocked: float = simulation.damage(simulation.left, 25.0, simulation.right.accent, simulation.right)
	_check(is_zero_approx(blocked) and is_equal_approx(simulation.left.hp, hp_before), "象发动全程免疫伤害")
	_check(is_equal_approx(simulation.left_ability.contact_damage(simulation.battle_context, simulation.left, simulation.right), 9.0), "象沿菱形撞击时使用可配置伤害")
	var path_lock_checked := false
	for _frame in range(1600):
		simulation.left_ability.on_step(
			simulation.battle_context,
			simulation.left,
			simulation.right,
			0,
			BattleSimulation.FIXED_STEP
		)
		if not path_lock_checked and String(simulation.left_ability.call("elephant_phase")) == "diamond":
			var prescribed_position: Vector2 = simulation.left_ability.call("elephant_path_position")
			simulation.left.pos += Vector2(91.0, -73.0)
			simulation.left.velocity = Vector2(-999.0, 444.0)
			simulation.left_ability.after_entities_step(
				simulation.battle_context,
				simulation.left,
				simulation.right,
				0,
				BattleSimulation.FIXED_STEP
			)
			_check(simulation.left.pos.is_equal_approx(prescribed_position), "象的菱形轨迹在帧末覆盖外部碰撞位移与速度干扰")
			path_lock_checked = true
		if not bool(simulation.left_ability.call("elephant_active")):
			break
	_check(path_lock_checked, "象先归位到竞技场底部中央再进入菱形运动")
	_check(int(simulation.left_ability.call("elephant_laps_completed")) == 2, "象严格完成两圈菱形轨迹后结束")
	var expected_bottom := Vector2(simulation.arena_size().x * 0.5, simulation.arena_size().y - 48.0)
	_check(simulation.left.pos.distance_to(expected_bottom) <= 0.01, "象两圈结束时回到竞技场底部中央")
	_check(not simulation.has_status(simulation.left, "chess_elephant_invulnerability"), "象结束后立即移除无敌状态")
	_check(simulation.left_ability.automatic_activation_enabled(), "象完成两圈后允许已到期的下一次棋令立即发动")

func _check_marshal_skill() -> void:
	_force_skill("marshal", {
		"marshal_instant_heal": 10.0,
		"marshal_regen_duration": 5.0,
		"marshal_regen_per_tick": 2.0,
		"marshal_regen_interval": 1.0,
	})
	var simulation := BattleSimulationScript.new(20270104, "chess", "laser")
	simulation.left.hp = 50.0
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	_check_cast(simulation, "marshal")
	_check(is_equal_approx(simulation.left.hp, 60.0), "帅发动时立即回复 10 点生命")
	_check(simulation.has_status(simulation.left, "chess_marshal_regeneration"), "帅的后续回血由象棋球私有状态独立管理")
	for _second in range(5):
		simulation._update_status_effects(simulation.left, 1.0)
	_check(is_equal_approx(simulation.left.hp, 70.0), "帅未来 5 秒每秒回复 2 点生命，共追加 10 点")
	_check(not simulation.has_status(simulation.left, "chess_marshal_regeneration"), "帅五次回血完成后清理持续状态")

func _check_guard_skill() -> void:
	_force_skill("guard", {
		"guard_summon_count": 2,
		"guard_max_hp": 12.0,
		"guard_contact_damage": 3.0,
		"guard_orbit_radius": 64.0,
		"guard_orbit_speed": 2.4,
	})
	var simulation := BattleSimulationScript.new(20270105, "chess", "heaven")
	simulation.left.pos = Vector2(140.0, 320.0)
	simulation.right.pos = Vector2(580.0, 320.0)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	_check_cast(simulation, "guard")
	var guards: Array[BallEntity] = simulation.entity_list(0, "chess_guard")
	_check(guards.size() == 2, "士默认一次召唤两枚可配置数量的环绕小球")
	if guards.size() < 2:
		return
	for guard: BallEntity in guards:
		_check(is_equal_approx(float(guard.get("max_hp")), 12.0), "每枚士使用独立可配置生命值")
		_check(is_equal_approx(guard.pos.distance_to(simulation.left.pos), 64.0), "士按可配置半径环绕象棋球")
		_check(guard.can_receive_attack(1) and guard.is_absorbable(), "士可挡攻击、可被捕获吞噬并拥有独立生命")
	_check_even_guard_spacing(guards, simulation.left.pos, "同批两枚士以 180° 等角间隔编排")
	simulation.left_ability.before_motion(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		1.25
	)
	simulation.left_ability.on_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	simulation.left_ability.activate(simulation.battle_context, simulation.left, simulation.right, 0)
	guards = simulation.entity_list(0, "chess_guard")
	_check(guards.size() == 4, "第二次士棋令加入两枚新士并重新编排全部现存士")
	_check_even_guard_spacing(guards, simulation.left.pos, "不同批次四枚士按当前总数重新等角编排")
	for guard: BallEntity in guards:
		_check(int(guard.call("orbit_slot_count")) == 4, "每枚士共享当前编队总数而不保留旧批次年龄偏移")
	var blocker := guards[0]
	blocker.pos = Vector2(320.0, 320.0)
	var guard_hp_before := float(blocker.get("hp"))
	var main_hp_before := simulation.left.hp
	simulation.add_projectile(
		1,
		Vector2(390.0, 320.0),
		Vector2(-600.0, 0.0),
		5.0,
		4.0,
		Color("57d7ff"),
		2.0,
		"chess_guard_block_test"
	)
	var projectile: BallEntity = simulation.entity_list(1, "projectile")[0]
	projectile.process_step(simulation.battle_context, 0.2)
	_check(projectile.removed and is_equal_approx(guard_hp_before - float(blocker.get("hp")), 4.0), "士挡住非穿透投射物并按实际伤害扣除自身生命")
	_check(is_equal_approx(simulation.left.hp, main_hp_before), "被士挡住的投射物不会继续命中象棋球本体")

	blocker.call("snap_to_orbit")
	simulation.right.pos = blocker.pos + Vector2(blocker.radius + simulation.right.radius - 1.0, 0.0)
	simulation.right.velocity = Vector2(-220.0, 0.0)
	blocker.velocity = Vector2(220.0, 0.0)
	var right_velocity_before := simulation.right.velocity
	var right_hp_before := simulation.right.hp
	simulation._resolve_fighter_entity_collisions()
	_check(is_equal_approx(right_hp_before - simulation.right.hp, 3.0), "士撞到敌方主球造成 3 点可配置碰撞伤害")
	_check(not simulation.right.velocity.is_equal_approx(right_velocity_before), "士与敌方主球发生等同本体碰撞的轨迹响应")
	simulation.left_ability.after_entities_step(
		simulation.battle_context,
		simulation.left,
		simulation.right,
		0,
		0.0
	)
	_check(is_equal_approx(blocker.pos.distance_to(simulation.left.pos), 64.0), "主球碰撞只改变敌方轨迹，士自身立即回归既定环绕轨道")

	var entity_target := TestCollidableEntity.new(1, blocker.pos + Vector2(blocker.radius + 9.0 - 1.0, 0.0), 9.0)
	entity_target.velocity = Vector2(-160.0, 0.0)
	simulation.add_entity(entity_target)
	blocker.set("_entity_contact_timers", {})
	var entity_hp_before := entity_target.hp
	var blocker_hp_before := float(blocker.get("hp"))
	blocker.call("resolve_entity_collision", simulation.battle_context, entity_target)
	_check(is_equal_approx(entity_hp_before - entity_target.hp, 3.0), "士也会与敌方可受击附属物碰撞并造成自身配置伤害")
	_check(is_equal_approx(blocker_hp_before - float(blocker.get("hp")), 2.0), "士与敌方附属物碰撞时双方独立结算接触伤害")
	_check(is_equal_approx(blocker.pos.distance_to(simulation.left.pos), 64.0), "附属物碰撞同样不会扭曲士的环绕轨迹")

	var transferred := guards[1]
	_check(transferred.transfer_ownership(1, simulation.right), "士接入通用永久所有权转移契约")
	transferred.set_ownership_visual_color(Color("b45cff"))
	transferred.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_check(transferred.owner_side == 1 and transferred.call("orbit_owner") == simulation.right, "被控制的士永久换边并改为环绕新主人")
	_check(is_equal_approx(transferred.pos.distance_to(simulation.right.pos), 64.0), "换边后的士继续保持原生环绕规则")
	_check(not bool(transferred.call("formation_managed")), "被控制的士脱离原象棋球编队后使用自己的连续环绕时钟")

func _check_even_guard_spacing(guards: Array[BallEntity], center: Vector2, label: String) -> void:
	if guards.size() < 2:
		_check(false, label)
		return
	var angles: Array[float] = []
	for guard: BallEntity in guards:
		angles.append(fposmod((guard.pos - center).angle(), TAU))
	angles.sort()
	var expected_gap := TAU / float(angles.size())
	for index in range(angles.size()):
		var next_angle := angles[(index + 1) % angles.size()]
		if index == angles.size() - 1:
			next_angle += TAU
		_check(absf(next_angle - angles[index] - expected_gap) <= 0.001, "%s（槽位 %d）" % [label, index + 1])

func _force_skill(skill: String, overrides: Dictionary = {}) -> void:
	var settings := {}
	for weight_key: String in WEIGHT_KEYS:
		settings[weight_key] = 0.0
	settings["%s_weight" % skill] = 1.0
	for key in overrides:
		settings[key] = overrides[key]
	BallRegistry.configure_settings({"chess": settings})

func _check_cast(simulation: BattleSimulation, skill: String) -> void:
	_check(String(simulation.left_ability.call("last_skill")) == skill, "%s 单权重配置只发动对应棋令" % SKILL_SYMBOLS[skill])
	var icons: Array[BallEntity] = simulation.entity_list(0, "chess_cast_icon_vfx")
	_check(icons.size() == 1, "%s 发动时生成球体最上层棋令图标" % SKILL_SYMBOLS[skill])
	if icons.is_empty():
		return
	_check(String(icons[0].call("icon_text")) == SKILL_SYMBOLS[skill], "%s 技能显示对应象棋文字" % SKILL_SYMBOLS[skill])
	var start_scale: float = icons[0].call("animation_scale")
	icons[0].process_lifetime(icons[0].remaining * 0.5)
	var peak_scale: float = icons[0].call("animation_scale")
	_check(icons[0].draws_above_balls() and peak_scale > start_scale, "%s 棋令图标位于球体上层并执行放大缩小动画" % SKILL_SYMBOLS[skill])

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
