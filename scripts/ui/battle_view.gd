class_name BattleView
extends Control

signal battle_finished(simulation: BattleSimulation)
signal combat_event(kind: String, strength: float)

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const VISIBLE_WORLD_SCALE := 1.2
const HEALTH_BAR_WIDTH := 238.0
const HEALTH_BAR_HEIGHT := 16.0
const HEALTH_VALUE_FONT_SIZE := 21
const HEALTH_NAME_FONT_SIZE := 17

var simulation: BattleSimulation
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
		var ids := BallRegistry.ids()
		start_battle(20260815, ids[0], ids[1])
	set_process(true)

func start_battle(seed_value: int, left_ball_id: String, right_ball_id: String, time_limit_seconds: float = -1.0) -> void:
	simulation = BattleSimulationScript.new(seed_value, left_ball_id, right_ball_id, time_limit_seconds)
	left_visual = simulation.left_module.create_visual(simulation.left_ability, simulation.left_profile)
	right_visual = simulation.right_module.create_visual(simulation.right_ability, simulation.right_profile)
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
		while _accumulator >= BattleSimulation.FIXED_STEP and steps < 32:
			simulation.step(BattleSimulation.FIXED_STEP)
			_accumulator -= BattleSimulation.FIXED_STEP
			steps += 1
		_check_combat_events()
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
	for event in simulation.take_combat_events():
		combat_event.emit(String(event["kind"]), float(event["strength"]))

func _sound_kind(ball_id: String) -> String:
	var module: BallModule = BallRegistry.get_module(ball_id)
	return module.sound_kind

func _draw() -> void:
	if simulation == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("050608"))
	draw_set_transform(_shake_offset, 0.0, Vector2.ONE)
	_draw_background_grid()
	_draw_beams()
	_draw_trails()
	_draw_entities()
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

func visible_world_size() -> Vector2:
	return BattleSimulation.ARENA_SIZE * VISIBLE_WORLD_SCALE

func arena_screen_rect() -> Rect2:
	return Rect2(_origin(), BattleSimulation.ARENA_SIZE * _scale_factor())

func health_hud_bounds(side: int) -> Rect2:
	var x := 13.0 if side == 0 else size.x - 13.0 - HEALTH_BAR_WIDTH
	return Rect2(Vector2(x, 31.0), Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT))

func _scale_factor() -> float:
	var world_size := visible_world_size()
	return minf(size.x / world_size.x, size.y / world_size.y)

func _origin() -> Vector2:
	return (size - BattleSimulation.ARENA_SIZE * _scale_factor()) * 0.5

func _p(value: Vector2) -> Vector2:
	return _origin() + value * _scale_factor()

func _draw_background_grid() -> void:
	var scale_factor := _scale_factor()
	draw_rect(arena_screen_rect(), Color("080b0e"))
	for coordinate in range(80, 640, 80):
		var alpha := 0.055 if coordinate % 160 != 0 else 0.085
		draw_line(_p(Vector2(coordinate, 0.0)), _p(Vector2(coordinate, 640.0)), Color(0.5, 0.68, 0.78, alpha), 1.0)
		draw_line(_p(Vector2(0.0, coordinate)), _p(Vector2(640.0, coordinate)), Color(0.5, 0.68, 0.78, alpha), 1.0)
	draw_circle(_p(Vector2(320.0, 320.0)), 218.0 * scale_factor, Color(0.55, 0.66, 0.72, 0.06), false, 1.5)
	draw_circle(_p(Vector2(320.0, 320.0)), 105.0 * scale_factor, Color(0.55, 0.66, 0.72, 0.05), false, 1.0)

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

func _draw_trail(fighter: BattleSimulation.FighterState, visual: BallVisual) -> void:
	if fighter.trail.size() < 2:
		return
	for index in range(1, fighter.trail.size()):
		var progress := 1.0 - float(index) / float(fighter.trail.size())
		var color := fighter.accent
		color.a = progress * visual.trail_alpha()
		draw_line(_p(fighter.trail[index - 1]), _p(fighter.trail[index]), color, fighter.radius * 0.52 * progress * visual.trail_width_multiplier() * _scale_factor(), true)

func _draw_entities() -> void:
	var ordered := simulation.entities.duplicate()
	ordered.sort_custom(func(left: BallEntity, right: BallEntity): return left.draw_layer < right.draw_layer)
	var context := BallRenderContext.new(
		_origin(),
		_scale_factor(),
		size,
		_shake_offset,
		simulation.elapsed,
		simulation.left,
		simulation.right,
		simulation.count_entities
	)
	for entity in ordered:
		if not entity.removed:
			entity.draw(self, context)

func _visual_context(fighter: BattleSimulation.FighterState) -> Dictionary:
	return {
		"position": _p(fighter.pos),
		"radius": fighter.radius * _scale_factor(),
		"scale_factor": _scale_factor(),
		"elapsed": simulation.elapsed,
		"shake_offset": _shake_offset,
	}

func _draw_underlay(fighter: BattleSimulation.FighterState, visual: BallVisual) -> void:
	visual.draw_underlay(self, fighter, _visual_context(fighter))

func _draw_ball(fighter: BattleSimulation.FighterState, visual: BallVisual) -> void:
	var context := _visual_context(fighter)
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	visual.draw_ball(self, fighter, context)
	for effect in fighter.status_effects:
		effect.draw_overlay(self, fighter, context)
	if fighter.hit_flash > 0.0:
		draw_circle(position, radius, Color(1.0, 1.0, 1.0, fighter.hit_flash * 0.52))
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
	var left_bounds := health_hud_bounds(0)
	var right_bounds := health_hud_bounds(1)
	var left_health := "%d / %d" % [int(ceil(simulation.left.hp)), int(simulation.left.max_hp)]
	var right_health := "%d / %d" % [int(ceil(simulation.right.hp)), int(simulation.right.max_hp)]
	_draw_health_hud_panel(
		left_bounds,
		simulation.left.display_name,
		left_health,
		simulation.left.hp_ratio(),
		left_color,
		false
	)
	_draw_health_hud_panel(
		right_bounds,
		simulation.right.display_name,
		right_health,
		simulation.right.hp_ratio(),
		right_color,
		true
	)
	_draw_entity_hud(left_bounds, right_bounds)
	draw_string(_font, Vector2(size.x * 0.5 - 48.0, 34.0), "%02d" % int(maxf(0.0, simulation.max_battle_time - simulation.elapsed)), HORIZONTAL_ALIGNMENT_CENTER, 96.0, 20, Color("e9eef2"))

func _draw_entity_hud(left_bounds: Rect2, right_bounds: Rect2) -> void:
	for entity in simulation.entities:
		if entity.removed or entity.is_captured() or entity.owner_side < 0:
			continue
		var health_bar_bounds := left_bounds if entity.owner_side == 0 else right_bounds
		entity.draw_hud(self, health_bar_bounds)

func _draw_health_hud_panel(bounds: Rect2, display_name: String, health_text: String, ratio: float, color: Color, align_right: bool) -> void:
	var panel_bounds := Rect2(
		Vector2(bounds.position.x - 6.0, 3.0),
		Vector2(bounds.size.x + 12.0, bounds.end.y)
	)
	var panel_outline := Color(color.r, color.g, color.b, 0.3)
	draw_rect(panel_bounds, Color(0.012, 0.016, 0.022, 0.9))
	draw_rect(panel_bounds, panel_outline, false, 1.5)

	var name_width := 92.0
	var value_width := bounds.size.x - name_width
	var label_baseline := bounds.position.y - 7.0
	var name_color := color.lerp(Color.WHITE, 0.32)
	name_color.a = 1.0
	var value_color := Color("ff978a") if ratio <= 0.25 else Color.WHITE
	if align_right:
		_draw_hud_text(health_text, Vector2(bounds.position.x, label_baseline), value_width, HEALTH_VALUE_FONT_SIZE, value_color, HORIZONTAL_ALIGNMENT_LEFT)
		_draw_hud_text(display_name, Vector2(bounds.position.x + value_width, label_baseline), name_width, HEALTH_NAME_FONT_SIZE, name_color, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_draw_hud_text(display_name, Vector2(bounds.position.x, label_baseline), name_width, HEALTH_NAME_FONT_SIZE, name_color, HORIZONTAL_ALIGNMENT_LEFT)
		_draw_hud_text(health_text, Vector2(bounds.position.x + name_width, label_baseline), value_width, HEALTH_VALUE_FONT_SIZE, value_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_health_bar(bounds, ratio, color, align_right)

func _draw_hud_text(text: String, position: Vector2, width: float, font_size: int, color: Color, alignment: int) -> void:
	draw_string(_font, position + Vector2(1.5, 1.5), text, alignment, width, font_size, Color(0.0, 0.0, 0.0, 0.95))
	draw_string(_font, position, text, alignment, width, font_size, color)

func _draw_health_bar(bounds: Rect2, ratio: float, color: Color, fill_from_right: bool) -> void:
	var clamped_ratio := clampf(ratio, 0.0, 1.0)
	var glow_color := Color(color.r, color.g, color.b, 0.36)
	var fill_width := bounds.size.x * clamped_ratio
	var fill_x := bounds.end.x - fill_width if fill_from_right else bounds.position.x
	var fill_bounds := Rect2(Vector2(fill_x, bounds.position.y), Vector2(fill_width, bounds.size.y))
	var fill_color := color.lerp(Color.WHITE, 0.16)
	fill_color.a = 1.0
	draw_rect(bounds.grow(3.0), Color(0.0, 0.0, 0.0, 0.78))
	draw_rect(bounds.grow(2.0), glow_color, false, 3.0)
	draw_rect(bounds, Color(0.018, 0.022, 0.028, 0.98))
	draw_rect(fill_bounds, fill_color)
	if fill_width > 1.0:
		draw_rect(Rect2(fill_bounds.position, Vector2(fill_bounds.size.x, 3.0)), Color(1.0, 1.0, 1.0, 0.2))
	draw_rect(bounds, Color(0.94, 0.96, 0.98, 0.94), false, 2.0)

func _draw_border() -> void:
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), Color("59626b"), false, 2.0)
	draw_rect(arena_screen_rect(), Color("f4f4f4"), false, 3.0)

func _draw_result_card() -> void:
	draw_rect(Rect2(Vector2(70.0, size.y * 0.36), Vector2(size.x - 140.0, 168.0)), Color(0.01, 0.01, 0.015, 0.9))
	var winner := simulation.winner()
	_draw_centered_text(winner.display_name + " 获胜", size.y * 0.36 + 65.0, 38, winner.accent)
	_draw_centered_text(simulation.finish_reason + " · %.1f 秒" % simulation.elapsed, size.y * 0.36 + 112.0, 24, Color("e8e8e8"))

func _draw_centered_text(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	draw_string(_font, Vector2(0.0, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
