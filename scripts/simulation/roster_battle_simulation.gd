class_name RosterBattleSimulation
extends RefCounted

const BallBattleContextScript := preload("res://scripts/balls/core/ball_battle_context.gd")

const ARENA_SIZE := Vector2(640.0, 640.0)
const MAX_BATTLE_TIME := 52.0
const FIXED_STEP := 1.0 / 60.0
const DAMAGE_SCALE := 0.5
const RECOVERY_SCALE := 0.5

class FighterState:
	var id := ""
	var display_name := ""
	var color := Color.WHITE
	var accent := Color.WHITE
	var pos := Vector2.ZERO
	var velocity := Vector2.ZERO
	var radius := 27.0
	var hp := 100.0
	var max_hp := 100.0
	var base_speed := 180.0
	var contact_damage := 8.0
	var cooldown := 4.0
	var ability_timer := 1.0
	var secondary_timer := 0.0
	var ability_active := 0.0
	var invulnerable := 0.0
	var rotation := 0.0
	var aux_angle := 0.0
	var hit_flash := 0.0
	var shield_flash := 0.0
	var clone_count := 0
	var trail: Array[Vector2] = []

	func _init(spec: Dictionary, spawn_position: Vector2, spawn_velocity: Vector2, timer_offset: float) -> void:
		id = String(spec["id"])
		display_name = String(spec["name"])
		color = spec["color"] as Color
		accent = spec["accent"] as Color
		pos = spawn_position
		velocity = spawn_velocity
		radius = float(spec["radius"])
		hp = float(spec["max_hp"])
		max_hp = hp
		base_speed = float(spec["speed"])
		contact_damage = float(spec["contact_damage"])
		cooldown = float(spec["cooldown"])
		ability_timer = cooldown * timer_offset

	func hp_ratio() -> float:
		return clampf(hp / max_hp, 0.0, 1.0)

	func append_trail() -> void:
		trail.push_front(pos)
		if trail.size() > 22:
			trail.pop_back()

var rng := RandomNumberGenerator.new()
var seed_value := 20260815
var left_id := "splitter"
var right_id := "black_hole"
var elapsed := 0.0
var finished := false
var winner_id := ""
var winner_side := ""
var finish_reason := ""
var phase := 1

var left: FighterState
var right: FighterState
var left_module: BallModule
var right_module: BallModule
var left_ability: BallAbility
var right_ability: BallAbility
var battle_context

var projectiles: Array[Dictionary] = []
var impact_rings: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var fire_zones: Array[Dictionary] = []
var gravity_wells: Array[Dictionary] = []
var anchors: Array[Dictionary] = []

var camera_shake := 0.0
var phase_flash := 0.0
var _contact_timer := 0.0
var _trail_timer := 0.0

var stats := {}

func _init(initial_seed: int = 20260815, initial_left: String = "splitter", initial_right: String = "black_hole") -> void:
	reset(initial_seed, initial_left, initial_right)

func reset(new_seed: int, new_left: String, new_right: String) -> void:
	assert(BallRegistry.is_valid(), "Ball registry is invalid: %s" % ", ".join(BallRegistry.validation_errors()))
	assert(BallRegistry.has_id(new_left), "Unknown left ball id: %s" % new_left)
	assert(BallRegistry.has_id(new_right), "Unknown right ball id: %s" % new_right)
	seed_value = new_seed if new_seed != 0 else 20260815
	left_id = new_left
	right_id = new_right
	left_module = BallRegistry.get_module(left_id)
	right_module = BallRegistry.get_module(right_id)
	left_ability = left_module.create_ability()
	right_ability = right_module.create_ability()
	battle_context = BallBattleContextScript.new(self)
	rng.seed = seed_value
	elapsed = 0.0
	finished = false
	winner_id = ""
	winner_side = ""
	finish_reason = ""
	phase = 1
	left = FighterState.new(
		left_module.fighter_spec(),
		Vector2(152.0, 318.0),
		Vector2(186.0, -121.0).rotated(rng.randf_range(-0.16, 0.16)),
		0.48
	)
	right = FighterState.new(
		right_module.fighter_spec(),
		Vector2(488.0, 322.0),
		Vector2(-178.0, 132.0).rotated(rng.randf_range(-0.16, 0.16)),
		0.67
	)
	projectiles.clear()
	impact_rings.clear()
	particles.clear()
	floating_texts.clear()
	beams.clear()
	fire_zones.clear()
	gravity_wells.clear()
	anchors.clear()
	camera_shake = 0.0
	phase_flash = 0.0
	_contact_timer = 0.0
	_trail_timer = 0.0
	var ability_counts := {}
	for ball_id in BallRegistry.ids():
		ability_counts[ball_id] = 0
	stats = {
		"damage_to_left": 0.0,
		"damage_to_right": 0.0,
		"healing": 0.0,
		"contact_hits": 0,
		"projectiles_spawned": 0,
		"clones_spawned": 0,
		"heavy_hits": 0,
		"burn_hits": 0,
		"abilities": ability_counts,
	}

func step(delta: float = FIXED_STEP) -> void:
	delta = clampf(delta, 0.0, 0.05)
	_update_transient_visuals(delta)
	if finished:
		return
	elapsed += delta
	_update_phase()
	_update_fighter(left, right, left_ability, 0, delta)
	_update_fighter(right, left, right_ability, 1, delta)
	_resolve_collision()
	_update_ability(left, right, left_ability, 0, delta)
	_update_ability(right, left, right_ability, 1, delta)
	_update_projectiles(delta)
	_update_trails(delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	camera_shake = maxf(0.0, camera_shake - delta * 16.0)
	phase_flash = maxf(0.0, phase_flash - delta * 1.5)
	_check_finish()

func _update_phase() -> void:
	var new_phase := 1
	if elapsed >= 17.0:
		new_phase = 2
	if elapsed >= 34.0:
		new_phase = 3
	if new_phase != phase:
		phase = new_phase
		phase_flash = 1.0
		camera_shake = 6.0
		spawn_ring(ARENA_SIZE * 0.5, Color("ffe05c"), 20.0, 250.0, 0.9)
		spawn_text("第 %d 阶段" % phase, ARENA_SIZE * 0.5, Color("ffe05c"), 1.3)

func _update_fighter(fighter: FighterState, opponent: FighterState, ability: BallAbility, side: int, delta: float) -> void:
	fighter.ability_timer -= delta
	fighter.secondary_timer = maxf(0.0, fighter.secondary_timer - delta)
	fighter.ability_active = maxf(0.0, fighter.ability_active - delta)
	fighter.invulnerable = maxf(0.0, fighter.invulnerable - delta)
	fighter.hit_flash = maxf(0.0, fighter.hit_flash - delta * 4.5)
	fighter.shield_flash = maxf(0.0, fighter.shield_flash - delta * 3.5)
	fighter.aux_angle = fmod(fighter.aux_angle + delta * (2.0 + phase * 0.28) * (-1.0 if side == 0 else 1.0), TAU)

	var to_opponent := (opponent.pos - fighter.pos).normalized()
	var weave := sin(elapsed * (0.82 + side * 0.09) + float(seed_value % 97) * 0.01 + side * 2.1) * 0.52
	var desired_direction := to_opponent.rotated(weave)
	var speed_multiplier := (1.0 + (phase - 1) * 0.08) * ability.speed_multiplier(battle_context, fighter, opponent, side)
	var desired_velocity := desired_direction * fighter.base_speed * speed_multiplier
	fighter.velocity = fighter.velocity.lerp(desired_velocity, minf(1.0, delta * 0.48))
	fighter.pos += fighter.velocity * delta
	fighter.rotation += fighter.velocity.length() * delta * 0.003
	_resolve_wall(fighter)

func _resolve_wall(fighter: FighterState) -> void:
	var bounced := false
	if fighter.pos.x < fighter.radius:
		fighter.pos.x = fighter.radius
		fighter.velocity.x = absf(fighter.velocity.x)
		bounced = true
	elif fighter.pos.x > ARENA_SIZE.x - fighter.radius:
		fighter.pos.x = ARENA_SIZE.x - fighter.radius
		fighter.velocity.x = -absf(fighter.velocity.x)
		bounced = true
	if fighter.pos.y < fighter.radius:
		fighter.pos.y = fighter.radius
		fighter.velocity.y = absf(fighter.velocity.y)
		bounced = true
	elif fighter.pos.y > ARENA_SIZE.y - fighter.radius:
		fighter.pos.y = ARENA_SIZE.y - fighter.radius
		fighter.velocity.y = -absf(fighter.velocity.y)
		bounced = true
	if bounced:
		fighter.velocity = fighter.velocity.rotated(rng.randf_range(-0.035, 0.035))
		spawn_particles(fighter.pos, fighter.accent, 3, 55.0)

func _resolve_collision() -> void:
	var delta_pos := right.pos - left.pos
	var minimum_distance := left.radius + right.radius
	var distance := delta_pos.length()
	if distance >= minimum_distance or distance <= 0.001:
		return
	var normal := delta_pos / distance
	var overlap := minimum_distance - distance
	left.pos -= normal * overlap * 0.5
	right.pos += normal * overlap * 0.5
	var relative_speed := (right.velocity - left.velocity).dot(normal)
	if relative_speed < 0.0:
		var impulse := -relative_speed * 0.92
		left.velocity -= normal * impulse
		right.velocity += normal * impulse
	if _contact_timer > 0.0:
		return
	_contact_timer = 0.38
	stats["contact_hits"] = int(stats["contact_hits"]) + 1
	var left_damage := left_ability.contact_damage(battle_context, left, right, left.contact_damage + float(phase - 1) * 1.25)
	var right_damage := right_ability.contact_damage(battle_context, right, left, right.contact_damage + float(phase - 1) * 1.25)
	damage(right, left_damage, left.accent, left)
	damage(left, right_damage, right.accent, right)
	left_ability.after_contact(battle_context, left, right, left_damage)
	right_ability.after_contact(battle_context, right, left, right_damage)
	var impact := (left.pos + right.pos) * 0.5
	spawn_ring(impact, Color.WHITE, 8.0, 74.0, 0.3)
	spawn_particles(impact, Color("fff0a0"), 10, 150.0)
	camera_shake = maxf(camera_shake, 5.0)

func _update_ability(fighter: FighterState, opponent: FighterState, ability: BallAbility, side: int, delta: float) -> void:
	ability.on_step(battle_context, fighter, opponent, side, delta)
	if fighter.ability_timer > 0.0:
		return
	ability.activate(battle_context, fighter, opponent, side)
	fighter.ability_timer = ability.cooldown_duration(battle_context, fighter)
	_record_ability(fighter.id)

func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[index]
		projectile["ttl"] = float(projectile["ttl"]) - delta
		projectile["pos"] = Vector2(projectile["pos"]) + Vector2(projectile["velocity"]) * delta
		var target := right if int(projectile["owner"]) == 0 else left
		if Vector2(projectile["pos"]).distance_to(target.pos) <= target.radius + float(projectile["radius"]):
			var source := left if int(projectile["owner"]) == 0 else right
			damage(target, float(projectile["damage"]), Color(projectile["color"]), source)
			spawn_particles(projectile["pos"], projectile["color"], 5, 100.0)
			projectiles.remove_at(index)
			continue
		var pos: Vector2 = projectile["pos"]
		if float(projectile["ttl"]) <= 0.0 or pos.x < -20.0 or pos.x > 660.0 or pos.y < -20.0 or pos.y > 660.0:
			projectiles.remove_at(index)
		else:
			projectiles[index] = projectile

func damage(target: FighterState, amount: float, color: Color, source: FighterState, show_text: bool = true) -> float:
	if target.invulnerable > 0.0:
		target.shield_flash = 1.0
		if show_text:
			spawn_text("免疫", target.pos + Vector2(0.0, -38.0), Color("fff1a3"), 0.55)
		return 0.0
	var applied := minf(target.hp, maxf(0.0, amount) * DAMAGE_SCALE)
	target.hp = maxf(0.0, target.hp - applied)
	target.hit_flash = 1.0
	if target == left:
		stats["damage_to_left"] = float(stats["damage_to_left"]) + applied
	else:
		stats["damage_to_right"] = float(stats["damage_to_right"]) + applied
	if show_text and applied > 0.0:
		spawn_text("-%d" % int(ceil(applied)), target.pos + Vector2(0.0, -target.radius - 6.0), color, 0.6)
	if source != null and applied > 0.0:
		var source_ability: BallAbility = _ability_for_fighter(source)
		if source_ability != null:
			source_ability.after_damage_dealt(battle_context, source, target, applied)
	return applied

func heal(fighter: FighterState, amount: float) -> float:
	var applied := minf(amount * RECOVERY_SCALE, fighter.max_hp - fighter.hp)
	if applied <= 0.0:
		return 0.0
	fighter.hp += applied
	stats["healing"] = float(stats["healing"]) + applied
	spawn_text("+%d" % int(ceil(applied)), fighter.pos + Vector2(0.0, -fighter.radius - 10.0), Color("60ff87"), 0.65)
	return applied

func _ability_for_fighter(fighter: FighterState) -> BallAbility:
	if fighter == left:
		return left_ability
	if fighter == right:
		return right_ability
	return null

func _update_trails(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = 0.055
	left.append_trail()
	right.append_trail()

func _update_transient_visuals(delta: float) -> void:
	for index in range(impact_rings.size() - 1, -1, -1):
		var ring := impact_rings[index]
		ring["ttl"] = float(ring["ttl"]) - delta
		ring["radius"] = lerpf(float(ring["start_radius"]), float(ring["end_radius"]), 1.0 - float(ring["ttl"]) / float(ring["duration"]))
		if float(ring["ttl"]) <= 0.0:
			impact_rings.remove_at(index)
		else:
			impact_rings[index] = ring
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle["ttl"] = float(particle["ttl"]) - delta
		particle["pos"] = Vector2(particle["pos"]) + Vector2(particle["velocity"]) * delta
		particle["velocity"] = Vector2(particle["velocity"]) * pow(0.05, delta)
		if float(particle["ttl"]) <= 0.0:
			particles.remove_at(index)
		else:
			particles[index] = particle
	for index in range(floating_texts.size() - 1, -1, -1):
		var item := floating_texts[index]
		item["ttl"] = float(item["ttl"]) - delta
		item["pos"] = Vector2(item["pos"]) + Vector2(0.0, -28.0) * delta
		if float(item["ttl"]) <= 0.0:
			floating_texts.remove_at(index)
		else:
			floating_texts[index] = item
	_update_ttl_array(beams, delta)
	_update_ttl_array(fire_zones, delta)
	_update_ttl_array(gravity_wells, delta)
	_update_ttl_array(anchors, delta)

func _update_ttl_array(items: Array[Dictionary], delta: float) -> void:
	for index in range(items.size() - 1, -1, -1):
		items[index]["ttl"] = float(items[index]["ttl"]) - delta
		if float(items[index]["ttl"]) <= 0.0:
			items.remove_at(index)

func spawn_ring(position: Vector2, color: Color, start_radius: float, end_radius: float, duration: float) -> void:
	impact_rings.append({
		"pos": position, "color": color, "start_radius": start_radius, "end_radius": end_radius,
		"radius": start_radius, "duration": duration, "ttl": duration,
	})

func spawn_particles(position: Vector2, color: Color, count: int, speed: float) -> void:
	for _index in range(count):
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var duration := rng.randf_range(0.25, 0.62)
		particles.append({
			"pos": position, "velocity": direction * rng.randf_range(speed * 0.35, speed),
			"color": color, "size": rng.randf_range(2.0, 5.0), "duration": duration, "ttl": duration,
		})

func spawn_text(text: String, position: Vector2, color: Color, duration: float) -> void:
	floating_texts.append({"text": text, "pos": position, "color": color, "duration": duration, "ttl": duration})

func add_anchor(owner_side: int, position: Vector2, duration: float) -> void:
	anchors.append({"owner": owner_side, "pos": position, "ttl": duration, "duration": duration})

func add_beam(from: Vector2, to: Vector2, color: Color, duration: float, width: float) -> void:
	beams.append({"from": from, "to": to, "color": color, "ttl": duration, "duration": duration, "width": width})

func add_gravity_well(position: Vector2, duration: float, radius: float, color: Color) -> void:
	gravity_wells.append({"pos": position, "ttl": duration, "duration": duration, "radius": radius, "color": color})

func add_projectile(owner_side: int, position: Vector2, velocity: Vector2, radius: float, projectile_damage: float, color: Color, duration: float, type: String) -> void:
	projectiles.append({
		"owner": owner_side,
		"pos": position,
		"velocity": velocity,
		"radius": radius,
		"damage": projectile_damage,
		"color": color,
		"ttl": duration,
		"type": type,
	})
	record_stat("projectiles_spawned")

func add_fire_zone(owner_side: int, position: Vector2, duration: float, radius: float) -> void:
	fire_zones.append({"owner": owner_side, "pos": position, "ttl": duration, "duration": duration, "radius": radius})
	while fire_zones.size() > 42:
		fire_zones.pop_front()

func record_stat(key: String, amount: int = 1) -> void:
	assert(stats.has(key), "Unknown battle stat: %s" % key)
	stats[key] = int(stats[key]) + amount

func record_clone_spawn(amount: int) -> void:
	if amount > 0:
		record_stat("clones_spawned", amount)

func _record_ability(ball_id: String) -> void:
	var abilities: Dictionary = stats["abilities"]
	abilities[ball_id] = int(abilities[ball_id]) + 1
	stats["abilities"] = abilities

func ray_to_arena_edge(origin: Vector2, direction: Vector2) -> Vector2:
	var distances: Array[float] = []
	if direction.x > 0.001:
		distances.append((ARENA_SIZE.x - origin.x) / direction.x)
	elif direction.x < -0.001:
		distances.append((0.0 - origin.x) / direction.x)
	if direction.y > 0.001:
		distances.append((ARENA_SIZE.y - origin.y) / direction.y)
	elif direction.y < -0.001:
		distances.append((0.0 - origin.y) / direction.y)
	var minimum := 1000.0
	for value in distances:
		if value > 0.0:
			minimum = minf(minimum, value)
	return origin + direction * minimum

func _check_finish() -> void:
	if left.hp <= 0.0 or right.hp <= 0.0:
		if left.hp <= 0.0 and right.hp <= 0.0:
			_set_winner("left", "同归于尽·先手判定")
		elif right.hp <= 0.0:
			_set_winner("left", "击败")
		else:
			_set_winner("right", "击败")
	elif elapsed >= MAX_BATTLE_TIME:
		if left.hp_ratio() >= right.hp_ratio():
			_set_winner("left", "时限判定")
		else:
			_set_winner("right", "时限判定")

func _set_winner(side: String, reason: String) -> void:
	finished = true
	winner_side = side
	winner_id = left.id if side == "left" else right.id
	finish_reason = reason
	var winner := left if side == "left" else right
	spawn_ring(winner.pos, Color("ffe35c"), winner.radius, 260.0, 1.2)
	phase_flash = 1.0

func winner() -> FighterState:
	return left if winner_side == "left" else right

func snapshot() -> Dictionary:
	return {
		"elapsed": elapsed,
		"phase": phase,
		"finished": finished,
		"winner_id": winner_id,
		"winner_side": winner_side,
		"left_hp": left.hp,
		"right_hp": right.hp,
		"left_pos": left.pos,
		"right_pos": right.pos,
		"left_velocity": left.velocity,
		"right_velocity": right.velocity,
		"left_clones": left.clone_count,
		"right_clones": right.clone_count,
		"projectiles": projectiles.size(),
		"stats": stats.duplicate(true),
	}
