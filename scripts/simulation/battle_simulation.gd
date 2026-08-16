class_name BattleSimulation
extends RefCounted

const BallBattleContextScript := preload("res://scripts/balls/core/ball_battle_context.gd")
const ScenarioRegistryScript := preload("res://scripts/scenarios/core/scenario_registry.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")

const DEFAULT_ARENA_SIZE := GlobalGameSettingsScript.DEFAULT_ARENA_SIZE
const DEFAULT_BATTLE_TIME := GlobalGameSettingsScript.DEFAULT_BATTLE_TIME
const FIXED_STEP := 1.0 / 60.0
const DAMAGE_SCALE := 1.0
const RECOVERY_SCALE := 1.0

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
	var minimum_speed := 180.0
	var maximum_speed := 180.0
	var cooldown := 4.0
	var ability_timer := 1.0
	var rotation := 0.0
	var hit_flash := 0.0
	var trail: Array[Vector2] = []
	var status_effects: Array[BallStatusEffect] = []

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
		minimum_speed = float(spec.get("minimum_speed", base_speed))
		maximum_speed = float(spec.get("maximum_speed", base_speed))
		cooldown = float(spec["cooldown"])
		ability_timer = cooldown * timer_offset

	func hp_ratio() -> float:
		return clampf(hp / max_hp, 0.0, 1.0)

	func append_trail() -> void:
		trail.push_front(pos)
		if trail.size() > 22:
			trail.pop_back()

var rng := RandomNumberGenerator.new()
var visual_rng := RandomNumberGenerator.new()
var seed_value := 20260815
var left_id := ""
var right_id := ""
var elapsed := 0.0
var finished := false
var winner_id := ""
var winner_side := ""
var finish_reason := ""

var left: FighterState
var right: FighterState
var left_module: BallModule
var right_module: BallModule
var left_ability: BallAbility
var right_ability: BallAbility
var battle_context
var scenario
var left_profile := "default"
var right_profile := "default"
var max_battle_time := DEFAULT_BATTLE_TIME
var _arena_size := DEFAULT_ARENA_SIZE
var damage_scale := DAMAGE_SCALE
var recovery_scale := RECOVERY_SCALE
var contact_cooldown := 0.38
var collision_impulse := 0.92
var trail_interval := 0.055

var impact_rings: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var entities: Array[BallEntity] = []
var combat_events: Array[Dictionary] = []

var camera_shake := 0.0
var _contact_timer := 0.0
var _trail_timer := 0.0

var stats := {}

func _init(
	initial_seed: int,
	initial_left: String,
	initial_right: String,
	time_limit_seconds: float = -1.0,
	battle_arena_size: Vector2 = DEFAULT_ARENA_SIZE
) -> void:
	reset(initial_seed, initial_left, initial_right, time_limit_seconds, battle_arena_size)

func reset(
	new_seed: int,
	new_left: String,
	new_right: String,
	time_limit_seconds: float = -1.0,
	battle_arena_size: Vector2 = DEFAULT_ARENA_SIZE
) -> void:
	assert(BallRegistry.is_valid(), "Ball registry is invalid: %s" % ", ".join(BallRegistry.validation_errors()))
	assert(ScenarioRegistryScript.validation_errors().is_empty(), "Battle scenario registry is invalid: %s" % ", ".join(ScenarioRegistryScript.validation_errors()))
	assert(BallRegistry.has_id(new_left), "Unknown left ball id: %s" % new_left)
	assert(BallRegistry.has_id(new_right), "Unknown right ball id: %s" % new_right)
	_arena_size = Vector2(
		maxf(160.0, battle_arena_size.x),
		maxf(160.0, battle_arena_size.y)
	)
	seed_value = new_seed if new_seed != 0 else 20260815
	left_id = new_left
	right_id = new_right
	left_module = BallRegistry.get_module(left_id)
	right_module = BallRegistry.get_module(right_id)
	scenario = ScenarioRegistryScript.resolve(left_id, right_id)
	left_profile = scenario.left_profile
	right_profile = scenario.right_profile
	assert(left_module.has_profile(left_profile), "%s does not provide scenario profile %s" % [left_id, left_profile])
	assert(right_module.has_profile(right_profile), "%s does not provide scenario profile %s" % [right_id, right_profile])
	left_ability = left_module.create_profile_ability(left_profile)
	right_ability = right_module.create_profile_ability(right_profile)
	battle_context = BallBattleContextScript.new(self)
	max_battle_time = maxf(FIXED_STEP, time_limit_seconds if time_limit_seconds > 0.0 else DEFAULT_BATTLE_TIME)
	damage_scale = DAMAGE_SCALE
	recovery_scale = RECOVERY_SCALE
	contact_cooldown = scenario.contact_cooldown
	collision_impulse = scenario.collision_impulse
	trail_interval = scenario.trail_interval
	rng.seed = seed_value
	visual_rng.seed = seed_value ^ 0x5F3759DF
	elapsed = 0.0
	finished = false
	winner_id = ""
	winner_side = ""
	finish_reason = ""
	left = FighterState.new(
		left_module.fighter_spec(left_profile),
		_scaled_spawn_position(scenario.left_spawn_position),
		scenario.left_spawn_velocity.rotated(rng.randf_range(-0.16, 0.16) if scenario.randomize_spawn_angle else 0.0),
		scenario.left_timer_offset
	)
	right = FighterState.new(
		right_module.fighter_spec(right_profile),
		_scaled_spawn_position(scenario.right_spawn_position),
		scenario.right_spawn_velocity.rotated(rng.randf_range(-0.16, 0.16) if scenario.randomize_spawn_angle else 0.0),
		scenario.right_timer_offset
	)
	_clamp_fighter_to_arena(left)
	_clamp_fighter_to_arena(right)
	impact_rings.clear()
	particles.clear()
	floating_texts.clear()
	beams.clear()
	entities.clear()
	combat_events.clear()
	camera_shake = 0.0
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
		"abilities": ability_counts,
	}
	stats.merge(scenario.initial_stats(), true)
	left_ability.on_battle_started(battle_context, left, right, 0)
	right_ability.on_battle_started(battle_context, right, left, 1)

func _scaled_spawn_position(reference_position: Vector2) -> Vector2:
	return Vector2(
		reference_position.x * _arena_size.x / DEFAULT_ARENA_SIZE.x,
		reference_position.y * _arena_size.y / DEFAULT_ARENA_SIZE.y
	)

func _clamp_fighter_to_arena(fighter: FighterState) -> void:
	fighter.pos.x = clampf(fighter.pos.x, fighter.radius, _arena_size.x - fighter.radius)
	fighter.pos.y = clampf(fighter.pos.y, fighter.radius, _arena_size.y - fighter.radius)

func step(delta: float = FIXED_STEP) -> void:
	delta = clampf(delta, 0.0, 0.05)
	_update_transient_visuals(delta)
	_update_entity_lifetimes(delta)
	if finished:
		return
	elapsed += delta
	_update_fighter(left, right, left_ability, 0, delta)
	_update_fighter(right, left, right_ability, 1, delta)
	_resolve_collision()
	_update_ability(left, right, left_ability, 0, delta)
	_update_ability(right, left, right_ability, 1, delta)
	_update_entities(delta)
	left_ability.after_entities_step(battle_context, left, right, 0, delta)
	right_ability.after_entities_step(battle_context, right, left, 1, delta)
	_update_trails(delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	camera_shake = maxf(0.0, camera_shake - delta * 16.0)
	_check_finish()

func _update_fighter(fighter: FighterState, opponent: FighterState, ability: BallAbility, side: int, delta: float) -> void:
	ability.before_motion(battle_context, fighter, opponent, side, delta)
	_update_status_effects(fighter, delta)
	fighter.ability_timer -= delta
	fighter.hit_flash = maxf(0.0, fighter.hit_flash - delta * 4.5)

	# 普通球没有互相追踪或吸引力：方向只来自初速度、墙面反弹、球体碰撞和显式技能。
	var speed_multiplier := ability.speed_multiplier(battle_context, fighter, opponent, side)
	var target_minimum_speed := fighter.minimum_speed * speed_multiplier
	var target_maximum_speed := fighter.maximum_speed * speed_multiplier
	if fighter.velocity.length_squared() <= 0.001:
		fighter.velocity = Vector2.from_angle(rng.randf_range(0.0, TAU)) * target_minimum_speed
	elif not _preserves_external_velocity(fighter):
		var speed := fighter.velocity.length()
		if speed < target_minimum_speed:
			fighter.velocity = fighter.velocity.normalized() * target_minimum_speed
		elif speed > target_maximum_speed:
			fighter.velocity = fighter.velocity.normalized() * target_maximum_speed
	else:
		fighter.velocity = fighter.velocity.limit_length(maxf(target_maximum_speed * 2.4, target_maximum_speed))
	fighter.pos += fighter.velocity * delta
	fighter.rotation += fighter.velocity.length() * delta * 0.003
	_resolve_wall(fighter)

func _resolve_wall(fighter: FighterState) -> void:
	var bounced := false
	if fighter.pos.x < fighter.radius:
		fighter.pos.x = fighter.radius
		fighter.velocity.x = absf(fighter.velocity.x)
		bounced = true
	elif fighter.pos.x > _arena_size.x - fighter.radius:
		fighter.pos.x = _arena_size.x - fighter.radius
		fighter.velocity.x = -absf(fighter.velocity.x)
		bounced = true
	if fighter.pos.y < fighter.radius:
		fighter.pos.y = fighter.radius
		fighter.velocity.y = absf(fighter.velocity.y)
		bounced = true
	elif fighter.pos.y > _arena_size.y - fighter.radius:
		fighter.pos.y = _arena_size.y - fighter.radius
		fighter.velocity.y = -absf(fighter.velocity.y)
		bounced = true
	if bounced:
		fighter.velocity = fighter.velocity.rotated(rng.randf_range(-0.035, 0.035))
		spawn_particles(fighter.pos, fighter.accent, 3, 55.0)
		for effect in fighter.status_effects.duplicate():
			effect.on_wall_hit(battle_context, fighter)

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
		var impulse := -relative_speed * collision_impulse
		left.velocity -= normal * impulse
		right.velocity += normal * impulse
	if _contact_timer > 0.0:
		return
	_contact_timer = contact_cooldown
	stats["contact_hits"] = int(stats["contact_hits"]) + 1
	var left_contact_damage := maxf(0.0, left_ability.contact_damage(battle_context, left, right))
	var right_contact_damage := maxf(0.0, right_ability.contact_damage(battle_context, right, left))
	var left_damage_dealt := damage(right, left_contact_damage, left.accent, left) if left_contact_damage > 0.0 else 0.0
	var right_damage_dealt := damage(left, right_contact_damage, right.accent, right) if right_contact_damage > 0.0 else 0.0
	left_ability.after_contact(battle_context, left, right, left_damage_dealt)
	right_ability.after_contact(battle_context, right, left, right_damage_dealt)
	var impact := (left.pos + right.pos) * 0.5
	spawn_ring(impact, Color.WHITE, 8.0, 74.0, 0.3)
	spawn_particles(impact, Color("fff0a0"), 10, 150.0)
	camera_shake = maxf(camera_shake, 5.0)

func _update_ability(fighter: FighterState, opponent: FighterState, ability: BallAbility, side: int, delta: float) -> void:
	ability.on_step(battle_context, fighter, opponent, side, delta)
	if not ability.automatic_activation_enabled():
		return
	if fighter.ability_timer > 0.0:
		return
	ability.activate(battle_context, fighter, opponent, side)
	fighter.ability_timer = ability.cooldown_duration(battle_context, fighter)
	_record_ability(fighter.id)

func damage(target: FighterState, amount: float, color: Color, source: FighterState, show_text: bool = true) -> float:
	for effect in target.status_effects:
		if effect.blocks_damage(battle_context, target, amount, source):
			effect.on_damage_blocked(battle_context, target, source, show_text)
			return 0.0
	var applied := minf(target.hp, maxf(0.0, amount) * damage_scale)
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

func damage_entity(
	target: BallEntity,
	amount: float,
	color: Color,
	source_side: int,
	show_text: bool = true
) -> float:
	if target == null or not target.can_receive_attack(source_side):
		return 0.0
	var applied := target.receive_attack(
		battle_context,
		maxf(0.0, amount) * damage_scale,
		source_side,
		color
	)
	if applied <= 0.0:
		return 0.0
	if show_text:
		spawn_text("-%d" % int(ceil(applied)), target.pos + Vector2(0.0, -target.radius - 6.0), color, 0.6)
	var source := fighter_for_side(source_side)
	var source_ability: BallAbility = _ability_for_fighter(source)
	if source_ability != null:
		source_ability.after_damage_dealt(battle_context, source, null, applied)
	return applied

func contact_damage_for_side(source_side: int, target) -> float:
	var source := fighter_for_side(source_side)
	var source_ability: BallAbility = _ability_for_fighter(source)
	if source_ability == null:
		return 0.0
	return maxf(0.0, source_ability.contact_damage(battle_context, source, target))

func heal(fighter: FighterState, amount: float) -> float:
	var applied := minf(amount * recovery_scale, fighter.max_hp - fighter.hp)
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

func _update_status_effects(fighter: FighterState, delta: float) -> void:
	for index in range(fighter.status_effects.size() - 1, -1, -1):
		var effect := fighter.status_effects[index]
		effect.tick(battle_context, fighter, delta)
		if effect.is_expired():
			fighter.status_effects.remove_at(index)

func _preserves_external_velocity(fighter: FighterState) -> bool:
	for effect in fighter.status_effects:
		if effect.preserves_external_velocity():
			return true
	return false

func _update_trails(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = trail_interval
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

func _update_ttl_array(items: Array[Dictionary], delta: float) -> void:
	for index in range(items.size() - 1, -1, -1):
		items[index]["ttl"] = float(items[index]["ttl"]) - delta
		if float(items[index]["ttl"]) <= 0.0:
				items.remove_at(index)

func _update_entity_lifetimes(delta: float) -> void:
	for entity in entities:
		entity.process_lifetime(delta)
	_remove_finished_entities()

func _update_entities(delta: float) -> void:
	for entity in entities.duplicate():
		if not entity.removed:
			entity.process_step(battle_context, delta)
	_remove_finished_entities()

func _remove_finished_entities() -> void:
	for index in range(entities.size() - 1, -1, -1):
		if entities[index].removed:
			entities.remove_at(index)

func spawn_ring(position: Vector2, color: Color, start_radius: float, end_radius: float, duration: float) -> void:
	impact_rings.append({
		"pos": position, "color": color, "start_radius": start_radius, "end_radius": end_radius,
		"radius": start_radius, "duration": duration, "ttl": duration,
	})

func spawn_particles(position: Vector2, color: Color, count: int, speed: float) -> void:
	for _index in range(count):
		var direction := Vector2.from_angle(visual_rng.randf_range(0.0, TAU))
		var duration := visual_rng.randf_range(0.25, 0.62)
		particles.append({
			"pos": position, "velocity": direction * visual_rng.randf_range(speed * 0.35, speed),
			"color": color, "size": visual_rng.randf_range(2.0, 5.0), "duration": duration, "ttl": duration,
		})

func spawn_text(text: String, position: Vector2, color: Color, duration: float) -> void:
	floating_texts.append({"text": text, "pos": position, "color": color, "duration": duration, "ttl": duration})

func add_beam(from: Vector2, to: Vector2, color: Color, duration: float, width: float) -> void:
	beams.append({"from": from, "to": to, "color": color, "ttl": duration, "duration": duration, "width": width})

func add_projectile(owner_side: int, position: Vector2, velocity: Vector2, radius: float, projectile_damage: float, color: Color, duration: float, type: String) -> void:
	add_entity(BallProjectileEntity.new(owner_side, position, velocity, radius, projectile_damage, color, duration, type))
	record_stat("projectiles_spawned")

func add_entity(entity: BallEntity) -> BallEntity:
	assert(entity != null, "Cannot add a null battle entity")
	entities.append(entity)
	return entity

func entity_list(owner_side: int = -1, tag: String = "") -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for entity in entities:
		if entity.removed or entity.is_captured():
			continue
		if owner_side >= 0 and entity.owner_side != owner_side:
			continue
		if not tag.is_empty() and not entity.has_tag(tag):
			continue
		result.append(entity)
	return result

func count_entities(owner_side: int, tag: String) -> int:
	return entity_list(owner_side, tag).size()

func apply_status(target: FighterState, effect: BallStatusEffect) -> BallStatusEffect:
	assert(effect != null and not effect.key.is_empty(), "Status effects require a stable key")
	for existing in target.status_effects:
		if existing.key == effect.key:
			existing.refresh_from(effect)
			return existing
	target.status_effects.append(effect)
	return effect

func has_status(target: FighterState, key_prefix: String) -> bool:
	for effect in target.status_effects:
		if effect.key.begins_with(key_prefix) and not effect.is_expired():
			return true
	return false

func arena_size() -> Vector2:
	return _arena_size

func fighter_for_side(side: int) -> FighterState:
	return left if side == 0 else right

func opponent_for_side(side: int) -> FighterState:
	return right if side == 0 else left

func side_for_fighter(fighter: FighterState) -> int:
	return 0 if fighter == left else 1

func emit_combat_event(kind: String, strength: float) -> void:
	combat_events.append({"kind": kind, "strength": clampf(strength, 0.0, 1.0)})

func take_combat_events() -> Array[Dictionary]:
	var result := combat_events.duplicate(true)
	combat_events.clear()
	return result

func record_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount

func _record_ability(ball_id: String) -> void:
	var abilities: Dictionary = stats["abilities"]
	abilities[ball_id] = int(abilities[ball_id]) + 1
	stats["abilities"] = abilities

func ray_to_arena_edge(origin: Vector2, direction: Vector2) -> Vector2:
	var distances: Array[float] = []
	if direction.x > 0.001:
		distances.append((_arena_size.x - origin.x) / direction.x)
	elif direction.x < -0.001:
		distances.append((0.0 - origin.x) / direction.x)
	if direction.y > 0.001:
		distances.append((_arena_size.y - origin.y) / direction.y)
	elif direction.y < -0.001:
		distances.append((0.0 - origin.y) / direction.y)
	var minimum := INF
	for value in distances:
		if value > 0.0:
			minimum = minf(minimum, value)
	return origin if is_inf(minimum) else origin + direction * minimum

func _check_finish() -> void:
	if left.hp <= 0.0 or right.hp <= 0.0:
		if left.hp <= 0.0 and right.hp <= 0.0:
			_set_winner("left", "同归于尽·先手判定")
		elif right.hp <= 0.0:
			_set_winner("left", "击败")
		else:
			_set_winner("right", "击败")
	elif elapsed >= max_battle_time:
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

func winner() -> FighterState:
	return left if winner_side == "left" else right

func snapshot() -> Dictionary:
	return {
		"elapsed": elapsed,
		"arena_size": _arena_size,
		"finished": finished,
		"winner_id": winner_id,
		"winner_side": winner_side,
		"scenario_id": scenario.id,
		"left_hp": left.hp,
		"right_hp": right.hp,
		"left_pos": left.pos,
		"right_pos": right.pos,
		"left_velocity": left.velocity,
		"right_velocity": right.velocity,
		"left_clones": count_entities(0, "clone"),
		"right_clones": count_entities(1, "clone"),
		"projectiles": entity_list(-1, "projectile").size(),
		"stats": stats.duplicate(true),
	}
