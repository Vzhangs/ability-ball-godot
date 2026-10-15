class_name BattleView
extends Control

signal battle_finished(simulation: BattleSimulation)
signal battle_resolved(simulation: BattleSimulation)
signal combat_event(kind: String, strength: float)

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const ResultPanelScript := preload("res://scripts/ui/battle_result_panel.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")
const Glow := preload("res://scripts/balls/core/combat_glow.gd")
const ArenaPresentation := preload("res://scripts/ui/arena_presentation.gd")
const ParticlePresentation := preload("res://scripts/ui/particle_presentation.gd")
const HudPresentation := preload("res://scripts/ui/hud_presentation.gd")
const HudGlassLayer := preload("res://scripts/ui/hud_glass_layer.gd")
const DEFAULT_VIEW_SIZE := Vector2(650.0, 700.0)
const VISIBLE_WORLD_SCALE := 1.2
const HEALTH_BAR_WIDTH := 238.0
const HEALTH_BAR_HEIGHT := 16.0
const HEALTH_VALUE_FONT_SIZE := 21
const HEALTH_NAME_FONT_SIZE := 17
const RELAY_HEALTH_BAR_Y := 121.0
const RELAY_HUD_BOTTOM := 150.0
const RELAY_ROSTER_AREA_TOP := 14.0
const RELAY_ROSTER_AREA_HEIGHT := 78.0
const RELAY_ROSTER_MAX_COLUMNS := 12
const RELAY_ROSTER_SIDE_MARGIN := 18.0
const RELAY_ROSTER_MAX_PITCH := 40.0
const RELAY_ROSTER_CENTER_GAP := 40.0
const RELAY_ROSTER_MODEL_SCALE := 1.15
const RELAY_ROSTER_NAME_FONT_SIZE := 9
const RELAY_TIMER_SIZE := Vector2(96.0, 46.0)
const RELAY_BOTTOM_VIEW_MARGIN := 24.0
const BALL_HEALTH_FONT_SCALE := 0.78
const BALL_HEALTH_FONT_MIN_SIZE := 15
const BALL_HEALTH_FONT_MAX_SIZE := 30
const BALL_HEALTH_OUTLINE_WIDTH := 2.0
const BALL_HEALTH_TEXT_ALPHA := 0.68
const BALL_HEALTH_OUTLINE_ALPHA := 0.54
const HEALTH_PANEL_BOTTOM := 84.0
const HUD_ARENA_GAP := 20.0
const MULTI_HUD_SIDE_MARGIN := 13.0
const MULTI_HUD_COLUMN_GAP := 8.0
const MULTI_HUD_CONTENT_TOP := 54.0
const MULTI_HUD_TEAM_HEADER_HEIGHT := 22.0
const MULTI_HUD_ROW_HEIGHT := 20.0
const MULTI_HUD_ROW_PITCH := 24.0
const MULTI_HUD_BAR_HEIGHT := 7.0
const MULTI_HUD_MAX_ROWS_PER_COLUMN := 8
const MULTI_HUD_BOTTOM_PADDING := 8.0
const MULTI_HUD_NAME_FONT_SIZE := 11
const MULTI_HUD_VALUE_FONT_SIZE := 10
const MULTI_TIMER_SIZE := Vector2(86.0, 36.0)
const DEFAULT_FLOATING_TEXT_FONT_SIZE := 21
const TEAM_MARKER_MAIN_WIDTH := 19.0
const TEAM_MARKER_MAIN_HEIGHT := 13.0
const TEAM_MARKER_MAIN_GAP := 6.0
const TEAM_MARKER_MAIN_BOB := 3.0
const TEAM_MARKER_ATTACHMENT_WIDTH := 11.0
const TEAM_MARKER_ATTACHMENT_HEIGHT := 8.0
const TEAM_MARKER_ATTACHMENT_GAP := 4.0
const TEAM_MARKER_ATTACHMENT_BOB := 2.0
const TEAM_MARKER_BOB_HZ := 1.15
const TEAM_MARKER_PALETTE := [
	Color("ff5c73"),
	Color("68d8ff"),
	Color("ffd166"),
	Color("a78bfa"),
	Color("5ee7a0"),
	Color("ff9f43"),
	Color("f472b6"),
	Color("d7f5ff"),
]

class HudRosterFighter:
	var color := Color.WHITE
	var accent := Color.WHITE
	var pos := Vector2.ZERO
	var velocity := Vector2.RIGHT * 180.0
	var rotation := 0.0

	func _init(module: BallModule) -> void:
		color = module.color
		accent = module.accent
		velocity = Vector2.RIGHT * module.speed

var simulation: BattleSimulation
var left_visual: BallVisual
var right_visual: BallVisual
var fighter_visuals := {}
var simulation_speed := 1.0
var paused := false
var result_auto_scroll := true
var result_panel: ResultPanelScript
var result_reveal_delay_seconds := GlobalGameSettingsScript.DEFAULT_RESULT_REVEAL_DELAY
var relay_handoff_pause_seconds := GlobalGameSettingsScript.DEFAULT_RELAY_HANDOFF_PAUSE
var relay_defeat_text_font_size := GlobalGameSettingsScript.DEFAULT_RELAY_DEFEAT_TEXT_FONT_SIZE
var damage_number_font_size := GlobalGameSettingsScript.DEFAULT_DAMAGE_NUMBER_FONT_SIZE
var damage_number_duration_seconds := GlobalGameSettingsScript.DEFAULT_DAMAGE_NUMBER_DURATION
var _accumulator := 0.0
var _finish_emitted := false
var _resolution_emitted := false
var _result_reveal_elapsed := 0.0
var _last_abilities := {}
var _roster_preview_visuals := {}
var _roster_preview_fighters := {}
var _font: Font
var _shake_offset := Vector2.ZERO
var _hud_panel_bottom := HEALTH_PANEL_BOTTOM
var _arena_presentation := ArenaPresentation.new()
var _particle_presentation := ParticlePresentation.new(BattleSimulation.MAX_VISUAL_PARTICLES)
var _hud_presentation := HudPresentation.new()
var _hud_glass_layer := HudGlassLayer.new()

func _init() -> void:
	add_child(_hud_glass_layer)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = CjkFontProviderScript.font()
	if simulation == null:
		var ids := BallRegistry.ids()
		start_battle(20260815, ids[0], ids[1])
	set_process(true)

func start_battle(
	seed_value: int,
	left_ball_id: String,
	right_ball_id: String,
	time_limit_seconds: float = -1.0,
	battle_arena_size: Vector2 = BattleSimulation.DEFAULT_ARENA_SIZE
) -> void:
	start_battle_setup(
		seed_value,
		BattleSetupScript.duel(left_ball_id, right_ball_id),
		time_limit_seconds,
		battle_arena_size
	)

func start_battle_setup(
	seed_value: int,
		setup,
		time_limit_seconds: float = -1.0,
		battle_arena_size: Vector2 = BattleSimulation.DEFAULT_ARENA_SIZE,
		battle_mode_rules: Dictionary = {}
		) -> void:
	var view_width := size.x if size.x > 0.0 else DEFAULT_VIEW_SIZE.x
	var active_counts := _setup_active_counts(setup)
	_hud_panel_bottom = hud_panel_bottom_for_mode(String(setup.mode), active_counts)
	size = view_size_for_arena(
		battle_arena_size,
		view_width,
		String(setup.mode),
		active_counts
	)
	simulation = BattleSimulationScript.new(
		seed_value,
		setup,
		time_limit_seconds,
		battle_arena_size,
		battle_mode_rules
	)
	simulation.death_effect_duration = maxf(BattleSimulation.FIXED_STEP, result_reveal_delay_seconds)
	simulation.handoff_pause_duration_seconds = maxf(BattleSimulation.FIXED_STEP, relay_handoff_pause_seconds)
	simulation.damage_number_duration_seconds = maxf(BattleSimulation.FIXED_STEP, damage_number_duration_seconds)
	fighter_visuals.clear()
	_build_roster_previews()
	_sync_fighter_visuals()
	_accumulator = 0.0
	_finish_emitted = false
	if result_panel != null:
		remove_child(result_panel)
		result_panel.queue_free()
		result_panel = null
	_resolution_emitted = false
	_result_reveal_elapsed = 0.0
	_hud_presentation.reset()
	_hud_glass_layer.update_bars([])
	_sync_hud_feedback()
	_last_abilities.clear()
	for ball_id in BallRegistry.ids():
		_last_abilities[ball_id] = 0
	queue_redraw()

func _sync_fighter_visuals() -> void:
	if simulation == null:
		return
	var active_uids := {}
	for fighter in simulation.active_fighters():
		active_uids[fighter.fighter_uid] = true
		if not fighter_visuals.has(fighter.fighter_uid):
			var module: BallModule = simulation.module_for_fighter(fighter)
			fighter_visuals[fighter.fighter_uid] = module.create_visual(
				simulation.ability_for_fighter(fighter)
			)
	for fighter_uid in fighter_visuals.keys():
		if not active_uids.has(fighter_uid):
			fighter_visuals.erase(fighter_uid)
	left_visual = fighter_visuals.get(simulation.fighter_for_side(simulation.teams[0].team_id).fighter_uid) if simulation.fighter_for_side(simulation.teams[0].team_id) != null else null
	right_visual = fighter_visuals.get(simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid) if simulation.fighter_for_side(simulation.teams[1].team_id) != null else null

func _build_roster_previews() -> void:
	_roster_preview_visuals.clear()
	_roster_preview_fighters.clear()
	if simulation == null:
		return
	for team in simulation.teams:
		for roster_index in range(team.roster.size()):
			var module: BallModule = BallRegistry.get_module(team.roster[roster_index])
			var preview_key := _roster_preview_key(team.team_id, roster_index)
			_roster_preview_visuals[preview_key] = module.create_visual()
			_roster_preview_fighters[preview_key] = HudRosterFighter.new(module)

func _roster_preview_key(team_id: int, roster_index: int) -> String:
	return "%d:%d" % [team_id, roster_index]

func set_paused(value: bool) -> void:
	paused = value

func set_simulation_speed(value: float) -> void:
	simulation_speed = clampf(value, 0.25, 8.0)

func _process(delta: float) -> void:
	if simulation == null:
		return
	if not paused:
		var presentation_delta := minf(delta, 0.1) * simulation_speed
		_accumulator += presentation_delta
		var steps := 0
		while _accumulator >= BattleSimulation.FIXED_STEP and steps < 32:
			simulation.step(BattleSimulation.FIXED_STEP)
			_sync_hud_feedback()
			_accumulator -= BattleSimulation.FIXED_STEP
			steps += 1
		if simulation.finished:
			_result_reveal_elapsed += presentation_delta
		_check_combat_events()
		if simulation.finished and not _resolution_emitted:
			_resolution_emitted = true
			battle_resolved.emit(simulation)
	_sync_fighter_visuals()
	if simulation.camera_shake > 0.0:
		var strength := simulation.camera_shake
		_shake_offset = Vector2(sin(simulation.elapsed * 93.0), cos(simulation.elapsed * 79.0)) * strength
	else:
		_shake_offset = _shake_offset.lerp(Vector2.ZERO, minf(1.0, delta * 18.0))
	_sync_result_panel()
	if result_reveal_ready() and not _finish_emitted:
		_finish_emitted = true
		battle_finished.emit(simulation)
	queue_redraw()

func result_reveal_ready() -> bool:
	return (
		simulation != null
		and simulation.finished
		and _result_reveal_elapsed >= _effective_result_reveal_delay()
	)

func result_reveal_progress() -> float:
	if simulation == null or not simulation.finished:
		return 0.0
	return clampf(
		_result_reveal_elapsed / maxf(BattleSimulation.FIXED_STEP, _effective_result_reveal_delay()),
		0.0,
		1.0
	)

func _effective_result_reveal_delay() -> float:
	var delay := maxf(0.0, result_reveal_delay_seconds)
	if simulation != null and simulation.battle_setup.mode == BattleSetupScript.MODE_RELAY:
		delay = maxf(delay, relay_handoff_pause_seconds)
	return delay

func _check_combat_events() -> void:
	var abilities: Dictionary = simulation.stats["abilities"]
	for ball_id in abilities:
		if int(abilities[ball_id]) > int(_last_abilities.get(ball_id, 0)):
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
	draw_rect(Rect2(Vector2.ZERO, size), Color("050a12"))
	draw_set_transform(_shake_offset, 0.0, Vector2.ONE)
	_draw_background_grid()
	_draw_trails()
	_draw_entities(false)
	for fighter in simulation.active_fighters():
		_draw_underlay(fighter, fighter_visuals[fighter.fighter_uid])
	for fighter in simulation.active_fighters():
		_draw_ball(fighter, fighter_visuals[fighter.fighter_uid])
	_draw_beams()
	for fighter in simulation.active_fighters():
		if fighter.hp > 0.0:
			_draw_center_value(_p(fighter.pos), str(int(ceil(fighter.hp))), fighter.radius * _scale_factor(), Color.WHITE)
	_draw_entities(true)
	_draw_impact_rings()
	_draw_particles()
	_draw_topmost_statuses()
	_draw_floating_texts()
	_draw_team_markers()
	_arena_presentation.draw_frame(self, arena_screen_rect(), simulation.elapsed)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_arena_hud()
	_draw_relay_handoff_notice()
	_draw_border()

func visible_world_size() -> Vector2:
	return size / _scale_factor()

func arena_screen_rect() -> Rect2:
	return Rect2(_origin(), _battle_arena_size() * _scale_factor())

func health_hud_bounds(side: int) -> Rect2:
	var x := 13.0 if side == 0 else size.x - 13.0 - HEALTH_BAR_WIDTH
	var y := RELAY_HEALTH_BAR_Y \
		if simulation != null and simulation.battle_setup.mode == BattleSetupScript.MODE_RELAY \
		else 45.0
	return Rect2(Vector2(x, y), Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT))

static func view_size_for_arena(
	arena_size: Vector2,
	view_width: float = DEFAULT_VIEW_SIZE.x,
	battle_mode: String = BattleSetupScript.MODE_DUEL,
	active_counts: Array = []
) -> Vector2:
	var safe_width := maxf(1.0, view_width)
	var safe_arena_width := maxf(1.0, arena_size.x)
	var safe_arena_height := maxf(1.0, arena_size.y)
	var horizontal_scale := safe_width / (safe_arena_width * VISIBLE_WORLD_SCALE)
	var bottom_margin_screen := RELAY_BOTTOM_VIEW_MARGIN \
		if battle_mode != BattleSetupScript.MODE_DUEL \
		else safe_arena_width * (VISIBLE_WORLD_SCALE - 1.0) * 0.5 * horizontal_scale
	var arena_top := hud_panel_bottom_for_mode(battle_mode, active_counts) + HUD_ARENA_GAP
	var required_height := (
		arena_top
		+ safe_arena_height * horizontal_scale
		+ bottom_margin_screen
	)
	return Vector2(safe_width, ceilf(required_height))

static func hud_panel_bottom_for_mode(battle_mode: String, active_counts: Array = []) -> float:
	if battle_mode == BattleSetupScript.MODE_RELAY:
		return RELAY_HUD_BOTTOM
	if BattleSetupScript.allows_team_editing(battle_mode):
		var team_count := maxi(2, active_counts.size())
		var row_count := ceili(float(team_count) / 2.0)
		return MULTI_HUD_CONTENT_TOP + float(row_count) * MULTI_HUD_ROW_PITCH + MULTI_HUD_BOTTOM_PADDING
	if battle_mode == BattleSetupScript.MODE_TEAM_BRAWL:
		var maximum_count := 1
		for raw_count in active_counts:
			maximum_count = maxi(maximum_count, int(raw_count))
		var row_count := mini(MULTI_HUD_MAX_ROWS_PER_COLUMN, maximum_count)
		return (
			MULTI_HUD_CONTENT_TOP
			+ MULTI_HUD_TEAM_HEADER_HEIGHT
			+ float(row_count) * MULTI_HUD_ROW_PITCH
			+ MULTI_HUD_BOTTOM_PADDING
		)
	return HEALTH_PANEL_BOTTOM

static func _setup_active_counts(setup) -> Array:
	var counts: Array[int] = []
	if setup == null:
		return counts
	for team_spec in setup.teams:
		counts.append(int(team_spec.get("active_count", 1)))
	return counts

func _scale_factor() -> float:
	var arena_size := _battle_arena_size()
	return maxf(0.0001, size.x / maxf(1.0, arena_size.x * VISIBLE_WORLD_SCALE))

func _origin() -> Vector2:
	var centered_origin := (size - _battle_arena_size() * _scale_factor()) * 0.5
	centered_origin.y = maxf(centered_origin.y, _hud_panel_bottom + HUD_ARENA_GAP)
	return centered_origin

func _battle_arena_size() -> Vector2:
	return simulation.arena_size() if simulation != null else BattleSimulation.DEFAULT_ARENA_SIZE

func _p(value: Vector2) -> Vector2:
	return _origin() + value * _scale_factor()

func _draw_background_grid() -> void:
	_arena_presentation.draw_floor(self, arena_screen_rect(), simulation.elapsed)

func _draw_beams() -> void:
	for beam in simulation.beams:
		var color: Color = beam["color"]
		color.a = clampf(float(beam["ttl"]) / float(beam["duration"]), 0.0, 1.0) * 0.88
		var start := _p(beam["from"])
		var finish := _p(beam["to"])
		var width := float(beam["width"]) * _scale_factor()
		Glow.streak(self, start, finish, color, width)
		Glow.halo(self, start, width * 5.0, Color(color, color.a * 0.42))
		Glow.halo(self, finish, width * 7.0, Color(color, color.a * 0.52))

func _draw_trails() -> void:
	for fighter in simulation.active_fighters():
		_draw_trail(fighter, fighter_visuals[fighter.fighter_uid])

func _draw_trail(fighter: BattleSimulation.FighterState, visual: BallVisual) -> void:
	if fighter.hp <= 0.0:
		return
	if fighter.trail.size() < 2:
		return
	var points := PackedVector2Array([_p(fighter.pos)])
	var colors := PackedColorArray([Color(fighter.accent, visual.trail_alpha())])
	for index in range(fighter.trail.size()):
		var progress := 1.0 - float(index) / float(fighter.trail.size())
		var point := _p(fighter.trail[index])
		if points[-1].distance_squared_to(point) > 0.01:
			points.append(point)
			colors.append(Color(fighter.accent, progress * progress * visual.trail_alpha()))
	if points.size() < 2:
		return
	var width := fighter.radius * 0.48 * visual.trail_width_multiplier() * _scale_factor()
	var glow_colors := PackedColorArray()
	var core_colors := PackedColorArray()
	for color in colors:
		glow_colors.append(Color(color, color.a * 0.18))
		core_colors.append(Color(color.lerp(Color.WHITE, 0.60), color.a * 0.62))
	draw_polyline_colors(points, glow_colors, maxf(0.5, width * 2.2), true)
	draw_polyline_colors(points, colors, maxf(0.5, width), true)
	draw_polyline_colors(points, core_colors, maxf(0.5, width * 0.22), true)

func _draw_entities(above_balls: bool) -> void:
	var ordered := simulation.entities.duplicate()
	ordered.sort_custom(func(left: BallEntity, right: BallEntity): return left.draw_layer < right.draw_layer)
	var context := BallRenderContext.new(
		_origin(),
		_scale_factor(),
		size,
		_shake_offset,
		simulation.elapsed,
		simulation.active_fighters(),
		simulation.count_entities
	)
	for entity in ordered:
		if entity.removed or entity.draws_above_balls() != above_balls:
			continue
		entity.draw(self, context)
		_draw_entity_statuses(entity, context)

func _draw_entity_statuses(entity: BallEntity, render_context: BallRenderContext) -> void:
	if entity.status_effects.is_empty():
		return
	var context := {
		"position": entity.screen_position(render_context),
		"radius": entity.radius * render_context.scale_factor,
		"scale_factor": render_context.scale_factor,
		"elapsed": simulation.elapsed,
		"shake_offset": _shake_offset,
	}
	for entity_status: BallStatusEffect in entity.status_effects:
		entity_status.draw_overlay(self, entity, context)

func _draw_topmost_statuses() -> void:
	for fighter in simulation.active_fighters():
		if fighter.hp <= 0.0:
			continue
		var context := _visual_context(fighter)
		for effect in fighter.status_effects:
			effect.draw_topmost_overlay(self, fighter, context)
	var render_context := BallRenderContext.new(_origin(), _scale_factor(), size, _shake_offset, simulation.elapsed, simulation.active_fighters(), simulation.count_entities)
	for entity in simulation.entities:
		if entity.removed or entity.status_effects.is_empty():
			continue
		var context := {
			"position": entity.screen_position(render_context),
			"radius": entity.radius * render_context.scale_factor,
			"scale_factor": render_context.scale_factor,
			"elapsed": simulation.elapsed,
			"shake_offset": _shake_offset,
		}
		for effect: BallStatusEffect in entity.status_effects:
			effect.draw_topmost_overlay(self, entity, context)

func _visual_context(fighter: BattleSimulation.FighterState) -> Dictionary:
	return {
		"position": _p(fighter.pos),
		"radius": fighter.radius * _scale_factor(),
		"scale_factor": _scale_factor(),
		"elapsed": simulation.elapsed,
		"shake_offset": _shake_offset,
	}

func _draw_underlay(fighter: BattleSimulation.FighterState, visual: BallVisual) -> void:
	if fighter.hp <= 0.0:
		return
	var context := _visual_context(fighter)
	var center: Vector2 = context.position
	var radius: float = context.radius
	Glow.halo(self, center + Vector2(0, radius * 0.42), radius * 1.7, Color(0, 0, 0, 0.72), Vector2(1.0, 0.70))
	Glow.halo(self, center, radius * 2.5, Color(fighter.accent, 0.17 + fighter.hit_flash * 0.14))
	visual.draw_underlay(self, fighter, context)

func _draw_ball(fighter: BattleSimulation.FighterState, visual: BallVisual) -> void:
	if fighter.hp <= 0.0:
		return
	var context := _visual_context(fighter)
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	visual.draw_ball(self, fighter, context)
	for effect in fighter.status_effects:
		effect.draw_overlay(self, fighter, context)
	if fighter.hit_flash > 0.0:
		draw_circle(position, radius, Color(1.0, 1.0, 1.0, fighter.hit_flash * 0.52))

func _draw_center_value(position: Vector2, text: String, radius: float, color: Color) -> void:
	var font_size := clampi(
		int(radius * BALL_HEALTH_FONT_SCALE),
		BALL_HEALTH_FONT_MIN_SIZE,
		BALL_HEALTH_FONT_MAX_SIZE
	)
	var baseline := position + Vector2(-radius, font_size * 0.34)
	var outline_color := Color(0.005, 0.008, 0.012, BALL_HEALTH_OUTLINE_ALPHA)
	var text_color := Color(color.r, color.g, color.b, color.a * BALL_HEALTH_TEXT_ALPHA)
	for outline_direction in [
		Vector2.LEFT,
		Vector2.RIGHT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(-1.0, -1.0).normalized(),
		Vector2(1.0, -1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(1.0, 1.0).normalized(),
	]:
		draw_string(
			_font,
			baseline + outline_direction * BALL_HEALTH_OUTLINE_WIDTH,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0,
			font_size,
			outline_color
		)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, text_color)

func _draw_impact_rings() -> void:
	for ring in simulation.impact_rings:
		var color: Color = ring["color"]
		var life := clampf(float(ring["ttl"]) / float(ring["duration"]), 0.0, 1.0)
		var age := 1.0 - life
		var center := _p(ring["pos"])
		var radius := maxf(0.1, float(ring["radius"]) * _scale_factor())
		color.a *= life * life
		Glow.halo(self, center, radius * 1.5, Color(color, color.a * 0.24))
		draw_arc(center, radius, 0, TAU, 64, Color(color, color.a * 0.12), 9.0 * life + 1.0, true)
		draw_arc(center, radius, 0, TAU, 64, Color(color.lerp(Color.WHITE, 0.42), color.a * 0.85), maxf(0.8, 2.6 * life), true)
		var flash := maxf(0.0, 1.0 - age * 4.5)
		Glow.halo(self, center, 28.0 * _scale_factor(), Color(color.lerp(Color.WHITE, 0.7), flash * 0.65))
		for index in range(8):
			var angle := TAU * float(index) / 8.0 + age * 0.3
			var direction := Vector2.from_angle(angle)
			var start := center + direction * radius * 0.80
			var finish := center + direction * radius * (1.10 + age * 0.25)
			draw_line(start, finish, Color(color, color.a * 0.48), maxf(0.7, life * 1.8), true)

func _draw_particles() -> void:
	_particle_presentation.draw(self, simulation.particles, _origin(), _scale_factor())

func _draw_floating_texts() -> void:
	for item in simulation.floating_texts:
		var color: Color = item["color"]
		color.a *= clampf(float(item["ttl"]) / minf(0.22, float(item["duration"])), 0.0, 1.0)
		var position := _p(item["pos"])
		var font_size := _floating_text_font_size(item)
		var text_width := maxf(100.0, float(font_size) * 4.5)
		draw_string_outline(_font, position + Vector2(-text_width * 0.5, 0.0), str(item["text"]), HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, 4, Color(0.015, 0.02, 0.035, color.a * 0.9))
		draw_string(
			_font,
			position + Vector2(-text_width * 0.5, 0.0),
			str(item["text"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			text_width,
			font_size,
			color
		)

func _floating_text_font_size(item: Dictionary) -> int:
	if String(item.get("kind", "generic")) == "damage":
		return maxi(1, damage_number_font_size)
	return DEFAULT_FLOATING_TEXT_FONT_SIZE

func team_marker_presentations() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if simulation == null or simulation.battle_setup.mode == BattleSetupScript.MODE_DUEL:
		return markers
	var scale_factor := _scale_factor()
	for fighter in simulation.active_fighters():
		markers.append(_team_marker_presentation(
			fighter.team_id,
			_p(fighter.pos),
			fighter.radius * scale_factor,
			true,
			fighter.fighter_uid
		))
	var render_context := BallRenderContext.new(
		_origin(),
		scale_factor,
		size,
		_shake_offset,
		simulation.elapsed,
		simulation.active_fighters(),
		simulation.count_entities
	)
	for entity: BallEntity in simulation.entities:
		var world_height := entity.team_marker_world_height()
		if (
			entity.removed
			or entity.is_captured()
			or entity.owner_side < 0
			or world_height <= 0.0
		):
			continue
		markers.append(_team_marker_presentation(
			entity.owner_side,
			entity.screen_position(render_context, entity.team_marker_world_position()),
			world_height * scale_factor,
			false,
			entity.get_instance_id()
		))
	return markers

func team_marker_color(team_id: int) -> Color:
	if simulation == null:
		return Color("b7c2c8")
	var team_index := -1
	for index in range(simulation.battle_setup.teams.size()):
		if int(simulation.battle_setup.teams[index].get("id", -1)) == team_id:
			team_index = index
			break
	if team_index < 0:
		return Color("b7c2c8")
	var configured_color: Color = simulation.battle_setup.teams[team_index].get(
		"color",
		Color.TRANSPARENT
	)
	if configured_color.a > 0.0:
		return configured_color
	if simulation.teams.size() == 2:
		return BattleSetupScript.RELAY_RED_TEAM_COLOR \
			if team_index == 0 \
			else BattleSetupScript.RELAY_BLUE_TEAM_COLOR
	return BattleSetupScript.competitive_team_color(team_index)

func _team_marker_presentation(
	team_id: int,
	subject_position: Vector2,
	visual_height: float,
	is_main_fighter: bool,
	subject_id: int
) -> Dictionary:
	var width := TEAM_MARKER_MAIN_WIDTH if is_main_fighter else TEAM_MARKER_ATTACHMENT_WIDTH
	var height := TEAM_MARKER_MAIN_HEIGHT if is_main_fighter else TEAM_MARKER_ATTACHMENT_HEIGHT
	var gap := TEAM_MARKER_MAIN_GAP if is_main_fighter else TEAM_MARKER_ATTACHMENT_GAP
	var bob_amplitude := TEAM_MARKER_MAIN_BOB if is_main_fighter else TEAM_MARKER_ATTACHMENT_BOB
	var bob_offset := float(team_id) * 0.83 + (0.0 if is_main_fighter else 0.38)
	var bob := sin(simulation.elapsed * TAU * TEAM_MARKER_BOB_HZ + bob_offset) * bob_amplitude
	return {
		"kind": "fighter" if is_main_fighter else "attachment",
		"subject_id": subject_id,
		"team_id": team_id,
		"color": team_marker_color(team_id),
		"tip": subject_position + Vector2(0.0, -visual_height - gap + bob),
		"width": width,
		"height": height,
	}

func _draw_team_markers() -> void:
	for marker in team_marker_presentations():
		var tip: Vector2 = marker["tip"]
		var width := float(marker["width"])
		var height := float(marker["height"])
		var color: Color = marker["color"]
		var glow_color := Color(color.r, color.g, color.b, 0.2)
		draw_colored_polygon(
			_team_marker_triangle_points(tip, width + 7.0, height + 5.0),
			glow_color
		)
		draw_colored_polygon(
			_team_marker_triangle_points(tip + Vector2(0.0, 2.0), width + 3.0, height + 2.0),
			Color(0.0, 0.0, 0.0, 0.72)
		)
		draw_colored_polygon(
			_team_marker_triangle_points(tip, width + 2.0, height + 2.0),
			Color(0.02, 0.025, 0.03, 0.98)
		)
		var fill_points := _team_marker_triangle_points(
			tip - Vector2(0.0, 1.2),
			maxf(3.0, width - 2.0),
			maxf(3.0, height - 2.6)
		)
		var fill_color := color.lerp(Color.WHITE, 0.12)
		fill_color.a = 1.0
		draw_colored_polygon(fill_points, fill_color)
		draw_line(
			fill_points[0],
			fill_points[1],
			Color(1.0, 1.0, 1.0, 0.64),
			1.0,
			true
		)

static func _team_marker_triangle_points(
	tip: Vector2,
	width: float,
	height: float
) -> PackedVector2Array:
	return PackedVector2Array([
		tip + Vector2(-width * 0.5, -height),
		tip + Vector2(width * 0.5, -height),
		tip,
	])

func _draw_arena_hud() -> void:
	_sync_hud_feedback()
	_hud_presentation.begin_frame()
	var hud_bounds := {"by_fighter": {}, "by_team": {}}
	if simulation.battle_setup.mode == BattleSetupScript.MODE_RELAY:
		_draw_relay_hud(hud_bounds)
	elif simulation.teams.size() == 2 and simulation.battle_setup.mode == BattleSetupScript.MODE_DUEL:
		var left_bounds := health_hud_bounds(0)
		var right_bounds := health_hud_bounds(1)
		var left_health := "%d / %d" % [int(ceil(simulation.fighter_for_side(simulation.teams[0].team_id).hp)), int(simulation.fighter_for_side(simulation.teams[0].team_id).max_hp)]
		var right_health := "%d / %d" % [int(ceil(simulation.fighter_for_side(simulation.teams[1].team_id).hp)), int(simulation.fighter_for_side(simulation.teams[1].team_id).max_hp)]
		_draw_health_hud_panel(left_bounds, simulation.fighter_for_side(simulation.teams[0].team_id).display_name, left_health, simulation.fighter_for_side(simulation.teams[0].team_id).hp / simulation.fighter_for_side(simulation.teams[0].team_id).max_hp, simulation.fighter_for_side(simulation.teams[0].team_id).accent, false, _hud_feedback(simulation.fighter_for_side(simulation.teams[0].team_id)))
		_draw_health_hud_panel(right_bounds, simulation.fighter_for_side(simulation.teams[1].team_id).display_name, right_health, simulation.fighter_for_side(simulation.teams[1].team_id).hp / simulation.fighter_for_side(simulation.teams[1].team_id).max_hp, simulation.fighter_for_side(simulation.teams[1].team_id).accent, true, _hud_feedback(simulation.fighter_for_side(simulation.teams[1].team_id)))
		hud_bounds["by_fighter"][simulation.fighter_for_side(simulation.teams[0].team_id).fighter_uid] = left_bounds
		hud_bounds["by_fighter"][simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid] = right_bounds
		hud_bounds["by_team"][simulation.teams[0].team_id] = left_bounds
		hud_bounds["by_team"][simulation.teams[1].team_id] = right_bounds
	else:
		_draw_compact_multi_hud(hud_bounds)
	_draw_entity_hud(hud_bounds)
	_hud_glass_layer.update_bars(hud_bounds["by_fighter"].values())
	if simulation.battle_setup.mode == BattleSetupScript.MODE_DUEL:
		_draw_match_timer(Rect2(Vector2(size.x * 0.5 - 48.0, 20.0), RELAY_TIMER_SIZE))

func _sync_hud_feedback() -> void:
	for fighter in simulation.fighter_history:
		_hud_presentation.observe(fighter.fighter_uid, fighter.hp, fighter.max_hp, simulation.elapsed + _result_reveal_elapsed)

func _hud_feedback(fighter) -> Dictionary:
	return _hud_presentation.feedback(fighter.fighter_uid, simulation.elapsed + _result_reveal_elapsed)

func _draw_relay_hud(hud_bounds: Dictionary) -> void:
	_draw_match_timer(relay_timer_bounds())
	for team_index in range(mini(2, simulation.teams.size())):
		var team = simulation.teams[team_index]
		var bounds := health_hud_bounds(team_index)
		var fighter = relay_current_hud_fighter(team_index)
		if fighter != null:
			var health_text := "%d / %d" % [int(ceil(maxf(0.0, fighter.hp))), int(ceil(fighter.max_hp))]
			_draw_health_hud_panel(
				bounds,
				fighter.display_name,
				health_text,
				fighter.hp / fighter.max_hp,
				team_marker_color(team.team_id),
				team_index == 1,
				_hud_feedback(fighter)
			)
		hud_bounds["by_fighter"][fighter.fighter_uid] = bounds
		hud_bounds["by_team"][team.team_id] = bounds
		_draw_relay_roster(team_index)

func relay_current_hud_fighter(team_index: int):
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return null
	var team = simulation.teams[team_index]
	return team.active_fighters[0] if not team.active_fighters.is_empty() else team.last_fighter

func relay_timer_bounds() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - RELAY_TIMER_SIZE.x * 0.5, 24.0), RELAY_TIMER_SIZE)

func multi_timer_bounds() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - MULTI_TIMER_SIZE.x * 0.5, 8.0), MULTI_TIMER_SIZE)

func _draw_match_timer(bounds: Rect2) -> void:
	var remaining := maxi(0, int(ceil(simulation.max_battle_time - simulation.elapsed)))
	var urgent := remaining <= 10 and not simulation.finished
	var text_color := Color("ed9189") if urgent else Color("e4e8ec")
	var font_size := 22 if bounds.size.y >= 40 else 18
	var time_text := "%02d:%02d" % [floori(float(remaining) / 60.0), remaining % 60]
	draw_string(_font, Vector2(bounds.position.x, bounds.position.y + bounds.size.y * 0.66), time_text, HORIZONTAL_ALIGNMENT_CENTER, bounds.size.x, font_size, text_color)

func _relay_roster_area(team_index: int) -> Rect2:
	var available_width := (
		size.x
		- RELAY_ROSTER_SIDE_MARGIN * 2.0
		- RELAY_TIMER_SIZE.x
		- RELAY_ROSTER_CENTER_GAP
	)
	var side_width := available_width * 0.5
	var x := RELAY_ROSTER_SIDE_MARGIN if team_index == 0 else size.x - RELAY_ROSTER_SIDE_MARGIN - side_width
	return Rect2(Vector2(x, RELAY_ROSTER_AREA_TOP), Vector2(side_width, RELAY_ROSTER_AREA_HEIGHT))

func _relay_roster_slot_pitch(team_index: int) -> float:
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return 0.0
	var roster_count: int = simulation.teams[team_index].roster.size()
	var columns := mini(RELAY_ROSTER_MAX_COLUMNS, roster_count)
	return minf(
		RELAY_ROSTER_MAX_PITCH,
		_relay_roster_area(team_index).size.x / float(maxi(1, columns))
	)

func relay_roster_model_radius(team_index: int, roster_index: int) -> float:
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return 0.0
	if roster_index < 0 or roster_index >= simulation.teams[team_index].roster.size():
		return 0.0
	var slot_pitch := _relay_roster_slot_pitch(team_index)
	return clampf(
		slot_pitch * 0.36 * RELAY_ROSTER_MODEL_SCALE,
		6.5 * RELAY_ROSTER_MODEL_SCALE,
		11.5 * RELAY_ROSTER_MODEL_SCALE
	)

func relay_roster_slot_display_name(team_index: int, roster_index: int) -> String:
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return ""
	var team = simulation.teams[team_index]
	if roster_index < 0 or roster_index >= team.roster.size():
		return ""
	return BallRegistry.get_module(team.roster[roster_index]).display_name

func relay_roster_slot_bounds(team_index: int, roster_index: int) -> Rect2:
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return Rect2()
	var team = simulation.teams[team_index]
	var roster_count: int = team.roster.size()
	if roster_index < 0 or roster_index >= roster_count:
		return Rect2()
	var columns := mini(RELAY_ROSTER_MAX_COLUMNS, roster_count)
	var area := _relay_roster_area(team_index)
	var slot_pitch := _relay_roster_slot_pitch(team_index)
	var model_radius := relay_roster_model_radius(team_index, roster_index)
	var row := floori(float(roster_index) / float(columns))
	var column := roster_index % columns
	var center_x := area.position.x + slot_pitch * (float(column) + 0.5)
	if team_index == 1:
		center_x = area.end.x - slot_pitch * (float(column) + 0.5)
	var center := Vector2(
		center_x,
		area.position.y + 13.0 + float(row) * 25.0
	)
	return Rect2(
		center - Vector2(model_radius + 3.0, model_radius + 3.0),
		Vector2(model_radius * 2.0 + 6.0, model_radius * 2.0 + 15.0)
	)

func relay_roster_slot_name_bounds(team_index: int, roster_index: int) -> Rect2:
	var slot_bounds := relay_roster_slot_bounds(team_index, roster_index)
	if slot_bounds.size.x <= 0.0:
		return Rect2()
	var model_radius := relay_roster_model_radius(team_index, roster_index)
	var center := slot_bounds.position + Vector2(slot_bounds.size.x * 0.5, model_radius + 3.0)
	var label_width := _relay_roster_slot_pitch(team_index)
	return Rect2(
		Vector2(center.x - label_width * 0.5, center.y + model_radius + 2.0),
		Vector2(label_width, 10.0)
	)

func relay_roster_slot_state(team_index: int, roster_index: int) -> String:
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return "invalid"
	var team = simulation.teams[team_index]
	for fighter in team.active_fighters:
		if fighter.roster_index == roster_index:
			return "active"
	if roster_index < team.next_roster_index:
		return "defeated"
	if roster_index == team.next_roster_index:
		return "next"
	return "queued"

func _draw_relay_roster(team_index: int) -> void:
	var team = simulation.teams[team_index]
	for roster_index in range(team.roster.size()):
		var bounds := relay_roster_slot_bounds(team_index, roster_index)
		var model_radius := (bounds.size.x - 6.0) * 0.5
		var center := bounds.position + Vector2(bounds.size.x * 0.5, model_radius + 3.0)
		var preview_key := _roster_preview_key(team.team_id, roster_index)
		var module: BallModule = BallRegistry.get_module(team.roster[roster_index])
		var visual: BallVisual = _roster_preview_visuals[preview_key]
		var preview: HudRosterFighter = _roster_preview_fighters[preview_key]
		preview.rotation = simulation.elapsed * 0.42 + float(roster_index) * 0.19
		var state := relay_roster_slot_state(team_index, roster_index)
		var outline_color := Color(module.accent.r, module.accent.g, module.accent.b, 0.48)
		var outline_width := 1.5
		if state == "active":
			var pulse := 0.72 + sin(simulation.elapsed * 5.0) * 0.18
			outline_color = Color(module.accent.r, module.accent.g, module.accent.b, pulse)
			outline_width = 3.0
		elif state == "next":
			outline_color = Color("ffe66d")
			outline_width = 2.2
		draw_circle(center, model_radius + 3.0, Color(0.01, 0.014, 0.019, 0.96))
		draw_circle(center, model_radius + 2.0, outline_color, false, outline_width)
		visual.draw_ball(self, preview, {
			"position": center,
			"radius": model_radius,
			"scale_factor": 1.0,
			"elapsed": simulation.elapsed,
			"shake_offset": Vector2.ZERO,
		})
		if state == "queued":
			draw_circle(center, model_radius, Color(0.0, 0.0, 0.0, 0.18))
		elif state == "defeated":
			draw_circle(center, model_radius + 1.0, Color(0.0, 0.0, 0.0, 0.62))
			var cross_extent := model_radius * 0.78
			draw_line(center + Vector2(-cross_extent, -cross_extent), center + Vector2(cross_extent, cross_extent), Color("ff5c62"), 3.2, true)
			draw_line(center + Vector2(cross_extent, -cross_extent), center + Vector2(-cross_extent, cross_extent), Color("ff5c62"), 3.2, true)
		var order_color := Color("ffffff") if state == "active" else Color("aeb8be")
		if state == "defeated":
			order_color = Color("ff777c")
		elif state == "next":
			order_color = Color("ffe66d")
		var badge_radius := clampf(model_radius * 0.34, 3.8, 5.0)
		var badge_center := center + Vector2(-model_radius * 0.78, -model_radius * 0.78)
		draw_circle(badge_center, badge_radius + 1.2, Color(0.0, 0.0, 0.0, 0.86))
		draw_circle(badge_center, badge_radius, Color(order_color.r, order_color.g, order_color.b, 0.9))
		_draw_hud_text(
			str(roster_index + 1),
			Vector2(badge_center.x - badge_radius, badge_center.y + 2.5),
			badge_radius * 2.0,
			7,
			Color("11161a"),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		var name_bounds := relay_roster_slot_name_bounds(team_index, roster_index)
		var name_color := order_color
		name_color.a = 0.72 if state == "queued" else 1.0
		_draw_compact_hud_text(
			relay_roster_slot_display_name(team_index, roster_index),
			name_bounds.position + Vector2(0.0, 8.0),
			name_bounds.size.x,
			RELAY_ROSTER_NAME_FONT_SIZE,
			name_color,
			HORIZONTAL_ALIGNMENT_CENTER
		)

func _draw_relay_handoff_notice() -> void:
	if simulation.battle_setup.mode != BattleSetupScript.MODE_RELAY:
		return
	var notices := _relay_notice_entries()
	if notices.is_empty():
		return
	var presentation := relay_defeat_notice_presentation()
	var alpha := float(presentation["alpha"])
	if alpha <= 0.001:
		return
	var arena_bounds := arena_screen_rect()
	var font_size := int(presentation["font_size"])
	var text_width := size.x - 80.0
	var base_y := arena_bounds.position.y + arena_bounds.size.y * 0.36 - float(presentation["rise"])
	var line_height := float(font_size) + 12.0
	base_y -= float(notices.size() - 1) * line_height * 0.5
	for notice_index in range(notices.size()):
		var notice: Dictionary = notices[notice_index]
		var team_id := int(notice.get("team_id", 0))
		var team_color := BattleSetupScript.RELAY_RED_TEAM_COLOR if team_id == 0 else BattleSetupScript.RELAY_BLUE_TEAM_COLOR
		var notice_text := relay_defeat_notice_text(notice)
		var text_position := Vector2(40.0, base_y + float(notice_index) * line_height)
		_draw_hud_text(notice_text, text_position + Vector2(2.0, 3.0), text_width, font_size, Color(0.0, 0.0, 0.0, alpha * 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		_draw_hud_text(notice_text, text_position, text_width, font_size, Color(team_color.r, team_color.g, team_color.b, alpha), HORIZONTAL_ALIGNMENT_CENTER)

func relay_defeat_notice_presentation() -> Dictionary:
	var duration := maxf(BattleSimulation.FIXED_STEP, relay_handoff_pause_seconds)
	var remaining := simulation.replacement_pause_remaining()
	if simulation.finished:
		duration = _effective_result_reveal_delay()
		remaining = maxf(0.0, duration - _result_reveal_elapsed)
	else:
		duration = maxf(duration, simulation.death_effect_duration)
	var progress := clampf(1.0 - remaining / maxf(BattleSimulation.FIXED_STEP, duration), 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.25, 1.0, progress)
	var pop := sin(clampf(progress / 0.18, 0.0, 1.0) * PI) * 0.12 if progress < 0.18 else 0.0
	return {
		"progress": progress,
		"alpha": alpha,
		"rise": progress * 30.0,
		"font_size": maxi(1, int(round(float(relay_defeat_text_font_size) * (1.0 + pop)))),
	}

func relay_defeat_notice_text(notice: Dictionary) -> String:
	var defeated_name := String(notice.get("defeated_display_name", notice.get("display_name", "")))
	var team_id := int(notice.get("team_id", 0))
	var team = simulation.team_for_id(team_id) if simulation != null else null
	var team_name: String = team.display_name \
		if team != null else BattleSetupScript.default_team_name(BattleSetupScript.MODE_RELAY, team_id)
	return "%s·%s落败" % [team_name, defeated_name]

func _relay_notice_entries() -> Array[Dictionary]:
	var pending := simulation.pending_replacement_notices()
	if not pending.is_empty():
		return pending
	var notices: Array[Dictionary] = []
	if not simulation.finished or result_reveal_ready():
		return notices
	var latest_elapsed := -INF
	for event in simulation.team_events:
		if String(event.get("kind", "")) == "fighter_defeated":
			latest_elapsed = maxf(latest_elapsed, float(event.get("elapsed", -INF)))
	for event in simulation.team_events:
		if String(event.get("kind", "")) != "fighter_defeated" \
				or not is_equal_approx(float(event.get("elapsed", -INF)), latest_elapsed):
			continue
		var notice: Dictionary = event.duplicate(true)
		notice["defeated_ball_id"] = String(event.get("ball_id", ""))
		notice["defeated_display_name"] = String(event.get("display_name", ""))
		notices.append(notice)
	return notices

func _team_hud_bounds(team_index: int, team_count: int) -> Rect2:
	if team_index < 0 or team_index >= team_count:
		return Rect2()
	return compact_hud_health_bar_bounds(team_index, 0)

func compact_hud_fighters_for_team(team_index: int) -> Array:
	var result := []
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return result
	var team = simulation.teams[team_index]
	for fighter in simulation.fighter_history:
		if fighter.team_id == team.team_id:
			result.append(fighter)
	result.sort_custom(func(first, second) -> bool:
		if first.roster_index != second.roster_index:
			return first.roster_index < second.roster_index
		return first.fighter_uid < second.fighter_uid
	)
	return result

func compact_hud_row_bounds(team_index: int, fighter_index: int) -> Rect2:
	if simulation == null or team_index < 0 or team_index >= simulation.teams.size():
		return Rect2()
	if BattleSetupScript.allows_team_editing(simulation.battle_setup.mode):
		var columns := 2
		var column := team_index % columns
		var ffa_row := floori(float(team_index) / float(columns))
		var column_width := (
			size.x
			- MULTI_HUD_SIDE_MARGIN * 2.0
			- MULTI_HUD_COLUMN_GAP
		) / 2.0
		return Rect2(
			Vector2(
				MULTI_HUD_SIDE_MARGIN + float(column) * (column_width + MULTI_HUD_COLUMN_GAP),
				MULTI_HUD_CONTENT_TOP + float(ffa_row) * MULTI_HUD_ROW_PITCH
			),
			Vector2(column_width, MULTI_HUD_ROW_HEIGHT)
		)
	var team_width := (
		size.x
		- MULTI_HUD_SIDE_MARGIN * 2.0
		- MULTI_HUD_COLUMN_GAP
	) / 2.0
	var team_x := MULTI_HUD_SIDE_MARGIN + float(team_index) * (team_width + MULTI_HUD_COLUMN_GAP)
	var fighter_count := compact_hud_fighters_for_team(team_index).size()
	var subcolumn_count := 2 if fighter_count > MULTI_HUD_MAX_ROWS_PER_COLUMN else 1
	var subcolumn_gap := 5.0 if subcolumn_count > 1 else 0.0
	var subcolumn_width := (
		team_width - subcolumn_gap * float(subcolumn_count - 1)
	) / float(subcolumn_count)
	var subcolumn := floori(float(fighter_index) / float(MULTI_HUD_MAX_ROWS_PER_COLUMN))
	var brawl_row := fighter_index % MULTI_HUD_MAX_ROWS_PER_COLUMN
	return Rect2(
		Vector2(
			team_x + float(subcolumn) * (subcolumn_width + subcolumn_gap),
			MULTI_HUD_CONTENT_TOP + MULTI_HUD_TEAM_HEADER_HEIGHT + float(brawl_row) * MULTI_HUD_ROW_PITCH
		),
		Vector2(subcolumn_width, MULTI_HUD_ROW_HEIGHT)
	)

func compact_hud_health_bar_bounds(team_index: int, fighter_index: int) -> Rect2:
	var row_bounds := compact_hud_row_bounds(team_index, fighter_index)
	if row_bounds.size.x <= 0.0:
		return Rect2()
	var name_width := clampf(row_bounds.size.x * 0.3, 42.0, 78.0)
	var value_width := clampf(row_bounds.size.x * 0.25, 44.0, 64.0)
	var bar_x := row_bounds.position.x + name_width + 4.0
	var bar_width := maxf(12.0, row_bounds.size.x - name_width - value_width - 8.0)
	return Rect2(
		Vector2(bar_x, row_bounds.position.y + (row_bounds.size.y - MULTI_HUD_BAR_HEIGHT) * 0.5),
		Vector2(bar_width, MULTI_HUD_BAR_HEIGHT)
	)

func _draw_compact_multi_hud(hud_bounds: Dictionary) -> void:
	_draw_compact_match_timer(multi_timer_bounds())
	if simulation.battle_setup.mode == BattleSetupScript.MODE_TEAM_BRAWL:
		for team_index in range(simulation.teams.size()):
			var team = simulation.teams[team_index]
			var sample_row := compact_hud_row_bounds(team_index, 0)
			var team_fighters := compact_hud_fighters_for_team(team_index)
			var alive_count := 0
			for fighter in team_fighters:
				if fighter.hp > 0.0:
					alive_count += 1
			var team_label := "%s · %d/%d" % [team.display_name, alive_count, team_fighters.size()]
			_draw_hud_text(
				team_label,
				Vector2(sample_row.position.x, MULTI_HUD_CONTENT_TOP + 13.0),
				sample_row.size.x * (2.0 if team_fighters.size() > MULTI_HUD_MAX_ROWS_PER_COLUMN else 1.0),
				12,
				team_marker_color(team.team_id).lerp(Color.WHITE, 0.2),
				HORIZONTAL_ALIGNMENT_CENTER
			)
	for team_index in range(simulation.teams.size()):
		var team = simulation.teams[team_index]
		var fighters := compact_hud_fighters_for_team(team_index)
		for fighter_index in range(fighters.size()):
			var fighter = fighters[fighter_index]
			var row_bounds := compact_hud_row_bounds(team_index, fighter_index)
			var bar_bounds := compact_hud_health_bar_bounds(team_index, fighter_index)
			_draw_compact_fighter_hud_row(row_bounds, bar_bounds, team, fighter)
			hud_bounds["by_fighter"][fighter.fighter_uid] = bar_bounds
			if not hud_bounds["by_team"].has(team.team_id):
				hud_bounds["by_team"][team.team_id] = bar_bounds

func _draw_compact_fighter_hud_row(row_bounds: Rect2, bar_bounds: Rect2, team, fighter) -> void:
	var color := team_marker_color(team.team_id)
	var alive: bool = fighter.hp > 0.0
	var ratio: float = fighter.hp / fighter.max_hp if alive else 0.0
	var feedback := _hud_feedback(fighter)
	draw_line(Vector2(row_bounds.position.x, row_bounds.end.y), row_bounds.end, Color(1, 1, 1, 0.07), 1.0)
	var name_width := bar_bounds.position.x - row_bounds.position.x - 4.0
	var value_x := bar_bounds.end.x + 4.0
	var value_width := row_bounds.end.x - value_x
	var display_name: String = fighter.display_name
	if BattleSetupScript.is_free_for_all_mode(simulation.battle_setup.mode):
		display_name = "%s·%s" % [team.display_name, fighter.display_name]
	var name_color := Color("dde2e6")
	name_color.a = 1.0 if alive else 0.52
	var value_color := Color("ff978a") if ratio <= 0.25 else Color.WHITE
	value_color.a = 1.0 if alive else 0.48
	_draw_compact_hud_text(display_name, row_bounds.position + Vector2(0.0, 14.0), name_width - 8.0, MULTI_HUD_NAME_FONT_SIZE, name_color, HORIZONTAL_ALIGNMENT_LEFT)
	_hud_presentation.health_bar(self, bar_bounds, ratio, color if alive else Color("57616c"), false, feedback, simulation.elapsed)
	var health_text := "%d/%d" % [int(ceil(maxf(0.0, fighter.hp))), int(ceil(fighter.max_hp))]
	_draw_hud_text(
		health_text,
		Vector2(value_x, row_bounds.position.y + 14.0),
		value_width - 3.0,
		_hud_value_font_size(health_text, value_width - 3.0, MULTI_HUD_VALUE_FONT_SIZE),
		value_color,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

func _draw_compact_match_timer(bounds: Rect2) -> void:
	_draw_match_timer(bounds)

func _draw_compact_hud_text(text: String, position: Vector2, width: float, font_size: int, color: Color, alignment: int) -> void:
	_draw_hud_text(_fit_hud_text(text, width, font_size), position, width, font_size, color, alignment)

func _hud_value_font_size(text: String, width: float, preferred: int) -> int:
	var fitted := preferred
	while fitted > 7 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 1
	return fitted

func _fit_hud_text(text: String, width: float, font_size: int) -> String:
	if width <= 0.0 or _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
		return text
	var shortened := text
	while shortened.length() > 1:
		shortened = shortened.left(shortened.length() - 1)
		var candidate := shortened + "…"
		if _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
			return candidate
	return "…"

func _draw_entity_hud(hud_bounds: Dictionary) -> void:
	var fighter_bounds: Dictionary = hud_bounds.get("by_fighter", {})
	var team_bounds: Dictionary = hud_bounds.get("by_team", {})
	for entity in simulation.entities:
		if entity.removed or entity.is_captured() or entity.owner_side < 0:
			continue
		if fighter_bounds.has(entity.owner_fighter_uid):
			entity.draw_hud(self, fighter_bounds[entity.owner_fighter_uid])
		elif team_bounds.has(entity.owner_side):
			entity.draw_hud(self, team_bounds[entity.owner_side])

func _draw_health_hud_panel(bounds: Rect2, display_name: String, health_text: String, ratio: float, color: Color, align_right: bool, feedback: Dictionary) -> void:
	var name_width := minf(92.0, bounds.size.x * 0.44)
	var value_width := bounds.size.x - name_width
	var label_baseline := bounds.position.y - 7.0
	var name_color := Color("dce1e5")
	name_color.a = 1.0
	var value_color := Color("ff978a") if ratio <= 0.25 else Color.WHITE
	var value_font_size := _hud_value_font_size(health_text, value_width, HEALTH_VALUE_FONT_SIZE)
	if align_right:
		_draw_hud_text(health_text, Vector2(bounds.position.x, label_baseline), value_width, value_font_size, value_color, HORIZONTAL_ALIGNMENT_LEFT)
		_draw_compact_hud_text(display_name, Vector2(bounds.position.x + value_width, label_baseline), name_width, HEALTH_NAME_FONT_SIZE, name_color, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_draw_compact_hud_text(display_name, Vector2(bounds.position.x, label_baseline), name_width, HEALTH_NAME_FONT_SIZE, name_color, HORIZONTAL_ALIGNMENT_LEFT)
		_draw_hud_text(health_text, Vector2(bounds.position.x + name_width, label_baseline), value_width, value_font_size, value_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_hud_presentation.health_bar(self, bounds, ratio, color, align_right, feedback, simulation.elapsed)

func _draw_hud_text(text: String, position: Vector2, width: float, font_size: int, color: Color, alignment: int) -> void:
	draw_string(_font, position, text, alignment, width, font_size, color)

func _draw_border() -> void:
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), Color("243848"), false, 1.0)

func _sync_result_panel() -> void:
	if not result_reveal_ready():
		return
	var top := _hud_panel_bottom + 16.0
	if result_panel == null:
		result_panel = ResultPanelScript.new()
		result_panel.name = "BattleResultPanel"
		result_panel.set_report_bounds(Rect2(Vector2(14.0, top), Vector2(size.x - 28.0, maxf(280.0, size.y - top - 14.0))))
		add_child(result_panel)
		var headline := "平局"
		var accent := Color("f2e7c4")
		if not simulation.is_draw():
			var winner := simulation.winner()
			var winner_team = simulation.team_for_id(simulation.winner_team_id)
			var winner_name: String = winner.display_name if simulation.battle_setup.mode == BattleSetupScript.MODE_DUEL else winner_team.display_name
			headline = winner_name + " 获胜"
			accent = winner.accent
		result_panel.configure(simulation.combat_report(), headline,
			"%s · %.1f 秒 · 种子 %d" % [simulation.finish_reason, simulation.elapsed, simulation.seed_value],
			accent, result_auto_scroll)
	result_panel.set_report_bounds(Rect2(Vector2(14.0, top), Vector2(size.x - 28.0, maxf(280.0, size.y - top - 14.0))))

func _draw_centered_text(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	draw_string(_font, Vector2(0.0, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
