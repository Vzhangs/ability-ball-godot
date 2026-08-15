class_name RosterBattleView
extends Control

signal state_changed(simulation: RosterBattleSimulation)
signal battle_finished(simulation: RosterBattleSimulation)
signal combat_event(kind: String, strength: float)

const RosterSimulationScript := preload("res://scripts/simulation/roster_battle_simulation.gd")

var simulation: RosterBattleSimulation
var left_visual: BallVisual
var right_visual: BallVisual
var simulation_speed := 1.0
var paused := false
var _accumulator := 0.0
var _finish_emitted := false
var _last_contact_hits := 0
var _last_abilities := {}
var _font: Font
var _shake_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = ThemeDB.fallback_font
	if simulation == null:
		start_battle(20260815, "splitter", "black_hole")
	set_process(true)

func start_battle(seed_value: int, left_ball_id: String = "splitter", right_ball_id: String = "black_hole") -> void:
	simulation = RosterSimulationScript.new(seed_value, left_ball_id, right_ball_id)
	left_visual = simulation.left_module.create_visual()
	right_visual = simulation.right_module.create_visual()
	_accumulator = 0.0
	_finish_emitted = false
	_last_contact_hits = 0
	_last_abilities.clear()
	for ball_id in BallRegistry.ids():
		_last_abilities[ball_id] = 0
	queue_redraw()

func set_paused(value: bool) -> void:
	paused = value

func set_simulation_speed(value: float) -> void:
	simulation_speed = clampf(value, 0.25, 8.0)

func _process(delta: float) -> void:
	if simulation == null:
		return
	if not paused:
		_accumulator += minf(delta, 0.1) * simulation_speed
		var steps := 0
		while _accumulator >= RosterBattleSimulation.FIXED_STEP and steps < 32:
			simulation.step(RosterBattleSimulation.FIXED_STEP)
			_accumulator -= RosterBattleSimulation.FIXED_STEP
			steps += 1
		_check_combat_events()
		state_changed.emit(simulation)
	if simulation.camera_shake > 0.0:
		var strength := simulation.camera_shake
		_shake_offset = Vector2(sin(simulation.elapsed * 93.0), cos(simulation.elapsed * 79.0)) * strength
	else:
		_shake_offset = _shake_offset.lerp(Vector2.ZERO, minf(1.0, delta * 18.0))
	if simulation.finished and not _finish_emitted:
		_finish_emitted = true
		battle_finished.emit(simulation)
	queue_redraw()

func _check_combat_events() -> void:
	if int(simulation.stats["contact_hits"]) > _last_contact_hits:
		combat_event.emit("impact", 0.75)
	_last_contact_hits = int(simulation.stats["contact_hits"])
	var abilities: Dictionary = simulation.stats["abilities"]
	for ball_id in [simulation.left.id, simulation.right.id]:
		if int(abilities[ball_id]) > int(_last_abilities[ball_id]):
			combat_event.emit(_sound_kind(ball_id), 0.7)
		_last_abilities[ball_id] = int(abilities[ball_id])

func _sound_kind(ball_id: String) -> String:
	var module: BallModule = BallRegistry.get_module(ball_id)
	return module.sound_kind

func _draw() -> void:
	if simulation == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("050608"))
	draw_set_transform(_shake_offset, 0.0, Vector2.ONE)
	_draw_background_grid()
	_draw_fire_zones()
	_draw_gravity_wells()
	_draw_anchors()
	_draw_beams()
	_draw_trails()
	_draw_projectiles()
	_draw_underlay(simulation.left, left_visual)
	_draw_underlay(simulation.right, right_visual)
	_draw_ball(simulation.left, left_visual)
	_draw_ball(simulation.right, right_visual)
	_draw_impact_rings()
	_draw_particles()
	_draw_floating_texts()
	_draw_arena_hud()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_border()
	if simulation.finished:
		_draw_result_card()

func _scale_factor() -> float:
	return minf(size.x / RosterBattleSimulation.ARENA_SIZE.x, size.y / RosterBattleSimulation.ARENA_SIZE.y)

func _origin() -> Vector2:
	return (size - RosterBattleSimulation.ARENA_SIZE * _scale_factor()) * 0.5

func _p(value: Vector2) -> Vector2:
	return _origin() + value * _scale_factor()

func _draw_background_grid() -> void:
	var scale_factor := _scale_factor()
	for coordinate in range(80, 640, 80):
		var alpha := 0.055 if coordinate % 160 != 0 else 0.085
		draw_line(_p(Vector2(coordinate, 0.0)), _p(Vector2(coordinate, 640.0)), Color(0.5, 0.68, 0.78, alpha), 1.0)
		draw_line(_p(Vector2(0.0, coordinate)), _p(Vector2(640.0, coordinate)), Color(0.5, 0.68, 0.78, alpha), 1.0)
	draw_circle(_p(Vector2(320.0, 320.0)), 218.0 * scale_factor, Color(0.55, 0.66, 0.72, 0.06), false, 1.5)
	draw_circle(_p(Vector2(320.0, 320.0)), 105.0 * scale_factor, Color(0.55, 0.66, 0.72, 0.05), false, 1.0)

func _draw_fire_zones() -> void:
	var scale_factor := _scale_factor()
	for zone in simulation.fire_zones:
		var alpha := clampf(float(zone["ttl"]) / float(zone["duration"]), 0.0, 1.0)
		var position := _p(zone["pos"])
		var radius := float(zone["radius"]) * scale_factor
		draw_circle(position, radius, Color(1.0, 0.19, 0.02, alpha * 0.19))
		draw_circle(position, radius * 0.65, Color(1.0, 0.68, 0.08, alpha * 0.18))

func _draw_gravity_wells() -> void:
	var scale_factor := _scale_factor()
	for well in simulation.gravity_wells:
		var progress := 1.0 - float(well["ttl"]) / float(well["duration"])
		var alpha := sin(progress * PI)
		var position := _p(well["pos"])
		for ring in range(4):
			var radius := (45.0 + ring * 32.0 + progress * 24.0) * scale_factor
			draw_arc(position, radius, progress * TAU + ring, progress * TAU + ring + PI * 1.52, 48, Color(0.7, 0.27, 1.0, alpha * (0.34 - ring * 0.045)), 3.0, true)

func _draw_anchors() -> void:
	for anchor in simulation.anchors:
		var fighter := simulation.left if int(anchor["owner"]) == 0 else simulation.right
		var position := _p(anchor["pos"])
		var target := _p(fighter.pos)
		var alpha := clampf(float(anchor["ttl"]) / float(anchor["duration"]), 0.0, 1.0)
		draw_line(position, target, Color(0.59, 0.89, 1.0, alpha * 0.72), 2.0, true)
		var inward := (Vector2(size.x, size.y) * 0.5 - position).normalized()
		var tangent := Vector2(-inward.y, inward.x)
		var polygon := PackedVector2Array([position + inward * 20.0, position - inward * 6.0 + tangent * 8.0, position - inward * 6.0 - tangent * 8.0])
		draw_colored_polygon(polygon, Color(0.18, 1.0, 0.38, alpha))

func _draw_beams() -> void:
	for beam in simulation.beams:
		var color: Color = beam["color"]
		color.a = clampf(float(beam["ttl"]) / float(beam["duration"]), 0.0, 1.0) * 0.88
		var start := _p(beam["from"])
		var finish := _p(beam["to"])
		draw_line(start, finish, Color(color.r, color.g, color.b, color.a * 0.18), float(beam["width"]) * 2.4 * _scale_factor(), true)
		draw_line(start, finish, color, float(beam["width"]) * _scale_factor(), true)

func _draw_trails() -> void:
	_draw_trail(simulation.left, left_visual)
	_draw_trail(simulation.right, right_visual)

func _draw_trail(fighter: RosterBattleSimulation.FighterState, visual: BallVisual) -> void:
	if fighter.trail.size() < 2:
		return
	for index in range(1, fighter.trail.size()):
		var progress := 1.0 - float(index) / float(fighter.trail.size())
		var color := fighter.accent
		color.a = progress * visual.trail_alpha()
		draw_line(_p(fighter.trail[index - 1]), _p(fighter.trail[index]), color, fighter.radius * 0.52 * progress * visual.trail_width_multiplier() * _scale_factor(), true)

func _draw_projectiles() -> void:
	for projectile in simulation.projectiles:
		var position := _p(projectile["pos"])
		var radius := float(projectile["radius"]) * _scale_factor()
		var color: Color = projectile["color"]
		draw_circle(position, radius * 2.2, Color(color.r, color.g, color.b, 0.18))
		draw_circle(position, radius, color)
		draw_circle(position, radius * 0.42, Color.WHITE)

func _visual_context(fighter: RosterBattleSimulation.FighterState) -> Dictionary:
	return {
		"position": _p(fighter.pos),
		"radius": fighter.radius * _scale_factor(),
		"scale_factor": _scale_factor(),
		"elapsed": simulation.elapsed,
		"shake_offset": _shake_offset,
	}

func _draw_underlay(fighter: RosterBattleSimulation.FighterState, visual: BallVisual) -> void:
	visual.draw_underlay(self, fighter, _visual_context(fighter))

func _draw_ball(fighter: RosterBattleSimulation.FighterState, visual: BallVisual) -> void:
	var context := _visual_context(fighter)
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	visual.draw_ball(self, fighter, context)
	if fighter.hit_flash > 0.0:
		draw_circle(position, radius, Color(1.0, 1.0, 1.0, fighter.hit_flash * 0.52))
	if fighter.shield_flash > 0.0 or fighter.invulnerable > 0.0:
		var alpha := maxf(fighter.shield_flash, fighter.invulnerable)
		draw_circle(position, radius * 1.28, Color(1.0, 0.92, 0.38, alpha * 0.8), false, 4.0)
	_draw_center_value(position, str(int(ceil(fighter.hp))), radius, Color.WHITE)

func _draw_center_value(position: Vector2, text: String, radius: float, color: Color) -> void:
	var font_size := clampi(int(radius * 0.56), 12, 24)
	draw_string(_font, position + Vector2(-radius, font_size * 0.34), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, color)

func _draw_impact_rings() -> void:
	for ring in simulation.impact_rings:
		var color: Color = ring["color"]
		color.a = clampf(float(ring["ttl"]) / float(ring["duration"]), 0.0, 1.0) * 0.72
		draw_circle(_p(ring["pos"]), float(ring["radius"]) * _scale_factor(), color, false, 3.0)

func _draw_particles() -> void:
	for particle in simulation.particles:
		var color: Color = particle["color"]
		color.a *= clampf(float(particle["ttl"]) / float(particle["duration"]), 0.0, 1.0)
		draw_circle(_p(particle["pos"]), float(particle["size"]) * _scale_factor(), color)

func _draw_floating_texts() -> void:
	for item in simulation.floating_texts:
		var color: Color = item["color"]
		color.a *= clampf(float(item["ttl"]) / minf(0.22, float(item["duration"])), 0.0, 1.0)
		var position := _p(item["pos"])
		draw_string(_font, position + Vector2(-50.0, 0.0), str(item["text"]), HORIZONTAL_ALIGNMENT_CENTER, 100.0, 21, color)

func _draw_arena_hud() -> void:
	var left_color := simulation.left.accent
	var right_color := simulation.right.accent
	var bar_width := 205.0
	var bar_height := 8.0
	draw_rect(Rect2(Vector2(15.0, 15.0), Vector2(bar_width, bar_height)), Color(0.1, 0.11, 0.12, 0.88))
	draw_rect(Rect2(Vector2(15.0, 15.0), Vector2(bar_width * simulation.left.hp_ratio(), bar_height)), left_color)
	draw_rect(Rect2(Vector2(size.x - 15.0 - bar_width, 15.0), Vector2(bar_width, bar_height)), Color(0.1, 0.11, 0.12, 0.88))
	draw_rect(Rect2(Vector2(size.x - 15.0 - bar_width + bar_width * (1.0 - simulation.right.hp_ratio()), 15.0), Vector2(bar_width * simulation.right.hp_ratio(), bar_height)), right_color)
	draw_string(_font, Vector2(15.0, 43.0), simulation.left.display_name, HORIZONTAL_ALIGNMENT_LEFT, bar_width, 16, left_color)
	draw_string(_font, Vector2(size.x - 15.0 - bar_width, 43.0), simulation.right.display_name, HORIZONTAL_ALIGNMENT_RIGHT, bar_width, 16, right_color)
	draw_string(_font, Vector2(size.x * 0.5 - 48.0, 31.0), "%02d" % int(maxf(0.0, RosterBattleSimulation.MAX_BATTLE_TIME - simulation.elapsed)), HORIZONTAL_ALIGNMENT_CENTER, 96.0, 20, Color("e9eef2"))
	draw_string(_font, Vector2(size.x * 0.5 - 48.0, size.y - 16.0), "PHASE %d" % simulation.phase, HORIZONTAL_ALIGNMENT_CENTER, 96.0, 15, Color(1.0, 0.86, 0.32, 0.72))

func _draw_border() -> void:
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), Color("f4f4f4"), false, 4.0)
	if simulation.phase_flash > 0.0:
		draw_rect(Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0)), Color(1.0, 0.86, 0.24, simulation.phase_flash * 0.46), false, 5.0)

func _draw_result_card() -> void:
	draw_rect(Rect2(Vector2(70.0, size.y * 0.36), Vector2(size.x - 140.0, 168.0)), Color(0.01, 0.01, 0.015, 0.9))
	var winner := simulation.winner()
	_draw_centered_text(winner.display_name + " 获胜", size.y * 0.36 + 65.0, 38, winner.accent)
	_draw_centered_text(simulation.finish_reason + " · %.1f 秒" % simulation.elapsed, size.y * 0.36 + 112.0, 24, Color("e8e8e8"))

func _draw_centered_text(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	draw_string(_font, Vector2(0.0, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
