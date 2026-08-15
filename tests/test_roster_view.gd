extends SceneTree

const RosterBattleViewScript := preload("res://scripts/ui/roster_battle_view.gd")

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var ids := BallRegistry.ids()
	for index in range(0, ids.size(), 2):
		var view: RosterBattleView = RosterBattleViewScript.new()
		view.size = Vector2(650.0, 650.0)
		get_root().add_child(view)
		view.start_battle(20260815 + index, ids[index], ids[index + 1])
		view.simulation.step(RosterBattleSimulation.FIXED_STEP)
		view.queue_redraw()
		await process_frame
		await process_frame
		_check(view.left_visual is BallVisual, "%s 视觉已装载" % ids[index])
		_check(view.right_visual is BallVisual, "%s 视觉已装载" % ids[index + 1])
		view.queue_free()
		await process_frame
	if failures.is_empty():
		print("ABILITY_BALL_ALL_VISUALS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
