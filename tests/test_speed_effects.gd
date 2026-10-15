extends SceneTree

class Modifier extends BallStatusEffect:
	var ratio: float
	func _init(label: String, value: float) -> void:
		key = label
		remaining = 1.0
		ratio = value
	func fighter_speed_multiplier() -> float:
		return ratio
	func entity_step_multiplier() -> float:
		return ratio

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	for reverse in [false, true]:
		var sim := BattleSimulation.new(18, "test_ball", "test_ball")
		var effects: Array[BallStatusEffect] = [Modifier.new("slow-a", 0.5), Modifier.new("slow-b", 0.7), Modifier.new("fast-a", 1.5), Modifier.new("fast-b", 1.2)]
		if reverse: effects.reverse()
		var entity := BallEntity.new()
		entity.status_effects = effects.duplicate()
		check(is_equal_approx(entity.status_step_multiplier(), 0.75), "Independent units combine strongest slow and strongest haste without multiplying overlaps")
		sim.fighter_for_side(sim.teams[0].team_id).status_effects = effects.duplicate()
		sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(200, 200)
		sim.fighter_for_side(sim.teams[0].team_id).velocity = Vector2.RIGHT * sim.fighter_for_side(sim.teams[0].team_id).base_speed
		sim._update_fighter(sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)), 0, 0.01)
		check(is_equal_approx(sim.fighter_for_side(sim.teams[0].team_id).velocity.length(), sim.fighter_for_side(sim.teams[0].team_id).base_speed * 0.75), "Main movement composes status speed with ability speed in either application order")
		for effect in effects: effect.remaining = 0.0
		check(is_equal_approx(entity.status_step_multiplier(), 1.0), "Expired modifiers leave no entity haste")
		sim._update_fighter(sim.fighter_for_side(sim.teams[0].team_id), sim.fighter_for_side(sim.teams[1].team_id), sim._ability_for_fighter(sim.fighter_for_side(sim.teams[0].team_id)), 0, 0.01)
		check(is_equal_approx(sim.fighter_for_side(sim.teams[0].team_id).velocity.length(), sim.fighter_for_side(sim.teams[0].team_id).base_speed), "Ordinary movement returns to base speed on expiry")
	if failures.is_empty():
		print("ABILITY_BALL_SPEED_EFFECTS_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
