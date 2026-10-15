extends SceneTree

const Setup := preload("res://scripts/simulation/battle_setup.gd")
var failures: Array[String] = []

func _init() -> void:
	BallRegistry.configure_settings({})
	var setups := [
		Setup.relay(["qing", "gale"], ["sniper", "garen"]),
		Setup.team_brawl(["qing", "gale"], ["splitter", "yuri"]),
		Setup.free_for_all([["qing"], ["gale"], ["sniper"], ["frost"]]),
		Setup.boss([["qing"], ["gale"], ["garen"]]),
	]
	for setup in setups:
		var sim := BattleSimulation.new(9014, setup, 30.0, Vector2(640, 640))
		for _frame in range(2400): sim.step(BattleSimulation.FIXED_STEP)
		if not sim.finished: failures.append("Battle failed to adjudicate: " + setup.mode)
		print("QING_GALE_MODE ", setup.mode, " finished=", sim.finished)
	if failures.is_empty():
		print("ABILITY_BALL_QING_GALE_MODES_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
