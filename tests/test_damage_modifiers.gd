extends SceneTree

const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
const Shield := preload("res://scripts/balls/core/invulnerability_status_effect.gd")
var failures: Array[String] = []

class ScalingEffect extends BallStatusEffect:
	var multiplier := 1.0
	var calls := 0
	func _init(label: String, value: float) -> void:
		key = label
		remaining = 10.0
		multiplier = value
	func modify_incoming_damage(_battle, _target, amount: float, _source) -> float:
		calls += 1
		return amount * multiplier

class Target extends BallEntity:
	var hp := 100.0
	func can_receive_attack(side: int) -> bool:
		return is_hostile_to(side) and not removed
	func receive_attack(_battle, amount: float, _side: int, _color: Color) -> float:
		var applied := minf(hp, amount)
		hp -= applied
		return applied

func _init() -> void:
	BallRegistry.configure_settings({})
	var sim := Simulation.new(9181, "test_ball", "test_ball")
	_check(sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 20.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id)) == 20.0, "默认状态不改变伤害")
	var armor := ScalingEffect.new("test_reduction", 0.5)
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), armor)
	_check(sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 20.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id)) == 10.0, "主球支持按比例减伤")
	var exposure := ScalingEffect.new("test_vulnerability", 1.5)
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), exposure)
	_check(sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 20.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id)) == 15.0, "减伤与易伤按稳定顺序组合")
	exposure.remaining = 0.0
	_check(sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 20.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id)) == 10.0, "过期修正不会继续生效")
	var calls_before := armor.calls
	sim.apply_status(sim.fighter_for_side(sim.teams[1].team_id), Shield.new(1.0, 1, "test_invulnerability"))
	_check(sim.damage(sim.fighter_for_side(sim.teams[1].team_id), 20.0, Color.WHITE, sim.fighter_for_side(sim.teams[0].team_id)) == 0.0 and armor.calls == calls_before, "无敌先于伤害修正")
	_check(is_equal_approx(float(sim.stats.damage_to_right), 55.0), "统计只累计实际承伤")
	var entity := Target.new()
	entity.owner_side = 1
	entity.owner_fighter_uid = sim.fighter_for_side(sim.teams[1].team_id).fighter_uid
	sim.add_entity(entity)
	sim.apply_status(entity, ScalingEffect.new("test_entity_armor", 0.25))
	_check(sim.damage_entity(entity, 20.0, Color.WHITE, 0) == 5.0 and entity.hp == 95.0, "附属单位复用同一通用受伤修正")
	sim.apply_status(entity, ScalingEffect.new("test_clamped", -2.0))
	_check(sim.damage_entity(entity, 20.0, Color.WHITE, 0) == 0.0 and entity.hp == 95.0, "负修正不能反向回血")
	if failures.is_empty():
		print("ABILITY_BALL_DAMAGE_MODIFIERS_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
