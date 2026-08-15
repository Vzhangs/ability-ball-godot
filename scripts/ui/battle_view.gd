class_name BattleView
extends Control

signal state_changed(simulation: BattleSimulation)
signal battle_finished(simulation: BattleSimulation)
signal combat_event(kind: String, strength: float)

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")

var simulation: BattleSimulation
var simulation_speed := 1.0
var paused := false
var _accumulator := 0.0
var _finish_emitted := false
var _last_contact_hits := 0
var _last_checker_hits := 0
var _last_track_hits := 0
var _last_blood_bursts := 0

var _font: Font
var _shake_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_font = ThemeDB.fallback_font
	if simulation == null:
		start_battle(20260815)
	set_process(true)

func start_battle(seed_value: int) -> void:
	simulation = BattleSimulationScript.new(seed_value)
	_accumulator = 0.0
	_finish_emitted = false
	_last_contact_hits = 0
	_last_checker_hits = 0
	_last_track_hits = 0
	_last_blood_bursts = 0
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
		state_changed.emit(simulation)
	if simulation.camera_shake > 0.0:
		var strength := simulation.camera_shake
		_shake_offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	else:
		_shake_offset = _shake_offset.lerp(Vector2.ZERO, minf(1.0, delta * 18.0))
	if simulation.finished and not _finish_emitted:
		_finish_emitted = true
		battle_finished.emit(simulation)
	queue_redraw()

func _check_combat_events() -> void:
	var contact_hits: int = simulation.stats["contact_hits"]
	var checker_hits: int = simulation.stats["checker_hits"]
	var track_hits: int = simulation.stats["track_hits"]
	var blood_bursts: int = simulation.stats["blood_bursts"]
	if contact_hits > _last_contact_hits:
		combat_event.emit("impact", 0.8)
	if checker_hits > _last_checker_hits:
		combat_event.emit("judgment", 0.9)
	if track_hits > _last_track_hits:
		combat_event.emit("track", 0.45)
	if blood_bursts > _last_blood_bursts:
		combat_event.emit("blood", 0.7)
	_last_contact_hits = contact_hits
	_last_checker_hits = checker_hits
	_last_track_hits = track_hits
	_last_blood_bursts = blood_bursts

func _draw() -> void:
	if simulation == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("050607"))
	draw_set_transform(_shake_offset, 0.0, Vector2.ONE)
	_draw_checkerboard()
	_draw_tracks()
	_draw_tethers_and_anchors()
	_draw_fighter_trails()
	_draw_carriage()
	_draw_impact_rings()
	_draw_fighters()
	_draw_particles()
	_draw_floating_texts()
	_draw_corner_phase()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_border()
	if simulation.finished:
		_draw_result_card()

func _scale_factor() -> float:
	return minf(size.x / BattleSimulation.ARENA_SIZE.x, size.y / BattleSimulation.ARENA_SIZE.y)

func _origin() -> Vector2:
	var scale_factor := _scale_factor()
	return (size - BattleSimulation.ARENA_SIZE * scale_factor) * 0.5

func _p(value: Vector2) -> Vector2:
	return _origin() + value * _scale_factor()

func _draw_checkerboard() -> void:
	if simulation.checker_visible <= 0.0:
		return
	var alpha := clampf(simulation.checker_visible / 0.45, 0.0, 1.0)
	for cell in simulation.checker_cells:
		var rect: Rect2 = cell["rect"]
		var screen_rect := Rect2(_p(rect.position), rect.size * _scale_factor())
		var active: bool = cell["active"]
		var color := Color(0.72, 0.72, 0.72, 0.52 * alpha) if active else Color(0.22, 0.23, 0.24, 0.28 * alpha)
		draw_rect(screen_rect, color)
		draw_rect(screen_rect, Color(0.86, 0.76, 0.12, 0.38 * alpha), false, 1.4)
		var value := str(cell["value"])
		draw_string(
			_font,
			screen_rect.position + Vector2(0.0, screen_rect.size.y * 0.63),
			value,
			HORIZONTAL_ALIGNMENT_CENTER,
			screen_rect.size.x,
			26,
			Color(0.91, 0.94, 0.46, 0.9 * alpha)
		)

func _draw_tracks() -> void:
	var scale_factor := _scale_factor()
	for track in simulation.track_structures:
		var age: float = track["age"]
		var lifetime: float = track["lifetime"]
		var fade := minf(1.0, age / 0.5) * minf(1.0, (lifetime - age) / 0.75)
		var arms: int = track["arms"]
		for arm in range(arms):
			var angle: float = float(track["angle"]) + TAU * float(arm) / float(arms)
			draw_set_transform(_p(simulation.six_king.pos) + _shake_offset, angle, Vector2.ONE * scale_factor)
			_draw_track_arm(float(track["length"]), float(track["width"]), fade)
	draw_set_transform(_shake_offset, 0.0, Vector2.ONE)

func _draw_track_arm(length: float, width: float, alpha: float) -> void:
	var sleeper_color := Color(0.32, 0.24, 0.18, 0.92 * alpha)
	var sleeper_light := Color(0.52, 0.39, 0.27, 0.92 * alpha)
	var rail_color := Color(0.64, 0.66, 0.64, 0.92 * alpha)
	draw_line(Vector2.ZERO, Vector2(length, 0.0), Color(0.12, 0.10, 0.08, 0.7 * alpha), width + 7.0, true)
	draw_line(Vector2(0.0, -width * 0.34), Vector2(length, -width * 0.34), rail_color, 3.0, true)
	draw_line(Vector2(0.0, width * 0.34), Vector2(length, width * 0.34), rail_color, 3.0, true)
	var distance := 8.0
	while distance < length:
		draw_rect(Rect2(Vector2(distance - 5.5, -width * 0.55), Vector2(11.0, width * 1.1)), sleeper_color)
		draw_rect(Rect2(Vector2(distance - 3.6, -width * 0.46), Vector2(7.2, width * 0.92)), sleeper_light, false, 1.2)
		distance += 15.0

func _draw_tethers_and_anchors() -> void:
	var king_position := _p(simulation.six_king.pos)
	for anchor in simulation.anchors:
		var anchor_position := _p(anchor["pos"])
		var points := _curved_line(king_position, anchor_position, int(anchor["index"]))
		draw_polyline(points, Color(0.68, 0.87, 1.0, 0.78), 2.25, true)
		draw_polyline(points, Color(0.90, 0.97, 1.0, 0.35), 0.8, true)
		_draw_anchor(anchor)

func _curved_line(start: Vector2, finish: Vector2, index: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta := finish - start
	var normal := Vector2(-delta.y, delta.x).normalized()
	var bend := sin(float(index) * 1.73) * minf(32.0, delta.length() * 0.08)
	for step in range(13):
		var t := float(step) / 12.0
		var point := start.lerp(finish, t) + normal * sin(t * PI) * bend
		points.append(point)
	return points

func _draw_anchor(anchor: Dictionary) -> void:
	var position := _p(anchor["pos"])
	var inward: Vector2 = anchor["inward"]
	var tangent := Vector2(-inward.y, inward.x)
	var scale_factor := _scale_factor()
	var tip := position + inward * 25.0 * scale_factor
	var base_center := position - inward * 7.0 * scale_factor
	var polygon := PackedVector2Array([
		tip,
		base_center + tangent * 11.0 * scale_factor,
		base_center - tangent * 11.0 * scale_factor,
	])
	draw_colored_polygon(polygon, Color("16ef44"))
	draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[0]]), Color("d8ffe1"), 1.3, true)
	var pulse: float = anchor["pulse"]
	if pulse > 0.0:
		draw_circle(position, (13.0 + pulse * 17.0) * scale_factor, Color(0.14, 1.0, 0.33, pulse * 0.25), false, 2.0)

func _draw_fighter_trails() -> void:
	_draw_trail(simulation.vampire.trail, Color("c30b2f"), 17.0)
	_draw_trail(simulation.six_king.trail, Color("86d7ff"), 12.0)

func _draw_trail(trail: Array[Vector2], color: Color, width: float) -> void:
	if trail.size() < 2:
		return
	for index in range(1, trail.size()):
		var progress := 1.0 - float(index) / float(trail.size())
		var segment_color := color
		segment_color.a = progress * 0.3
		draw_line(_p(trail[index - 1]), _p(trail[index]), segment_color, width * progress * _scale_factor(), true)

func _draw_carriage() -> void:
	var position := _p(simulation.carriage_position)
	var direction := (simulation.carriage_position - simulation.six_king.pos).angle() + PI * 0.5
	var scale_factor := _scale_factor()
	draw_set_transform(position + _shake_offset, direction, Vector2.ONE * scale_factor)
	draw_rect(Rect2(Vector2(-27.0, -38.0), Vector2(54.0, 76.0)), Color("292d31"))
	draw_rect(Rect2(Vector2(-22.0, -32.0), Vector2(44.0, 64.0)), Color("70777b"), false, 3.0)
	draw_rect(Rect2(Vector2(-17.0, -24.0), Vector2(34.0, 20.0)), Color("b8e4ed"))
	draw_rect(Rect2(Vector2(-19.0, 8.0), Vector2(38.0, 18.0)), Color("8d1523"))
	draw_circle(Vector2(-20.0, 29.0), 6.0, Color("17191b"))
	draw_circle(Vector2(20.0, 29.0), 6.0, Color("17191b"))
	draw_set_transform(_shake_offset, 0.0, Vector2.ONE)

func _draw_impact_rings() -> void:
	for ring in simulation.impact_rings:
		var color: Color = ring["color"]
		color.a = clampf(float(ring["ttl"]) / float(ring["duration"]), 0.0, 1.0) * 0.72
		draw_circle(_p(ring["pos"]), float(ring["radius"]) * _scale_factor(), color, false, 3.0)

func _draw_fighters() -> void:
	_draw_vampire()
	_draw_six_king()

func _draw_vampire() -> void:
	var fighter := simulation.vampire
	var position := _p(fighter.pos)
	var radius := fighter.radius * _scale_factor()
	for index in range(10):
		var angle := fighter.rotation + TAU * float(index) / 10.0
		var root := position + Vector2.from_angle(angle) * radius * 0.78
		var tip := position + Vector2.from_angle(angle) * radius * 1.42
		var tangent := Vector2.from_angle(angle + PI * 0.5) * radius * 0.16
		draw_colored_polygon(PackedVector2Array([root - tangent, tip, root + tangent]), Color("145b2d"))
	draw_circle(position, radius * 1.12, Color(0.08, 0.48, 0.22, 0.34))
	draw_circle(position, radius, Color("a90920"))
	draw_circle(position - Vector2(radius * 0.18, radius * 0.22), radius * 0.48, Color("cf102c"))
	if fighter.hit_flash > 0.0:
		draw_circle(position, radius, Color(1.0, 0.8, 0.8, fighter.hit_flash * 0.58))
	_draw_vampire_fangs(position, radius)
	_draw_center_value(position, str(int(ceil(fighter.hp))), radius, Color.WHITE)

func _draw_vampire_fangs(position: Vector2, radius: float) -> void:
	var fang_color := Color("fff5e8")
	var left := position + Vector2(-radius * 0.35, radius * 0.42)
	var right := position + Vector2(radius * 0.35, radius * 0.42)
	draw_colored_polygon(PackedVector2Array([left + Vector2(-4.0, -4.0), left + Vector2(4.0, -4.0), left + Vector2(0.0, 8.0)]), fang_color)
	draw_colored_polygon(PackedVector2Array([right + Vector2(-4.0, -4.0), right + Vector2(4.0, -4.0), right + Vector2(0.0, 8.0)]), fang_color)

func _draw_six_king() -> void:
	var fighter := simulation.six_king
	var position := _p(fighter.pos)
	var radius := fighter.radius * _scale_factor()
	var colors := [Color("3b73df"), Color("f7d93f"), Color("d63a35"), Color("3ba969"), Color("ef8f32"), Color("7f55c7")]
	for wedge in range(6):
		var points := PackedVector2Array([position])
		var start_angle := -PI * 0.5 + TAU * float(wedge) / 6.0 + fighter.rotation * 0.15
		for segment in range(6):
			var angle := start_angle + TAU / 6.0 * float(segment) / 5.0
			points.append(position + Vector2.from_angle(angle) * radius)
		draw_colored_polygon(points, colors[wedge])
	draw_circle(position, radius, Color("f9f2c8"), false, 2.2)
	if fighter.shield_flash > 0.0:
		draw_circle(position, radius * (1.14 + fighter.shield_flash * 0.12), Color(0.35, 0.78, 1.0, fighter.shield_flash * 0.72), false, 4.0)
	if simulation.gold_flash > 0.0:
		draw_circle(position, radius * (1.3 + simulation.gold_flash * 0.35), Color(1.0, 0.87, 0.24, simulation.gold_flash * 0.65), false, 5.0)
	_draw_center_value(position, str(int(ceil(fighter.hp))), radius, Color.WHITE)

func _draw_center_value(position: Vector2, text: String, radius: float, color: Color) -> void:
	var font_size := clampi(int(radius * 0.58), 13, 25)
	draw_string(
		_font,
		position + Vector2(-radius, font_size * 0.34),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		font_size,
		color
	)

func _draw_particles() -> void:
	for particle in simulation.particles:
		var color: Color = particle["color"]
		color.a *= clampf(float(particle["ttl"]) / float(particle["duration"]), 0.0, 1.0)
		draw_circle(_p(particle["pos"]), float(particle["size"]) * _scale_factor(), color)

func _draw_floating_texts() -> void:
	for item in simulation.floating_texts:
		var color: Color = item["color"]
		color.a *= clampf(float(item["ttl"]) / minf(0.25, float(item["duration"])), 0.0, 1.0)
		var position := _p(item["pos"])
		var font_size := int(22.0 * float(item["scale"]) * _scale_factor())
		draw_string(_font, position + Vector2(-44.0, 0.0), str(item["text"]), HORIZONTAL_ALIGNMENT_CENTER, 88.0, font_size, color)

func _draw_corner_phase() -> void:
	var text := "PHASE %d" % simulation.phase
	draw_string(_font, Vector2(14.0, 31.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(1.0, 0.89, 0.32, 0.78))
	draw_string(_font, Vector2(size.x - 122.0, 31.0), "%03d s" % int(simulation.elapsed), HORIZONTAL_ALIGNMENT_RIGHT, 108.0, 18, Color(0.75, 0.84, 0.9, 0.72))

func _draw_border() -> void:
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), Color("f4f4f4"), false, 4.0)
	if simulation.gold_flash > 0.0:
		draw_rect(Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0)), Color(1.0, 0.86, 0.22, simulation.gold_flash * 0.45), false, 5.0)

func _draw_result_card() -> void:
	draw_rect(Rect2(Vector2(72.0, size.y * 0.36), Vector2(size.x - 144.0, 168.0)), Color(0.01, 0.01, 0.015, 0.88))
	var winner_name := simulation.vampire.display_name if simulation.winner_id == "vampire" else simulation.six_king.display_name
	_draw_centered_text(winner_name + " 获胜", size.y * 0.36 + 65.0, 38, Color("ffe552"))
	_draw_centered_text(simulation.finish_reason + " · %.1f 秒" % simulation.elapsed, size.y * 0.36 + 112.0, 24, Color("e8e8e8"))

func _draw_centered_text(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	draw_string(_font, Vector2(0.0, baseline_y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color)
