extends SceneTree

const View := preload("res://scripts/ui/battle_view.gd")
var capture_dir := ""
var failures: Array[String] = []

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	root.size = Vector2i(1080, 1200)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for ball in ["qing", "gale"]:
		var view := View.new()
		view.start_battle(391, ball, "test_ball", 120)
		view.paused = true
		root.add_child(view)
		for frame in range(1201):
			view.simulation.step(BattleSimulation.FIXED_STEP)
			view._sync_hud_feedback()
			if frame in [0, 600, 1200]:
				await capture(view, ball + "-natural-%04d-1080" % frame)
		if ball == "qing":
			var sim = view.simulation
			var nodes := sim.entity_list(0, "qing_athena")
			for i in range(nodes.size()):
				nodes[i].pos = [Vector2(170, 180), Vector2(460, 250), Vector2(300, 490)][i]
				nodes[i].velocity = Vector2.ZERO
				nodes[i].set("_age", 0.0)
			for arc in sim.entity_list(0, "qing_arc"): arc.set("_age", 0.0)
			sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(160, 410)
			sim.fighter_for_side(sim.teams[1].team_id).pos = Vector2(320, 220)
			for delta in [0.0, 0.09, 0.1, 0.25]:
				sim._update_entities(delta)
				await capture(view, "qing-staged-%03d" % int(delta * 1000))
		root.size = Vector2i(540, 600)
		await capture(view, ball + "-540")
		view.queue_free()
		await process_frame
		root.size = Vector2i(1080, 1200)
	if failures.is_empty():
		print("ABILITY_BALL_QING_GALE_VISUAL_OK")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func capture(view: BattleView, label: String) -> void:
	var snapshot := view.simulation.snapshot()
	var random_state := view.simulation.visual_rng.state
	root.content_scale_size = Vector2i(650, ceili(view.size.y))
	root.size = Vector2i(root.size.x, roundi(root.size.x * view.size.y / 650.0))
	view._sync_fighter_visuals()
	view.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not capture_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(capture_dir)
			if root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png")) != OK:
				failures.append("Screenshot failed: " + label)
	if snapshot != view.simulation.snapshot() or random_state != view.simulation.visual_rng.state:
		failures.append("Rendering mutated battle: " + label)
