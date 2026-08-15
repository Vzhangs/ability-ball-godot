class_name BattleSimulation
extends RefCounted

## Deterministic, renderer-independent combat model for the vertical video scene.

const ARENA_SIZE := Vector2(640.0, 640.0)
const MAX_BATTLE_TIME := 118.0
const FIXED_STEP := 1.0 / 60.0

const VAMPIRE_MAX_HP := 6675.0
const SIX_KING_MAX_HP := 194.0

class FighterState:
	var id := ""
	var display_name := ""
	var pos := Vector2.ZERO
	var velocity := Vector2.ZERO
	var radius := 28.0
	var hp := 100.0
	var max_hp := 100.0
	var rotation := 0.0
	var hit_flash := 0.0
	var shield_flash := 0.0
	var trail: Array[Vector2] = []

	func _init(
		fighter_id: String,
		fighter_name: String,
		spawn_position: Vector2,
		spawn_velocity: Vector2,
		spawn_radius: float,
		spawn_hp: float
	) -> void:
		id = fighter_id
		display_name = fighter_name
		pos = spawn_position
		velocity = spawn_velocity
		radius = spawn_radius
		hp = spawn_hp
		max_hp = spawn_hp

	func hp_ratio() -> float:
		return clampf(hp / max_hp, 0.0, 1.0)

	func append_trail() -> void:
		trail.push_front(pos)
		if trail.size() > 18:
			trail.pop_back()

var rng := RandomNumberGenerator.new()
var seed_value := 20260815
var elapsed := 0.0
var finished := false
var winner_id := ""
var finish_reason := ""
var phase := 1

var vampire: FighterState
var six_king: FighterState

var anchors: Array[Dictionary] = []
var track_structures: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var checker_cells: Array[Dictionary] = []
var impact_rings: Array[Dictionary] = []

var carriage_angle := 0.0
var carriage_position := Vector2.ZERO
var checker_visible := 0.0
var gold_flash := 0.0
var camera_shake := 0.0

var _anchor_timer := 0.6
var _track_timer := 2.5
var _checker_timer := 3.0
var _blood_burst_timer := 5.4
var _dash_timer := 2.6
var _contact_timer := 0.0
var _tether_damage_timer := 0.0
var _track_damage_timer := 0.0
var _carriage_damage_timer := 0.0
var _trail_timer := 0.0

var stats := {
	"damage_to_vampire": 0.0,
	"damage_to_six_king": 0.0,
	"vampire_healing": 0.0,
	"contact_hits": 0,
	"anchors_spawned": 0,
	"tracks_spawned": 0,
	"checker_hits": 0,
	"tether_hits": 0,
	"track_hits": 0,
	"blood_bursts": 0,
	"phase_changes": 0,
}

func _init(initial_seed: int = 20260815) -> void:
	reset(initial_seed)

func reset(new_seed: int = 20260815) -> void:
	seed_value = new_seed if new_seed != 0 else 20260815
	rng.seed = seed_value
	elapsed = 0.0
	finished = false
	winner_id = ""
	finish_reason = ""
	phase = 1

	vampire = FighterState.new(
		"vampire",
		"吸血鬼",
		Vector2(168.0, 310.0),
		Vector2(188.0, 126.0),
		31.0,
		VAMPIRE_MAX_HP
	)
	six_king = FighterState.new(
		"six_king",
		"六王球",
		Vector2(466.0, 326.0),
		Vector2(-151.0, -174.0),
		29.0,
		SIX_KING_MAX_HP
	)

	anchors.clear()
	track_structures.clear()
	floating_texts.clear()
	particles.clear()
	checker_cells.clear()
	impact_rings.clear()
	carriage_angle = 0.0
	carriage_position = six_king.pos
	checker_visible = 0.0
	gold_flash = 0.0
	camera_shake = 0.0

	_anchor_timer = 0.6
	_track_timer = 2.5
	_checker_timer = 3.0
	_blood_burst_timer = 5.4
	_dash_timer = 2.6
	_contact_timer = 0.0
	_tether_damage_timer = 0.0
	_track_damage_timer = 0.0
	_carriage_damage_timer = 0.0
	_trail_timer = 0.0

	stats = {
		"damage_to_vampire": 0.0,
		"damage_to_six_king": 0.0,
		"vampire_healing": 0.0,
		"contact_hits": 0,
		"anchors_spawned": 0,
		"tracks_spawned": 0,
		"checker_hits": 0,
		"tether_hits": 0,
		"track_hits": 0,
		"blood_bursts": 0,
		"phase_changes": 0,
	}

func step(delta: float = FIXED_STEP) -> void:
	delta = clampf(delta, 0.0, 0.05)
	_update_transient_visuals(delta)
	if finished:
		return

	elapsed += delta
	_update_phase()
	_update_cooldowns(delta)
	_update_fighter_motion(vampire, delta, 155.0, 470.0)
	_update_fighter_motion(six_king, delta, 138.0, 390.0)
	_resolve_fighter_collision()
	_update_vampire_abilities(delta)
	_update_six_king_abilities(delta)
	_update_tracks(delta)
	_update_carriage(delta)
	_update_trails(delta)
	_check_finish()

func _update_cooldowns(delta: float) -> void:
	_anchor_timer -= delta
	_track_timer -= delta
	_checker_timer -= delta
	_blood_burst_timer -= delta
	_dash_timer -= delta
	_contact_timer = maxf(0.0, _contact_timer - delta)
	_tether_damage_timer = maxf(0.0, _tether_damage_timer - delta)
	_track_damage_timer = maxf(0.0, _track_damage_timer - delta)
	_carriage_damage_timer = maxf(0.0, _carriage_damage_timer - delta)
	checker_visible = maxf(0.0, checker_visible - delta)
	gold_flash = maxf(0.0, gold_flash - delta * 1.5)
	camera_shake = maxf(0.0, camera_shake - delta * 18.0)
	vampire.hit_flash = maxf(0.0, vampire.hit_flash - delta * 4.0)
	six_king.hit_flash = maxf(0.0, six_king.hit_flash - delta * 4.0)
	six_king.shield_flash = maxf(0.0, six_king.shield_flash - delta * 3.0)

func _update_phase() -> void:
	var new_phase := 1
	if elapsed >= 37.0 or vampire.hp_ratio() <= 0.68:
		new_phase = 2
	if elapsed >= 74.0 or vampire.hp_ratio() <= 0.36:
		new_phase = 3
	if new_phase != phase:
		phase = new_phase
		stats["phase_changes"] += 1
		gold_flash = 1.0
		camera_shake = 8.0
		spawn_floating_text("第 %d 阶段" % phase, six_king.pos + Vector2(0.0, -58.0), Color("ffe75a"), 1.5, 1.2)
		spawn_ring(six_king.pos, Color("ffe75a"), 24.0, 170.0, 1.0)

func _update_fighter_motion(fighter: FighterState, delta: float, minimum_speed: float, maximum_speed: float) -> void:
	fighter.pos += fighter.velocity * delta
	fighter.rotation += fighter.velocity.length() * delta * 0.0024

	if fighter.pos.x - fighter.radius < 0.0:
		fighter.pos.x = fighter.radius
		fighter.velocity.x = absf(fighter.velocity.x)
		_on_wall_bounce(fighter)
	elif fighter.pos.x + fighter.radius > ARENA_SIZE.x:
		fighter.pos.x = ARENA_SIZE.x - fighter.radius
		fighter.velocity.x = -absf(fighter.velocity.x)
		_on_wall_bounce(fighter)
	if fighter.pos.y - fighter.radius < 0.0:
		fighter.pos.y = fighter.radius
		fighter.velocity.y = absf(fighter.velocity.y)
		_on_wall_bounce(fighter)
	elif fighter.pos.y + fighter.radius > ARENA_SIZE.y:
		fighter.pos.y = ARENA_SIZE.y - fighter.radius
		fighter.velocity.y = -absf(fighter.velocity.y)
		_on_wall_bounce(fighter)

	var speed := fighter.velocity.length()
	if speed < minimum_speed:
		fighter.velocity = fighter.velocity.normalized() * minimum_speed if speed > 0.1 else Vector2.RIGHT * minimum_speed
	elif speed > maximum_speed:
		fighter.velocity = fighter.velocity.normalized() * maximum_speed

func _on_wall_bounce(fighter: FighterState) -> void:
	fighter.velocity = fighter.velocity.rotated(rng.randf_range(-0.045, 0.045))
	spawn_particles(fighter.pos, Color("ffffff"), 3, 42.0)

func _resolve_fighter_collision() -> void:
	var delta_pos := six_king.pos - vampire.pos
	var minimum_distance := vampire.radius + six_king.radius
	var distance := delta_pos.length()
	if distance >= minimum_distance or distance <= 0.001:
		return

	var normal := delta_pos / distance
	var overlap := minimum_distance - distance
	vampire.pos -= normal * overlap * 0.5
	six_king.pos += normal * overlap * 0.5
	var relative_speed := (six_king.velocity - vampire.velocity).dot(normal)
	if relative_speed < 0.0:
		var impulse := -(1.82) * relative_speed * 0.5
		vampire.velocity -= normal * impulse
		six_king.velocity += normal * impulse

	if _contact_timer <= 0.0:
		_contact_timer = 0.42
		stats["contact_hits"] += 1
		_damage(six_king, 5.0, vampire.pos, "-5", Color("ff4d55"))
		_heal(vampire, 3.0, vampire.pos + Vector2(0.0, -34.0))
		_damage(vampire, 18.0 + phase * 3.0, six_king.pos, "-%d" % int(18.0 + phase * 3.0), Color("ffe16a"))
		camera_shake = maxf(camera_shake, 5.0)
		spawn_ring((vampire.pos + six_king.pos) * 0.5, Color("ffffff"), 8.0, 72.0, 0.28)
		spawn_particles((vampire.pos + six_king.pos) * 0.5, Color("fff3a6"), 9, 145.0)

func _update_vampire_abilities(_delta: float) -> void:
	if _dash_timer <= 0.0:
		_dash_timer = maxf(2.25, 4.1 - phase * 0.25)
		var direction := (six_king.pos - vampire.pos).normalized()
		vampire.velocity = direction.rotated(rng.randf_range(-0.16, 0.16)) * (410.0 + phase * 18.0)
		spawn_ring(vampire.pos, Color("d71933"), 18.0, 92.0, 0.35)
		spawn_particles(vampire.pos, Color("ff304e"), 14, 180.0)

	if _blood_burst_timer <= 0.0:
		_blood_burst_timer = maxf(4.4, 6.4 - phase * 0.45)
		stats["blood_bursts"] += 1
		spawn_ring(vampire.pos, Color("b90028"), vampire.radius, 138.0, 0.7)
		spawn_particles(vampire.pos, Color("d40f38"), 24, 225.0)
		if vampire.pos.distance_to(six_king.pos) <= 142.0:
			_damage(six_king, 2.0, six_king.pos, "-2", Color("ff4054"))
			_heal(vampire, 9.0, vampire.pos + Vector2(0.0, -42.0))

func _update_six_king_abilities(_delta: float) -> void:
	var desired_anchor_count := 8 + phase * 7
	if _anchor_timer <= 0.0 and anchors.size() < desired_anchor_count:
		_anchor_timer = maxf(0.7, 1.55 - phase * 0.22)
		_spawn_anchor()

	if _checker_timer <= 0.0:
		_checker_timer = maxf(3.5, 5.8 - phase * 0.55)
		_activate_checkerboard()

	if _track_timer <= 0.0:
		_track_timer = maxf(4.6, 8.2 - phase * 1.0)
		_spawn_track_structure()

	if anchors.is_empty():
		return
	if _tether_damage_timer <= 0.0:
		_tether_damage_timer = 0.20
		var crossings := 0
		for anchor in anchors:
			var distance := _distance_to_segment(vampire.pos, six_king.pos, anchor["pos"])
			if distance <= vampire.radius * 0.72:
				crossings += 1
		if crossings > 0:
			var tether_damage := minf(26.0, 2.4 + crossings * (1.6 + phase * 0.55))
			_damage(vampire, tether_damage, vampire.pos, "-%d" % int(ceil(tether_damage)), Color("7be8ff"), false)
			stats["tether_hits"] += 1
			spawn_particles(vampire.pos, Color("8defff"), mini(8, crossings + 2), 95.0)

func _spawn_anchor() -> void:
	var index := anchors.size()
	var side := index % 4
	var slot := index / 4
	var spread := 72.0 + float(slot % 7) * 82.0
	var position := Vector2.ZERO
	var inward := Vector2.ZERO
	match side:
		0:
			position = Vector2(clampf(spread, 22.0, 618.0), 7.0)
			inward = Vector2.DOWN
		1:
			position = Vector2(633.0, clampf(spread, 22.0, 618.0))
			inward = Vector2.LEFT
		2:
			position = Vector2(clampf(ARENA_SIZE.x - spread, 22.0, 618.0), 633.0)
			inward = Vector2.UP
		_:
			position = Vector2(7.0, clampf(ARENA_SIZE.y - spread, 22.0, 618.0))
			inward = Vector2.RIGHT
	anchors.append({"pos": position, "inward": inward, "pulse": 1.0, "index": index})
	stats["anchors_spawned"] += 1
	spawn_ring(position, Color("22ff4d"), 3.0, 38.0, 0.45)

func _activate_checkerboard() -> void:
	checker_visible = 1.35
	checker_cells.clear()
	var grid_count := 6
	var cell_size := ARENA_SIZE.x / float(grid_count)
	for y in range(grid_count):
		for x in range(grid_count):
			var active := ((x + y + phase + int(elapsed)) % 3 == 0) or rng.randf() < 0.14
			var value := rng.randi_range(1, 30)
			checker_cells.append({
				"rect": Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size),
				"active": active,
				"value": value,
			})
	var cell_x := clampi(int(vampire.pos.x / cell_size), 0, grid_count - 1)
	var cell_y := clampi(int(vampire.pos.y / cell_size), 0, grid_count - 1)
	var current: Dictionary = checker_cells[cell_y * grid_count + cell_x]
	if current["active"]:
		var damage := 24.0 + float(current["value"]) * 0.75 + phase * 7.0
		_damage(vampire, damage, vampire.pos, "-%d" % int(damage), Color("fff06a"))
		stats["checker_hits"] += 1
		gold_flash = 0.65

func _spawn_track_structure() -> void:
	var arms := 2 + phase
	var lifetime := 10.0 + phase * 2.0
	track_structures.append({
		"angle": rng.randf_range(0.0, TAU),
		"arms": arms,
		"length": 250.0 + phase * 45.0,
		"age": 0.0,
		"lifetime": lifetime,
		"angular_speed": rng.randf_range(0.18, 0.34) * (-1.0 if rng.randf() < 0.5 else 1.0),
		"width": 19.0 + phase * 2.0,
	})
	stats["tracks_spawned"] += 1
	spawn_ring(six_king.pos, Color("c9a978"), 26.0, 110.0, 0.55)

func _update_tracks(delta: float) -> void:
	var remove_indices: Array[int] = []
	var touching_track := false
	for index in range(track_structures.size()):
		var track: Dictionary = track_structures[index]
		track["age"] = float(track["age"]) + delta
		track["angle"] = float(track["angle"]) + float(track["angular_speed"]) * delta
		track_structures[index] = track
		if float(track["age"]) >= float(track["lifetime"]):
			remove_indices.push_front(index)
			continue
		var arms: int = track["arms"]
		for arm in range(arms):
			var angle: float = float(track["angle"]) + TAU * float(arm) / float(arms)
			var endpoint := six_king.pos + Vector2.from_angle(angle) * float(track["length"])
			if _distance_to_segment(vampire.pos, six_king.pos, endpoint) <= vampire.radius + float(track["width"]) * 0.5:
				touching_track = true
	for index in remove_indices:
		track_structures.remove_at(index)
	if touching_track and _track_damage_timer <= 0.0:
		_track_damage_timer = 0.16
		var damage := 7.0 + phase * 3.5
		_damage(vampire, damage, vampire.pos, "-%d" % int(damage), Color("e5bd83"), false)
		stats["track_hits"] += 1
		vampire.velocity += (vampire.pos - six_king.pos).normalized() * 28.0

func _update_carriage(delta: float) -> void:
	carriage_angle += delta * (1.25 + phase * 0.15)
	var orbit_radius := 82.0 + phase * 11.0
	carriage_position = six_king.pos + Vector2.from_angle(carriage_angle) * orbit_radius
	if carriage_position.distance_to(vampire.pos) <= vampire.radius + 31.0 and _carriage_damage_timer <= 0.0:
		_carriage_damage_timer = 0.65
		var damage := 25.0 + phase * 8.0
		_damage(vampire, damage, carriage_position, "-%d" % int(damage), Color("f4f4f4"))
		vampire.velocity += (vampire.pos - carriage_position).normalized() * 110.0
		camera_shake = 7.0

func _update_trails(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = 0.045
	vampire.append_trail()
	six_king.append_trail()

func _damage(
	target: FighterState,
	amount: float,
	world_position: Vector2,
	label_text: String,
	color: Color,
	show_text: bool = true
) -> void:
	if finished or amount <= 0.0:
		return
	var actual := minf(amount, target.hp)
	target.hp = maxf(0.0, target.hp - amount)
	target.hit_flash = 1.0
	if target.id == "vampire":
		stats["damage_to_vampire"] += actual
	else:
		stats["damage_to_six_king"] += actual
		target.shield_flash = 1.0
	if show_text:
		spawn_floating_text(label_text, world_position + Vector2(rng.randf_range(-10.0, 10.0), -26.0), color, 0.72, 0.82)

func _heal(target: FighterState, amount: float, world_position: Vector2) -> void:
	if finished or amount <= 0.0:
		return
	var before := target.hp
	target.hp = minf(target.max_hp, target.hp + amount)
	var actual := target.hp - before
	if actual <= 0.0:
		return
	stats["vampire_healing"] += actual
	spawn_floating_text("+%d" % int(round(actual)), world_position, Color("26ef72"), 0.78, 0.9)

func _check_finish() -> void:
	if vampire.hp <= 0.0:
		_finish("six_king", "击败")
	elif six_king.hp <= 0.0:
		_finish("vampire", "击败")
	elif elapsed >= MAX_BATTLE_TIME:
		var vampire_ratio := vampire.hp_ratio()
		var king_ratio := six_king.hp_ratio()
		_finish("vampire" if vampire_ratio > king_ratio else "six_king", "时间裁定")

func _finish(new_winner_id: String, reason: String) -> void:
	finished = true
	winner_id = new_winner_id
	finish_reason = reason
	var winner := vampire if winner_id == "vampire" else six_king
	spawn_ring(winner.pos, Color("ffe75a"), winner.radius, 260.0, 1.8)
	spawn_particles(winner.pos, Color("ffe75a"), 50, 310.0)
	camera_shake = 12.0

func _update_transient_visuals(delta: float) -> void:
	for anchor in anchors:
		anchor["pulse"] = maxf(0.0, float(anchor["pulse"]) - delta * 2.4)

	var text_remove: Array[int] = []
	for index in range(floating_texts.size()):
		var item: Dictionary = floating_texts[index]
		item["ttl"] = float(item["ttl"]) - delta
		item["pos"] = Vector2(item["pos"]) + Vector2(0.0, -34.0 * delta)
		floating_texts[index] = item
		if float(item["ttl"]) <= 0.0:
			text_remove.push_front(index)
	for index in text_remove:
		floating_texts.remove_at(index)

	var particle_remove: Array[int] = []
	for index in range(particles.size()):
		var particle: Dictionary = particles[index]
		particle["ttl"] = float(particle["ttl"]) - delta
		particle["pos"] = Vector2(particle["pos"]) + Vector2(particle["velocity"]) * delta
		particle["velocity"] = Vector2(particle["velocity"]) * maxf(0.0, 1.0 - delta * 2.2)
		particles[index] = particle
		if float(particle["ttl"]) <= 0.0:
			particle_remove.push_front(index)
	for index in particle_remove:
		particles.remove_at(index)

	var ring_remove: Array[int] = []
	for index in range(impact_rings.size()):
		var ring: Dictionary = impact_rings[index]
		ring["ttl"] = float(ring["ttl"]) - delta
		var progress: float = 1.0 - float(ring["ttl"]) / float(ring["duration"])
		ring["radius"] = lerpf(float(ring["start_radius"]), float(ring["end_radius"]), clampf(progress, 0.0, 1.0))
		impact_rings[index] = ring
		if float(ring["ttl"]) <= 0.0:
			ring_remove.push_front(index)
	for index in ring_remove:
		impact_rings.remove_at(index)

func spawn_floating_text(text: String, position: Vector2, color: Color, ttl: float = 0.8, scale: float = 1.0) -> void:
	floating_texts.append({"text": text, "pos": position, "color": color, "ttl": ttl, "duration": ttl, "scale": scale})

func spawn_particles(position: Vector2, color: Color, count: int, speed: float) -> void:
	for _index in range(count):
		var velocity := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(speed * 0.35, speed)
		var ttl := rng.randf_range(0.22, 0.62)
		particles.append({
			"pos": position,
			"velocity": velocity,
			"color": color,
			"ttl": ttl,
			"duration": ttl,
			"size": rng.randf_range(2.0, 5.5),
		})

func spawn_ring(position: Vector2, color: Color, start_radius: float, end_radius: float, duration: float) -> void:
	impact_rings.append({
		"pos": position,
		"color": color,
		"start_radius": start_radius,
		"end_radius": end_radius,
		"radius": start_radius,
		"ttl": duration,
		"duration": duration,
	})

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)

func snapshot() -> Dictionary:
	return {
		"seed": seed_value,
		"elapsed_ms": int(round(elapsed * 1000.0)),
		"phase": phase,
		"finished": finished,
		"winner_id": winner_id,
		"vampire_hp": snappedf(vampire.hp, 0.001),
		"six_king_hp": snappedf(six_king.hp, 0.001),
		"vampire_pos": Vector2(snappedf(vampire.pos.x, 0.001), snappedf(vampire.pos.y, 0.001)),
		"six_king_pos": Vector2(snappedf(six_king.pos.x, 0.001), snappedf(six_king.pos.y, 0.001)),
		"anchors": anchors.size(),
		"tracks": track_structures.size(),
		"stats": stats.duplicate(true),
	}
