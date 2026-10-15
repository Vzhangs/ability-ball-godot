extends SceneTree

const View := preload("res://scripts/ui/battle_view.gd")
const Setup := preload("res://scripts/simulation/battle_setup.gd")
const Death := preload("res://scripts/balls/core/fighter_death_effect_entity.gd")

var failures: Array[String] = []
var capture_dir := ""

class LayerView extends "res://scripts/ui/battle_view.gd":
	var draw_events: Array[String] = []

	func _draw() -> void:
		draw_events.clear()
		super()

	func _draw_beams() -> void:
		draw_events.append("beam")
		super()

	func _draw_particles() -> void:
		draw_events.append("particles")
		super()

	func _draw_center_value(position: Vector2, text: String, radius: float, color: Color) -> void:
		draw_events.append("health")
		super(position, text, radius, color)

class LayerShield extends "res://scripts/balls/core/invulnerability_status_effect.gd":
	var draw_events: Array[String]

	func _init(events: Array[String]) -> void:
		super(1.0, 0, "visual_layer_probe")
		draw_events = events

	func draw_topmost_overlay(canvas: CanvasItem, fighter, context: Dictionary) -> void:
		draw_events.append("shield")
		super(canvas, fighter, context)

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	BallRegistry.configure_settings({})
	_check_budgets_and_expiry()
	_check_visual_rng_isolation()
	await _check_view_lifecycle()
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(capture_dir)
		await _capture_scenarios()
	if failures.is_empty():
		print("ABILITY_BALL_VISUAL_PRESENTATION_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_budgets_and_expiry() -> void:
	var sim := BattleSimulation.new(8127, "test_ball", "test_ball")
	for index in range(160):
		sim.spawn_particles(Vector2(index, 200), Color.CYAN, 40, 180)
		sim.spawn_ring(Vector2(index, 200), Color.CYAN, 0, 64, 0.5)
	_check(sim.particles.size() == BattleSimulation.MAX_VISUAL_PARTICLES, "Particle budget must stay bounded during a burst storm")
	_check(sim.impact_rings.size() == BattleSimulation.MAX_IMPACT_RINGS, "Ring budget must stay bounded during a burst storm")
	_check(sim.particles.back().pos == Vector2(159, 200), "New contacts remain visible at the visual budget")
	sim._update_transient_visuals(1.0)
	_check(sim.particles.is_empty() and sim.impact_rings.is_empty(), "All transient effects expire")
	sim.spawn_ring(Vector2.ZERO, Color.WHITE, 0, 10, 0)
	_check(sim.impact_rings.is_empty(), "A zero-duration ring cannot introduce invalid geometry")
	sim.fighter_for_side(sim.teams[0].team_id).pos = Vector2(sim.fighter_for_side(sim.teams[0].team_id).radius - 2, 250)
	sim.fighter_for_side(sim.teams[0].team_id).velocity = Vector2(-180, 0)
	sim._resolve_wall(sim.fighter_for_side(sim.teams[0].team_id))
	_check(sim.impact_rings.back().pos == Vector2(0, 250), "Wall feedback must originate at the physical boundary")
	_check(is_equal_approx(sim.fighter_for_side(sim.teams[0].team_id).hp, sim.fighter_for_side(sim.teams[0].team_id).max_hp), "Decorative wall feedback must not damage the fighter")

func _check_visual_rng_isolation() -> void:
	var plain := BattleSimulation.new(88231, "flame", "replicator", 30)
	var decorated := BattleSimulation.new(88231, "flame", "replicator", 30)
	for frame in range(1801):
		if frame % 7 == 0:
			decorated.spawn_particles(Vector2(320, 320), Color.CYAN, 40, 160)
			decorated.spawn_ring(Vector2(320, 320), Color.CYAN, 2, 80, 0.4)
		plain.step(BattleSimulation.FIXED_STEP)
		decorated.step(BattleSimulation.FIXED_STEP)
		if frame % 120 == 0:
			_check(plain.snapshot() == decorated.snapshot(), "Additional VFX must not alter combat at frame %d" % frame)
	_check(plain.snapshot() == decorated.snapshot(), "Outcome and combat ledger are independent of VFX volume")

func _check_view_lifecycle() -> void:
	var view := View.new()
	view.start_battle(4123, "flame", "frost")
	view.paused = true
	root.add_child(view)
	view.simulation.spawn_particles(Vector2(320, 320), Color.CYAN, 8, 120)
	var frozen := view.simulation.particles.duplicate(true)
	view._process(0.1)
	_check(view.simulation.particles == frozen, "Pause freezes all particle ages and positions")
	view.paused = false
	view._process(0.1)
	_check(view.simulation.particles != frozen, "Resume advances the particle timeline")
	view.start_battle(4123, "flame", "frost")
	_check(view.simulation.particles.is_empty() and view.simulation.impact_rings.is_empty(), "Restart clears previous battle VFX")
	view.queue_free()
	await process_frame

func _capture_scenarios() -> void:
	root.size = Vector2i(1080, 1200)
	root.content_scale_size = Vector2i(650, 722)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var scenarios := [
		["elemental", "flame", "frost", 10.0],
		["ranged", "prism", "replicator", 18.0],
		["swarm", "black_hole", "splitter", 24.0],
	]
	for scenario in scenarios:
		var view := View.new()
		view.start_battle(20260817, scenario[1], scenario[2])
		view.paused = true
		root.add_child(view)
		for frame in range(int(float(scenario[3]) * 60.0)):
			view.simulation.step(BattleSimulation.FIXED_STEP)
			view._sync_hud_feedback()
		await _capture(view, String(scenario[0]) + "-1080")
		if scenario[0] == "elemental":
			root.size = Vector2i(540, 600)
			await _capture(view, "elemental-540")
			root.size = Vector2i(1080, 1200)
		view.queue_free()
		await process_frame
	var impacts := View.new()
	impacts.start_battle(1234, "sonic", "test_ball")
	impacts.paused = true
	root.add_child(impacts)
	impacts.simulation.fighter_for_side(impacts.simulation.teams[0].team_id).pos = Vector2(286, 320)
	impacts.simulation.fighter_for_side(impacts.simulation.teams[1].team_id).pos = Vector2(340, 320)
	for age in [0.0, 0.08, 0.22, 0.41, 0.8]:
		impacts.simulation.impact_rings.clear()
		impacts.simulation.particles.clear()
		impacts.simulation.spawn_ring(Vector2(313, 320), Color("ffdf9a"), 4, 85, 0.42)
		impacts.simulation.spawn_particles(Vector2(313, 320), Color("ffdf9a"), 22, 240)
		impacts.simulation._update_transient_visuals(age)
		await _capture(impacts, "impact-%03d" % int(age * 1000))
	for progress in [0.0, 0.2, 0.6, 1.0]:
		impacts.simulation.entities.clear()
		var death := Death.new(0, Vector2(310, 330), 27, Color("ff754f"), Color("ffd895"), 1.2)
		death.remaining = 1.2 * (1.0 - progress)
		impacts.simulation.add_entity(death)
		await _capture(impacts, "death-%03d" % int(progress * 1000))
	impacts.queue_free()
	await process_frame
	await _capture_modes()
	await _capture_shield_layers()
	await _capture_density()

func _capture_shield_layers() -> void:
	var view := LayerView.new()
	view.start_battle(215, "test_ball", "test_ball")
	view.paused = true
	root.add_child(view)
	view.simulation.fighter_for_side(view.simulation.teams[0].team_id).status_effects.append(LayerShield.new(view.draw_events))
	var unit := BallEntity.new()
	unit.pos = Vector2(320, 320)
	unit.radius = 20
	unit.status_effects.append(LayerShield.new(view.draw_events))
	view.simulation.add_entity(unit)
	view.simulation.add_beam(Vector2(80, 320), Vector2(560, 320), Color.CYAN, 0.5, 22)
	view.simulation.spawn_particles(view.simulation.fighter_for_side(view.simulation.teams[0].team_id).pos, Color.CYAN, 28, 180)
	await _capture(view, "shield-over-beam")
	_check(view.draw_events.count("shield") == 2, "Fighter and attachment shields are each drawn exactly once")
	_check(view.draw_events.find("shield") > view.draw_events.find("particles"), "Topmost shields cover particles")
	_check(view.draw_events.find("shield") > view.draw_events.find("beam"), "Topmost shields cover beams")
	_check(view.draw_events.count("health") == 2 and view.draw_events.find("shield") > view.draw_events.rfind("health"), "Topmost shields cover both fighter health labels")
	view.queue_free()
	await process_frame

func _capture_modes() -> void:
	var view := View.new()
	view.start_battle_setup(2315, Setup.relay(["flame", "prism"], ["frost", "sonic"]), 120, Vector2(440, 740))
	view.paused = true
	root.add_child(view)
	for frame in range(360):
		view.simulation.step(BattleSimulation.FIXED_STEP)
		view._sync_hud_feedback()
	root.size = Vector2i(540, 600)
	await _capture(view, "relay-tall-540")
	view.queue_free()
	await process_frame
	root.size = Vector2i(1080, 1200)

func _capture_density() -> void:
	var view := View.new()
	var setup := Setup.new(Setup.MODE_TEAM_BRAWL, [
		Setup.team(0, "红队", ["flame", "prism", "plant", "splitter"], 4),
		Setup.team(1, "蓝队", ["frost", "replicator", "heavy_industry", "sonic"], 4),
	])
	view.start_battle_setup(81231, setup)
	view.paused = true
	root.add_child(view)
	for frame in range(900):
		view.simulation.step(BattleSimulation.FIXED_STEP)
		view._sync_hud_feedback()
	await _capture(view, "team-brawl")
	view.simulation.spawn_particles(Vector2(320, 320), Color.CYAN, 800, 250)
	var timings: Array[float] = []
	for frame in range(90):
		var start := Time.get_ticks_usec()
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		timings.append(float(Time.get_ticks_usec() - start) / 1000.0)
	timings.sort()
	print("VFX_STRESS_FRAME_MS median=", timings[45], " p95=", timings[85], " particles=", view.simulation.particles.size(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	view.queue_free()
	await process_frame

func _capture(view: BattleView, name: String) -> void:
	var snapshot := view.simulation.snapshot()
	var visual_random_state := view.simulation.visual_rng.state
	root.content_scale_size = Vector2i(650, ceili(view.size.y))
	root.size = Vector2i(root.size.x, roundi(float(root.size.x) * view.size.y / 650.0))
	view._sync_fighter_visuals()
	view.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_check(view.simulation.snapshot() == snapshot, "Rendering leaves combat unchanged: " + name)
	_check(view.simulation.visual_rng.state == visual_random_state, "Rendering does not consume random state: " + name)
	_check(view._particle_presentation._halos.visible_instance_count == view.simulation.particles.size(), "Particle batch matches the live timeline: " + name)
	var result := root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
	_check(result == OK, "Screenshot saved: " + name)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
