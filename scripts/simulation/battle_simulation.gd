class_name BattleSimulation
extends RefCounted

const BallBattleContextScript := preload("res://scripts/balls/core/ball_battle_context.gd")
const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const FighterDeathEffectEntityScript := preload("res://scripts/balls/core/fighter_death_effect_entity.gd")
const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")
const CombatLedgerScript := preload("res://scripts/logging/combat_ledger.gd")

const DEFAULT_ARENA_SIZE := GlobalGameSettingsScript.DEFAULT_ARENA_SIZE
const DEFAULT_BATTLE_TIME := GlobalGameSettingsScript.DEFAULT_BATTLE_TIME
const FIXED_STEP := 1.0 / 60.0
const DAMAGE_SCALE := 1.0
const RECOVERY_SCALE := 1.0
const SPAWN_SEED_SALT := 0x6C8E9CF5
const CONTACT_COOLDOWN := 0.38
const COLLISION_IMPULSE := 0.92
const TRAIL_INTERVAL := 0.055
const ABILITY_TIMER_OFFSET := 0.6
const LEFT_SPAWN_RATIO := Vector2(0.25, 0.5)
const RIGHT_SPAWN_RATIO := Vector2(0.75, 0.5)
const WALL_IMPACT_REFERENCE_SPEED := 720.0
const WALL_IMPACT_MIN_STRENGTH := 0.12
const WALL_IMPACT_MAX_STRENGTH := 0.28

class FighterState:
	var fighter_uid := -1
	var team_id := -1
	var roster_index := -1
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

	func _init(uid: int, owner_team: int, roster_slot: int, spec: Dictionary, spawn_position: Vector2, spawn_velocity: Vector2, timer_offset: float) -> void:
		fighter_uid = uid
		team_id = owner_team
		roster_index = roster_slot
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

class TeamState:
	var team_id := -1
	var display_name := ""
	var color := Color.TRANSPARENT
	var roster: Array[String] = []
	var roster_max_hp: Array[float] = []
	var total_max_hp := 0.0
	var active_limit := 1
	var next_roster_index := 0
	var active_fighters: Array[FighterState] = []
	var last_fighter: FighterState
	var eliminated := false

	func _init(spec: Dictionary) -> void:
		team_id = int(spec["id"])
		display_name = String(spec.get("name", "阵营 %d" % (team_id + 1)))
		color = spec.get("color", Color.TRANSPARENT) as Color
		for ball_id in spec["roster"]:
			var normalized_ball_id := String(ball_id)
			roster.append(normalized_ball_id)
			var maximum_hp := (
				float(BallRegistry.get_module(normalized_ball_id).fighter_spec()["max_hp"])
			)
			roster_max_hp.append(maximum_hp)
			total_max_hp += maximum_hp
		active_limit = int(spec["active_count"])

	func queued_count() -> int:
		return maxi(0, roster.size() - next_roster_index)

var rng := RandomNumberGenerator.new()
var visual_rng := RandomNumberGenerator.new()
var _spawn_rng := RandomNumberGenerator.new()
var seed_value := 20260815
var battle_setup
var mode_rules := {}
var teams: Array[TeamState] = []
var fighters: Array[FighterState] = []
var fighter_history: Array[FighterState] = []
var team_events: Array[Dictionary] = []

var elapsed := 0.0
var finished := false
var winner_id := ""
var winner_side := ""
var winner_team_id := -1
var finish_reason := ""
var battle_context
var max_battle_time := DEFAULT_BATTLE_TIME
var _arena_size := DEFAULT_ARENA_SIZE
var damage_scale := DAMAGE_SCALE
var recovery_scale := RECOVERY_SCALE
var contact_cooldown := CONTACT_COOLDOWN
var collision_impulse := COLLISION_IMPULSE
var trail_interval := TRAIL_INTERVAL
var death_effect_duration := GlobalGameSettingsScript.DEFAULT_RESULT_REVEAL_DELAY
var handoff_pause_duration_seconds := GlobalGameSettingsScript.DEFAULT_RELAY_HANDOFF_PAUSE
var damage_number_duration_seconds := GlobalGameSettingsScript.DEFAULT_DAMAGE_NUMBER_DURATION

const MAX_VISUAL_PARTICLES := 640
const MAX_IMPACT_RINGS := 96

var impact_rings: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var entities: Array[BallEntity] = []
var combat_events: Array[Dictionary] = []
var camera_shake := 0.0

var _trail_timer := 0.0
var _next_fighter_uid := 1
var _module_by_uid := {}
var _ability_by_uid := {}
var _contact_timers := {}
var _pending_deaths: Array[FighterState] = []
var _pending_death_uids := {}
var _pending_replacements: Array[Dictionary] = []
var _replacement_pause_remaining := 0.0
var _world_stop_remaining := 0.0
var _world_stop_source_fighter_uid := -1
var _execution_fighter: FighterState
var _combat_execution_entity: BallEntity
var _combat_status_source: Dictionary = {}
var combat_ledger = CombatLedgerScript.new()
var stats := {}

func _init(initial_seed: int, initial_left, initial_right = null, option_four = -1.0, option_five = DEFAULT_ARENA_SIZE) -> void:
	if initial_left is Object and initial_left.get_script() == BattleSetupScript:
		var setup_time := float(initial_right) if initial_right is float or initial_right is int else -1.0
		var setup_arena := option_four as Vector2 if option_four is Vector2 else DEFAULT_ARENA_SIZE
		var setup_rules := option_five as Dictionary if option_five is Dictionary else {}
		reset_setup(initial_seed, initial_left, setup_time, setup_arena, setup_rules)
	else:
		reset(initial_seed, String(initial_left), String(initial_right), float(option_four), option_five as Vector2)

func reset(new_seed: int, new_left: String, new_right: String, time_limit_seconds: float = -1.0, battle_arena_size: Vector2 = DEFAULT_ARENA_SIZE) -> void:
	reset_setup(new_seed, BattleSetupScript.duel(new_left, new_right), time_limit_seconds, battle_arena_size)

func reset_setup(
	new_seed: int,
	requested_setup,
	time_limit_seconds: float = -1.0,
	battle_arena_size: Vector2 = DEFAULT_ARENA_SIZE,
	battle_mode_rules: Dictionary = {}
) -> void:
	assert(BallRegistry.is_valid(), "Ball registry is invalid: %s" % ", ".join(BallRegistry.validation_errors()))
	assert(requested_setup != null and requested_setup.get_script() == BattleSetupScript, "Battle setup is required")
	assert(requested_setup.is_valid(), "Invalid battle setup: %s" % ", ".join(requested_setup.validation_errors()))
	battle_setup = BattleSetupScript.new(String(requested_setup.mode), requested_setup.teams.duplicate(true))
	mode_rules = battle_mode_rules.duplicate(true)
	_arena_size = Vector2(maxf(160.0, battle_arena_size.x), maxf(160.0, battle_arena_size.y))
	seed_value = new_seed if new_seed != 0 else 20260815
	max_battle_time = maxf(FIXED_STEP, time_limit_seconds if time_limit_seconds > 0.0 else DEFAULT_BATTLE_TIME)
	damage_scale = DAMAGE_SCALE
	recovery_scale = RECOVERY_SCALE
	contact_cooldown = CONTACT_COOLDOWN
	collision_impulse = COLLISION_IMPULSE
	trail_interval = TRAIL_INTERVAL
	rng.seed = seed_value
	visual_rng.seed = seed_value ^ 0x5F3759DF
	_spawn_rng.seed = seed_value ^ SPAWN_SEED_SALT
	elapsed = 0.0
	finished = false
	winner_id = ""
	winner_side = ""
	winner_team_id = -1
	finish_reason = ""
	battle_context = BallBattleContextScript.new(self)
	teams.clear()
	fighters.clear()
	fighter_history.clear()
	team_events.clear()
	_module_by_uid.clear()
	_ability_by_uid.clear()
	_contact_timers.clear()
	_pending_deaths.clear()
	_pending_death_uids.clear()
	_pending_replacements.clear()
	_replacement_pause_remaining = 0.0
	_world_stop_remaining = 0.0
	_world_stop_source_fighter_uid = -1
	_execution_fighter = null
	_combat_execution_entity = null
	_combat_status_source = {}
	combat_ledger = CombatLedgerScript.new()
	_next_fighter_uid = 1
	impact_rings.clear()
	particles.clear()
	floating_texts.clear()
	beams.clear()
	entities.clear()
	combat_events.clear()
	camera_shake = 0.0
	_trail_timer = 0.0
	_initialize_stats()
	for team_spec in battle_setup.teams:
		teams.append(TeamState.new(team_spec))
	for team_index in range(teams.size()):
		var team := teams[team_index]
		for slot_index in range(team.active_limit):
			_spawn_next_fighter(team, _initial_spawn_position(team_index, slot_index, team.active_limit))
	for fighter in fighters.duplicate():
		_start_fighter_ability(fighter)

func _initialize_stats() -> void:
	var ability_counts := {}
	for ball_id in BallRegistry.ids():
		ability_counts[ball_id] = 0
	stats = {
		"damage_to_left": 0.0, "damage_to_right": 0.0,
		"damage_to_team": {}, "damage_by_team": {}, "healing": 0.0,
		"contact_hits": 0, "fighter_entity_contact_hits": 0,
		"projectiles_spawned": 0, "fighter_replacements": 0,
		"team_eliminations": 0, "abilities": ability_counts,
	}

func _spawn_next_fighter(team: TeamState, spawn_position: Vector2) -> FighterState:
	if team.next_roster_index >= team.roster.size():
		return null
	var roster_index := team.next_roster_index
	var ball_id := team.roster[roster_index]
	var module: BallModule = BallRegistry.get_module(ball_id)
	var spec: Dictionary = module.fighter_spec().duplicate(true)
	var fighter := FighterState.new(_next_fighter_uid, team.team_id, roster_index, spec, spawn_position, _seeded_spawn_velocity(float(spec["speed"])), ABILITY_TIMER_OFFSET)
	_next_fighter_uid += 1
	team.next_roster_index += 1
	team.active_fighters.append(fighter)
	team.last_fighter = fighter
	fighters.append(fighter)
	fighter_history.append(fighter)
	combat_ledger.ensure_actor(_fighter_combat_identity(fighter))
	_module_by_uid[fighter.fighter_uid] = module
	_ability_by_uid[fighter.fighter_uid] = module.create_ability()
	_clamp_fighter_to_arena(fighter)
	return fighter

func _start_fighter_ability(fighter: FighterState) -> void:
	var opponent := nearest_hostile_fighter(fighter)
	if opponent == null:
		return
	var previous_scope := _set_execution_fighter(fighter)
	_ability_for_fighter(fighter).on_battle_started(battle_context, fighter, opponent, fighter.team_id)
	_set_execution_fighter(previous_scope)

func _initial_spawn_position(team_index: int, slot_index: int, slot_count: int) -> Vector2:
	var anchor := Vector2.ZERO
	var tangent := Vector2.DOWN
	if teams.size() == 2:
		anchor = _spawn_position(LEFT_SPAWN_RATIO if team_index == 0 else RIGHT_SPAWN_RATIO)
	else:
		var angle := -PI * 0.5 + TAU * float(team_index) / float(teams.size())
		anchor = _arena_size * 0.5 + Vector2(cos(angle) * _arena_size.x * 0.31, sin(angle) * _arena_size.y * 0.31)
		tangent = Vector2.from_angle(angle + PI * 0.5)
	var centered_slot := float(slot_index) - float(slot_count - 1) * 0.5
	return anchor + tangent * centered_slot * 68.0

func _spawn_position(ratio: Vector2) -> Vector2:
	return Vector2(_arena_size.x * ratio.x, _arena_size.y * ratio.y)

func _seeded_spawn_velocity(speed: float) -> Vector2:
	return Vector2.ZERO if speed <= 0.001 else Vector2.from_angle(_spawn_rng.randf_range(0.0, TAU)) * speed

func _clamp_fighter_to_arena(fighter: FighterState) -> void:
	fighter.pos.x = clampf(fighter.pos.x, fighter.radius, _arena_size.x - fighter.radius)
	fighter.pos.y = clampf(fighter.pos.y, fighter.radius, _arena_size.y - fighter.radius)

func step(delta: float = FIXED_STEP) -> void:
	delta = clampf(delta, 0.0, 0.05)
	_update_transient_visuals(delta)
	if finished:
		# 对局结束后仍需让死亡碎片等揭晓演出自然收尾。
		_update_entity_lifetimes(delta)
		return
	if _world_stop_remaining > 0.0:
		_advance_world_stop(delta)
		return
	_update_entity_lifetimes(delta)
	if not _pending_replacements.is_empty():
		_advance_pending_replacements(delta)
		return
	elapsed += delta
	_tick_contact_timers(delta)
	for fighter in fighters.duplicate():
		if fighter.hp <= 0.0:
			continue
		var opponent := nearest_hostile_fighter(fighter)
		if opponent != null:
			_update_fighter(fighter, opponent, _ability_for_fighter(fighter), fighter.team_id, delta)
	_resolve_fighter_collisions()
	for fighter in fighters.duplicate():
		if fighter.hp <= 0.0:
			continue
		var opponent := nearest_hostile_fighter(fighter)
		if opponent != null:
			_update_ability(fighter, opponent, _ability_for_fighter(fighter), fighter.team_id, delta)
	_update_entities(delta)
	_resolve_fighter_entity_collisions()
	for fighter in fighters.duplicate():
		if fighter.hp <= 0.0:
			continue
		var opponent := nearest_hostile_fighter(fighter)
		if opponent == null:
			continue
		var previous_scope := _set_execution_fighter(fighter)
		_ability_for_fighter(fighter).after_entities_step(battle_context, fighter, opponent, fighter.team_id, delta)
		_set_execution_fighter(previous_scope)
	_update_trails(delta)
	camera_shake = maxf(0.0, camera_shake - delta * 16.0)
	_process_pending_deaths()
	_check_finish()

func _update_fighter(fighter: FighterState, opponent: FighterState, ability: BallAbility, side: int, delta: float) -> void:
	var previous_scope := _set_execution_fighter(fighter)
	ability.before_motion(battle_context, fighter, opponent, side, delta)
	_update_status_effects(fighter, delta)
	if fighter.hp <= 0.0:
		_set_execution_fighter(previous_scope)
		return
	fighter.ability_timer -= delta
	fighter.hit_flash = maxf(0.0, fighter.hit_flash - delta * 4.5)
	var speed_multiplier := ability.speed_multiplier(battle_context, fighter, opponent, side)
	var status_slow := 1.0
	var status_haste := 1.0
	for effect: BallStatusEffect in fighter.status_effects:
		if effect.is_expired(): continue
		var modifier := maxf(0.0, effect.fighter_speed_multiplier())
		if modifier < 1.0: status_slow = minf(status_slow, modifier)
		else: status_haste = maxf(status_haste, modifier)
	speed_multiplier *= status_slow * status_haste
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
	_set_execution_fighter(previous_scope)

func _resolve_wall(fighter: FighterState) -> void:
	var bounced := false
	var horizontal := false
	var vertical := false
	var wall_x := 0.0
	var wall_y := 0.0
	if fighter.pos.x < fighter.radius:
		fighter.pos.x = fighter.radius
		fighter.velocity.x = absf(fighter.velocity.x)
		bounced = true
		vertical = true
	elif fighter.pos.x > _arena_size.x - fighter.radius:
		fighter.pos.x = _arena_size.x - fighter.radius
		fighter.velocity.x = -absf(fighter.velocity.x)
		bounced = true
		vertical = true
		wall_x = _arena_size.x
	if fighter.pos.y < fighter.radius:
		fighter.pos.y = fighter.radius
		fighter.velocity.y = absf(fighter.velocity.y)
		bounced = true
		horizontal = true
	elif fighter.pos.y > _arena_size.y - fighter.radius:
		fighter.pos.y = _arena_size.y - fighter.radius
		fighter.velocity.y = -absf(fighter.velocity.y)
		bounced = true
		horizontal = true
		wall_y = _arena_size.y
	if not bounced:
		return
	fighter.velocity = fighter.velocity.rotated(rng.randf_range(-0.035, 0.035))
	emit_combat_event("wall_impact", clampf(fighter.velocity.length() / WALL_IMPACT_REFERENCE_SPEED, WALL_IMPACT_MIN_STRENGTH, WALL_IMPACT_MAX_STRENGTH))
	var contact_position := fighter.pos
	if vertical: contact_position.x = wall_x
	if horizontal: contact_position.y = wall_y
	spawn_particles(contact_position, fighter.accent, 6, 95.0)
	spawn_ring(contact_position, fighter.accent, 3.0, 34.0, 0.30)
	var opponent := nearest_hostile_fighter(fighter)
	var ability := _ability_for_fighter(fighter)
	if opponent != null and ability.after_wall_hit(battle_context, fighter, opponent, fighter.team_id, contact_position):
		_record_ability(fighter.id)
	_notify_status_wall_hit(fighter)

func _resolve_fighter_collisions() -> void:
	for first_index in range(fighters.size()):
		var first := fighters[first_index]
		if first.hp <= 0.0: continue
		for second_index in range(first_index + 1, fighters.size()):
			var second := fighters[second_index]
			if second.hp > 0.0: _resolve_fighter_pair(first, second)

func _resolve_fighter_pair(first: FighterState, second: FighterState) -> void:
	var delta_pos := second.pos - first.pos
	var minimum_distance := first.radius + second.radius
	var distance := delta_pos.length()
	if distance >= minimum_distance or distance <= 0.001: return
	var normal := delta_pos / distance
	var overlap := minimum_distance - distance
	first.pos -= normal * overlap * 0.5
	second.pos += normal * overlap * 0.5
	_clamp_fighter_to_arena(first)
	_clamp_fighter_to_arena(second)
	var relative_speed := (second.velocity - first.velocity).dot(normal)
	if relative_speed < 0.0:
		var impulse := -relative_speed * collision_impulse
		first.velocity -= normal * impulse
		second.velocity += normal * impulse
	if first.team_id == second.team_id: return
	var pair_key := _fighter_pair_key(first, second)
	if float(_contact_timers.get(pair_key, 0.0)) > 0.0: return
	_contact_timers[pair_key] = contact_cooldown
	stats["contact_hits"] = int(stats["contact_hits"]) + 1
	emit_combat_event("body_impact", clampf(maxf(0.0, -relative_speed) / 360.0, 0.5, 1.0))
	var first_ability := _ability_for_fighter(first)
	var second_ability := _ability_for_fighter(second)
	var previous_scope := _set_execution_fighter(first)
	var first_contact_damage := maxf(0.0, first_ability.contact_damage(battle_context, first, second))
	_set_execution_fighter(second)
	var second_contact_damage := maxf(0.0, second_ability.contact_damage(battle_context, second, first))
	_set_execution_fighter(previous_scope)
	var first_dealt := damage(second, first_contact_damage, first.accent, first) if first_contact_damage > 0.0 else 0.0
	var second_dealt := damage(first, second_contact_damage, second.accent, second) if second_contact_damage > 0.0 else 0.0
	previous_scope = _set_execution_fighter(first)
	first_ability.after_contact(battle_context, first, second, first_dealt)
	_set_execution_fighter(second)
	second_ability.after_contact(battle_context, second, first, second_dealt)
	_set_execution_fighter(previous_scope)
	var impact := (first.pos + second.pos) * 0.5
	spawn_ring(impact, Color.WHITE, 8.0, 74.0, 0.3)
	spawn_particles(impact, Color("fff0a0"), 10, 150.0)
	camera_shake = maxf(camera_shake, 5.0)

func _fighter_pair_key(first: FighterState, second: FighterState) -> String:
	return "%d:%d" % [mini(first.fighter_uid, second.fighter_uid), maxi(first.fighter_uid, second.fighter_uid)]

func _tick_contact_timers(delta: float) -> void:
	for key in _contact_timers.keys():
		var remaining := maxf(0.0, float(_contact_timers[key]) - delta)
		if remaining <= 0.0: _contact_timers.erase(key)
		else: _contact_timers[key] = remaining

func _resolve_fighter_entity_collisions() -> void:
	for entity: BallEntity in entities.duplicate():
		if entity.removed or entity.is_captured() or not entity.participates_in_fighter_collision() or entity.owner_side < 0: continue
		for fighter in fighters.duplicate():
			if fighter.hp > 0.0 and fighter.team_id != entity.owner_side:
				_resolve_fighter_entity_collision(fighter, _ability_for_fighter(fighter), fighter.team_id, entity)

func _resolve_fighter_entity_collision(fighter: FighterState, ability: BallAbility, fighter_side: int, entity: BallEntity) -> void:
	var offset: Vector2 = entity.pos - fighter.pos
	var minimum_distance := fighter.radius + entity.radius
	var distance := offset.length()
	if distance >= minimum_distance: return
	var normal := offset / distance if distance > 0.001 else fighter.velocity.normalized()
	if normal.length_squared() <= 0.001: normal = Vector2.RIGHT if fighter.fighter_uid % 2 != 0 else Vector2.LEFT
	var overlap := minimum_distance - maxf(distance, 0.001)
	var entity_inverse_mass := maxf(0.0, entity.fighter_collision_inverse_mass())
	var total_inverse_mass := 1.0 + entity_inverse_mass
	fighter.pos -= normal * overlap / total_inverse_mass
	entity.pos += normal * overlap * entity_inverse_mass / total_inverse_mass
	_clamp_fighter_to_arena(fighter)
	var entity_collision_velocity := entity.velocity if entity_inverse_mass > 0.0 else Vector2.ZERO
	var relative_speed := (entity_collision_velocity - fighter.velocity).dot(normal)
	if relative_speed < 0.0:
		var impulse := -2.0 * relative_speed / total_inverse_mass
		fighter.velocity -= normal * impulse
		entity.velocity += normal * impulse * entity_inverse_mass
	entity.combat_contact_source = _fighter_combat_identity(fighter)
	if ability == null or not entity.can_resolve_fighter_contact(fighter_side): return
	var fighter_damage := maxf(0.0, entity.entity_contact_damage())
	var previous_scope := _set_execution_fighter(fighter)
	var entity_damage := maxf(0.0, ability.contact_damage(battle_context, fighter, entity))
	var contact_color := entity.entity_contact_color()
	entity.begin_fighter_contact(fighter_side)
	var damage_to_entity := damage_entity(entity, entity_damage, fighter.accent, fighter_side) if entity_damage > 0.0 else 0.0
	var entity_source := fighter_for_uid(entity.owner_fighter_uid)
	if entity_source == null: entity_source = fighter_for_side(entity.owner_side)
	if fighter_damage > 0.0: damage(fighter, fighter_damage, contact_color, entity_source, true, entity)
	ability.after_entity_contact(battle_context, fighter, entity, damage_to_entity)
	_set_execution_fighter(previous_scope)
	stats["fighter_entity_contact_hits"] = int(stats["fighter_entity_contact_hits"]) + 1
	var impact_position := fighter.pos + normal * fighter.radius
	emit_combat_event("body_impact", clampf(maxf(0.0, -relative_speed) / 360.0, 0.3, 0.9))
	spawn_ring(impact_position, contact_color, 5.0, 44.0, 0.24)
	spawn_particles(impact_position, contact_color, 6, 108.0)
	camera_shake = maxf(camera_shake, 3.5)

func _update_ability(fighter: FighterState, opponent: FighterState, ability: BallAbility, side: int, delta: float) -> void:
	var previous_scope := _set_execution_fighter(fighter)
	ability.on_step(battle_context, fighter, opponent, side, delta)
	if ability.automatic_activation_enabled() and fighter.ability_timer <= 0.0:
		ability.activate(battle_context, fighter, opponent, side)
		fighter.ability_timer = ability.cooldown_duration(battle_context, fighter)
		_record_ability(fighter.id)
	_set_execution_fighter(previous_scope)

func damage(target: FighterState, amount: float, color: Color, source: FighterState, show_text: bool = true, source_unit = null) -> float:
	if target == null or target.hp <= 0.0: return 0.0
	for effect in target.status_effects:
		if effect.blocks_damage(battle_context, target, amount, source):
			effect.on_damage_blocked(battle_context, target, source, show_text)
			return 0.0
	var applied := minf(target.hp, _modified_incoming_damage(target, amount, source) * damage_scale)
	target.hp = maxf(0.0, target.hp - applied)
	target.hit_flash = 1.0
	_record_damage_stats(target.team_id, source.team_id if source != null else -1, applied)
	combat_ledger.record_damage(
		_combat_source_identity(source, source.team_id if source != null else -1, source_unit),
		_fighter_combat_identity(target), applied
	)
	if show_text and applied > 0.0:
		spawn_text(
			"-%d" % int(ceil(applied)),
			target.pos + Vector2(0.0, -target.radius - 6.0),
			color,
			damage_number_duration_seconds,
			"damage"
		)
	if source != null and applied > 0.0:
		_notify_damage_dealt(source, target, applied)
	if target.hp <= 0.0 and not _pending_death_uids.has(target.fighter_uid):
		_pending_death_uids[target.fighter_uid] = true
		_pending_deaths.append(target)
		_spawn_fighter_death(target)
	return applied

func _modified_incoming_damage(target, amount: float, source) -> float:
	var adjusted := maxf(0.0, amount)
	for effect: BallStatusEffect in target.status_effects:
		if not effect.is_expired():
			adjusted = maxf(0.0, effect.modify_incoming_damage(battle_context, target, adjusted, source))
	return adjusted

func _record_damage_stats(target_team: int, source_team: int, amount: float) -> void:
	var damage_to_team: Dictionary = stats["damage_to_team"]
	damage_to_team[target_team] = float(damage_to_team.get(target_team, 0.0)) + amount
	stats["damage_to_team"] = damage_to_team
	if source_team >= 0:
		var damage_by_team: Dictionary = stats["damage_by_team"]
		damage_by_team[source_team] = float(damage_by_team.get(source_team, 0.0)) + amount
		stats["damage_by_team"] = damage_by_team
	if not teams.is_empty() and target_team == teams[0].team_id: stats["damage_to_left"] = float(stats["damage_to_left"]) + amount
	elif teams.size() > 1 and target_team == teams[1].team_id: stats["damage_to_right"] = float(stats["damage_to_right"]) + amount

func _spawn_fighter_death(fighter: FighterState) -> void:
	var effect: BallEntity = FighterDeathEffectEntityScript.new(fighter.team_id, fighter.pos, fighter.radius, fighter.color, fighter.accent, death_effect_duration)
	effect.owner_fighter_uid = -2
	add_entity(effect)
	emit_combat_event("fighter_death", 1.0)
	camera_shake = maxf(camera_shake, 10.0)
	record_stat("fighter_deaths")

func _process_pending_deaths() -> void:
	if _pending_deaths.is_empty(): return
	_pending_deaths.sort_custom(func(first: FighterState, second: FighterState): return first.fighter_uid < second.fighter_uid)
	var queued_replacement := false
	for dead_fighter in _pending_deaths:
		if not fighters.has(dead_fighter): continue
		var team := team_for_id(dead_fighter.team_id)
		team.active_fighters.erase(dead_fighter)
		team.last_fighter = dead_fighter
		fighters.erase(dead_fighter)
		dead_fighter.status_effects.clear()
		for entity in entities:
			if entity.owner_fighter_uid == dead_fighter.fighter_uid: entity.removed = true
		team_events.append({
			"kind": "fighter_defeated",
			"elapsed": elapsed,
			"team_id": team.team_id,
			"team_name": team.display_name,
			"fighter_uid": dead_fighter.fighter_uid,
			"roster_index": dead_fighter.roster_index,
			"ball_id": dead_fighter.id,
			"display_name": dead_fighter.display_name,
		})
		var reserved_count := _pending_replacement_count(team.team_id)
		if team.active_fighters.size() + reserved_count < team.active_limit \
				and team.queued_count() > reserved_count:
			var next_roster_index := team.next_roster_index + reserved_count
			var next_ball_id := team.roster[next_roster_index]
			var next_module: BallModule = BallRegistry.get_module(next_ball_id)
			var replacement_request := {
				"team_id": team.team_id,
				"team_name": team.display_name,
				"replaced_fighter_uid": dead_fighter.fighter_uid,
				"defeated_roster_index": dead_fighter.roster_index,
				"defeated_ball_id": dead_fighter.id,
				"defeated_display_name": dead_fighter.display_name,
				"next_roster_index": next_roster_index,
				"next_ball_id": next_ball_id,
				"next_display_name": next_module.display_name,
				"position": dead_fighter.pos,
			}
			_pending_replacements.append(replacement_request)
			queued_replacement = true
			var queued_event := replacement_request.duplicate(true)
			queued_event["kind"] = "fighter_replacement_queued"
			queued_event["elapsed"] = elapsed
			team_events.append(queued_event)
	_pending_deaths.clear()
	_pending_death_uids.clear()
	_remove_finished_entities()
	if queued_replacement:
		_replacement_pause_remaining = maxf(
			_replacement_pause_remaining,
			maxf(death_effect_duration, handoff_pause_duration_seconds)
		)
	_mark_eliminated_teams()

func _pending_replacement_count(team_id: int) -> int:
	var count := 0
	for request in _pending_replacements:
		if int(request.get("team_id", -1)) == team_id:
			count += 1
	return count

func pending_replacement_notices() -> Array[Dictionary]:
	return _pending_replacements.duplicate(true)

func replacement_pause_remaining() -> float:
	return _replacement_pause_remaining

func request_world_stop(duration: float, source: FighterState) -> bool:
	var requested_duration := maxf(0.0, duration)
	if finished or source == null or source.hp <= 0.0 or requested_duration <= 0.0:
		return false
	if (
		requested_duration > _world_stop_remaining + 0.0001
		or (
			is_equal_approx(requested_duration, _world_stop_remaining)
			and (
				_world_stop_source_fighter_uid < 0
				or source.fighter_uid < _world_stop_source_fighter_uid
			)
		)
	):
		_world_stop_source_fighter_uid = source.fighter_uid
	_world_stop_remaining = maxf(_world_stop_remaining, requested_duration)
	return true

func world_stop_remaining() -> float:
	return _world_stop_remaining

func world_stop_source_fighter_uid() -> int:
	return _world_stop_source_fighter_uid

func _advance_world_stop(delta: float) -> void:
	var stop_step := minf(delta, _world_stop_remaining)
	var source := fighter_for_uid(_world_stop_source_fighter_uid)
	if source != null and source.hp > 0.0:
		var source_ability := _ability_for_fighter(source)
		if source_ability != null:
			var opponent := nearest_hostile_fighter(source)
			var previous_scope := _set_execution_fighter(source)
			source_ability.on_world_stop_step(
				battle_context,
				source,
				opponent,
				source.team_id,
				stop_step
			)
			_set_execution_fighter(previous_scope)
	_world_stop_remaining = maxf(0.0, _world_stop_remaining - stop_step)
	camera_shake = maxf(0.0, camera_shake - stop_step * 16.0)
	if _world_stop_remaining <= 0.0:
		_world_stop_source_fighter_uid = -1

func _advance_pending_replacements(delta: float) -> void:
	_replacement_pause_remaining = maxf(0.0, _replacement_pause_remaining - delta)
	if _replacement_pause_remaining > 0.0:
		return
	var requests: Array[Dictionary] = _pending_replacements.duplicate(true)
	_pending_replacements.clear()
	var replacements: Array[FighterState] = []
	for request in requests:
		var team := team_for_id(int(request.get("team_id", -1)))
		if team == null or team.active_fighters.size() >= team.active_limit or team.queued_count() <= 0:
			continue
		var replacement := _spawn_next_fighter(team, request.get("position", Vector2.ZERO) as Vector2)
		if replacement == null:
			continue
		replacements.append(replacement)
		stats["fighter_replacements"] = int(stats["fighter_replacements"]) + 1
		team_events.append({"kind": "fighter_replaced", "elapsed": elapsed, "team_id": team.team_id, "replaced_fighter_uid": int(request.get("replaced_fighter_uid", -1)), "fighter_uid": replacement.fighter_uid, "ball_id": replacement.id, "position": replacement.pos})
		emit_combat_event("fighter_replaced", 0.84)
	_mark_eliminated_teams()
	for fighter in replacements:
		_start_fighter_ability(fighter)
	_check_finish()

func _mark_eliminated_teams() -> void:
	for team in teams:
		if team.active_fighters.is_empty() and team.queued_count() == 0 \
				and _pending_replacement_count(team.team_id) == 0 and not team.eliminated:
			team.eliminated = true
			stats["team_eliminations"] = int(stats["team_eliminations"]) + 1
			team_events.append({"kind": "team_eliminated", "elapsed": elapsed, "team_id": team.team_id})

func damage_entity(target: BallEntity, amount: float, color: Color, source_side: int, show_text: bool = true, source_unit = null) -> float:
	if target == null or not target.can_receive_attack(source_side): return 0.0
	var source := _execution_fighter if _execution_fighter != null and _execution_fighter.team_id == source_side else fighter_for_side(source_side)
	for effect: BallStatusEffect in target.status_effects:
		if effect.blocks_damage(battle_context, target, amount, source):
			effect.on_damage_blocked(battle_context, target, source, show_text)
			return 0.0
	var source_identity := _combat_source_identity(source, source_side, source_unit)
	var target_identity := target.combat_identity()
	var applied := target.receive_attack(battle_context, _modified_incoming_damage(target, amount, source) * damage_scale, source_side, color)
	if applied <= 0.0: return 0.0
	combat_ledger.record_damage(source_identity, target_identity, applied)
	if show_text:
		spawn_text(
			"-%d" % int(ceil(applied)),
			target.pos + Vector2(0.0, -target.radius - 6.0),
			color,
			damage_number_duration_seconds,
			"damage"
		)
	_notify_damage_dealt(source, null, applied)
	return applied

func record_entity_health_loss(target: BallEntity, applied: float) -> void:
	combat_ledger.record_damage({}, target.combat_identity(), applied)

func _notify_damage_dealt(source: FighterState, target, applied: float) -> void:
	var ability := _ability_for_fighter(source)
	if ability == null:
		return
	var previous_scope := _set_execution_fighter(source)
	var previous_entity := _combat_execution_entity
	var previous_status := _combat_status_source
	_combat_execution_entity = null
	_combat_status_source = {}
	ability.after_damage_dealt(battle_context, source, target, applied)
	_combat_execution_entity = previous_entity
	_combat_status_source = previous_status
	_set_execution_fighter(previous_scope)

func contact_damage_for_side(source_side: int, target) -> float:
	var source := _execution_fighter if _execution_fighter != null and _execution_fighter.team_id == source_side else fighter_for_side(source_side)
	var ability := _ability_for_fighter(source)
	return 0.0 if ability == null else maxf(0.0, ability.contact_damage(battle_context, source, target))

func heal(fighter: FighterState, amount: float, allow_overheal: bool = false) -> float:
	if fighter == null or fighter.hp <= 0.0: return 0.0
	var scaled_amount := maxf(0.0, amount) * recovery_scale
	var applied := scaled_amount if allow_overheal else minf(scaled_amount, fighter.max_hp - fighter.hp)
	if applied <= 0.0: return 0.0
	fighter.hp += applied
	stats["healing"] = float(stats["healing"]) + applied
	combat_ledger.record_healing(
		_combat_source_identity(_execution_fighter, _execution_fighter.team_id if _execution_fighter != null else -1),
		_fighter_combat_identity(fighter), applied
	)
	spawn_text("+%d" % int(ceil(applied)), fighter.pos + Vector2(0.0, -fighter.radius - 10.0), Color("60ff87"), 0.65, "healing")
	return applied

func module_for_fighter(fighter: FighterState) -> BallModule:
	return _module_by_uid.get(fighter.fighter_uid) if fighter != null else null

func ability_for_fighter(fighter: FighterState) -> BallAbility:
	return _ability_for_fighter(fighter)

func _ability_for_fighter(fighter: FighterState) -> BallAbility:
	return _ability_by_uid.get(fighter.fighter_uid) if fighter != null else null

func _update_status_effects(target, delta: float) -> void:
	for index in range(target.status_effects.size() - 1, -1, -1):
		var effect: BallStatusEffect = target.status_effects[index]
		var previous_source := _combat_status_source
		_combat_status_source = effect.combat_source
		effect.tick(battle_context, target, delta)
		_combat_status_source = previous_source
		if effect.is_expired(): target.status_effects.remove_at(index)

func _notify_status_wall_hit(fighter: FighterState) -> void:
	for effect: BallStatusEffect in fighter.status_effects.duplicate():
		var previous_source := _combat_status_source
		_combat_status_source = effect.combat_source
		effect.on_wall_hit(battle_context, fighter)
		_combat_status_source = previous_source

func _preserves_external_velocity(fighter: FighterState) -> bool:
	for effect in fighter.status_effects:
		if effect.preserves_external_velocity(): return true
	return false

func movement_control_priority(fighter: FighterState) -> int:
	var highest_priority := BallStatusEffect.MOVEMENT_CONTROL_PRIORITY_NONE
	for effect in fighter.status_effects:
		if not effect.is_expired(): highest_priority = maxi(highest_priority, effect.movement_control_priority())
	return highest_priority

func _update_trails(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0: return
	_trail_timer = trail_interval
	for fighter in fighters:
		if fighter.hp > 0.0: fighter.append_trail()

func _update_transient_visuals(delta: float) -> void:
	for index in range(impact_rings.size() - 1, -1, -1):
		var ring := impact_rings[index]
		ring["ttl"] = float(ring["ttl"]) - delta
		ring["radius"] = lerpf(float(ring["start_radius"]), float(ring["end_radius"]), 1.0 - float(ring["ttl"]) / float(ring["duration"]))
		if float(ring["ttl"]) <= 0.0: impact_rings.remove_at(index)
		else: impact_rings[index] = ring
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		particle["ttl"] = float(particle["ttl"]) - delta
		particle["pos"] = Vector2(particle["pos"]) + Vector2(particle["velocity"]) * delta
		particle["velocity"] = Vector2(particle["velocity"]) * pow(0.05, delta)
		if float(particle["ttl"]) <= 0.0: particles.remove_at(index)
		else: particles[index] = particle
	for index in range(floating_texts.size() - 1, -1, -1):
		var item := floating_texts[index]
		item["ttl"] = float(item["ttl"]) - delta
		item["pos"] = Vector2(item["pos"]) + Vector2(0.0, -28.0) * delta
		if float(item["ttl"]) <= 0.0: floating_texts.remove_at(index)
		else: floating_texts[index] = item
	_update_ttl_array(beams, delta)

func _update_ttl_array(items: Array[Dictionary], delta: float) -> void:
	for index in range(items.size() - 1, -1, -1):
		items[index]["ttl"] = float(items[index]["ttl"]) - delta
		if float(items[index]["ttl"]) <= 0.0: items.remove_at(index)

func _update_entity_lifetimes(delta: float) -> void:
	for entity in entities: entity.process_lifetime(delta)
	_remove_finished_entities()

func _update_entities(delta: float) -> void:
	for entity in entities.duplicate():
		if entity.removed: continue
		if not entity.is_captured():
			_update_status_effects(entity, delta)
		if entity.removed: continue
		var previous_scope := _set_execution_fighter(fighter_for_uid(entity.owner_fighter_uid))
		var previous_entity := _combat_execution_entity
		_combat_execution_entity = entity
		entity.process_step(battle_context, delta)
		if not entity.combat_category().is_empty():
			combat_ledger.ensure_actor(entity.combat_identity())
		_set_execution_fighter(previous_scope)
		_combat_execution_entity = previous_entity
	_remove_finished_entities()

func _remove_finished_entities() -> void:
	for index in range(entities.size() - 1, -1, -1):
		if entities[index].removed:
			entities.remove_at(index)

func spawn_ring(position: Vector2, color: Color, start_radius: float, end_radius: float, duration: float) -> void:
	if duration <= 0.0:
		return
	if impact_rings.size() >= MAX_IMPACT_RINGS:
		impact_rings.pop_front()
	impact_rings.append({"pos": position, "color": color, "start_radius": start_radius, "end_radius": end_radius, "radius": start_radius, "duration": duration, "ttl": duration})

func spawn_particles(position: Vector2, color: Color, count: int, speed: float) -> void:
	var visual_count := mini(ceili(float(maxi(0, count)) * 1.6), MAX_VISUAL_PARTICLES)
	var overflow := maxi(0, particles.size() + visual_count - MAX_VISUAL_PARTICLES)
	if overflow > 0:
		particles = particles.slice(overflow)
	for _index in range(visual_count):
		var direction := Vector2.from_angle(visual_rng.randf_range(0.0, TAU))
		var duration := visual_rng.randf_range(0.25, 0.62)
		particles.append({"pos": position, "velocity": direction * visual_rng.randf_range(speed * 0.35, speed), "color": color, "size": visual_rng.randf_range(2.0, 5.0), "duration": duration, "ttl": duration})

func spawn_text(text: String, position: Vector2, color: Color, duration: float, kind: String = "generic") -> void:
	floating_texts.append({
		"text": text,
		"pos": position,
		"color": color,
		"duration": duration,
		"ttl": duration,
		"kind": kind,
	})

func add_beam(from: Vector2, to: Vector2, color: Color, duration: float, width: float) -> void:
	beams.append({"from": from, "to": to, "color": color, "ttl": duration, "duration": duration, "width": width})

func add_projectile(owner_side: int, position: Vector2, velocity: Vector2, radius: float, projectile_damage: float, color: Color, duration: float, type: String, source_unit: BallEntity = null) -> void:
	var projectile := BallProjectileEntity.new(owner_side, position, velocity, radius, projectile_damage, color, duration, type)
	if source_unit != null:
		projectile.owner_fighter_uid = source_unit.owner_fighter_uid
		projectile.combat_source = source_unit.combat_identity()
	add_entity(projectile)
	record_stat("projectiles_spawned")

func add_entity(entity: BallEntity) -> BallEntity:
	assert(entity != null, "Cannot add a null battle entity")
	if entity.owner_fighter_uid == -1 and _execution_fighter != null and entity.owner_side == _execution_fighter.team_id:
		entity.owner_fighter_uid = _execution_fighter.fighter_uid
	if entity.combat_origin_fighter_uid < 0:
		entity.combat_origin_fighter_uid = entity.owner_fighter_uid
	if entity.combat_source.is_empty():
		entity.combat_source = _combat_source_identity(fighter_for_uid(entity.owner_fighter_uid), entity.owner_side)
	if not entity.combat_category().is_empty():
		combat_ledger.ensure_actor(entity.combat_identity())
	entities.append(entity)
	return entity

func entity_list(owner_side: int = -1, tag: String = "") -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for entity in entities:
		if entity.removed or entity.is_captured(): continue
		if owner_side >= 0 and entity.owner_side != owner_side: continue
		if not tag.is_empty() and not entity.has_tag(tag): continue
		result.append(entity)
	return result

func count_entities(owner_side: int, tag: String) -> int:
	return entity_list(owner_side, tag).size()

func apply_status(target, effect: BallStatusEffect) -> BallStatusEffect:
	assert(target != null, "Status effects require a target")
	assert(effect != null and not effect.key.is_empty(), "Status effects require a stable key")
	if effect.source_fighter_uid < 0 and _execution_fighter != null and effect.source_side == _execution_fighter.team_id:
		effect.source_fighter_uid = _execution_fighter.fighter_uid
	if effect.combat_source.is_empty():
		effect.combat_source = _combat_source_identity(_historical_fighter(effect.source_fighter_uid), effect.source_side)
	for existing: BallStatusEffect in target.status_effects:
		if existing.key == effect.key:
			existing.refresh_from(effect)
			return existing
	target.status_effects.append(effect)
	return effect

func has_status(target, key_prefix: String) -> bool:
	if target == null:
		return false
	for effect: BallStatusEffect in target.status_effects:
		if effect.key.begins_with(key_prefix) and not effect.is_expired(): return true
	return false

func remove_status(target, exact_key: String) -> bool:
	if target == null:
		return false
	for index in range(target.status_effects.size() - 1, -1, -1):
		if target.status_effects[index].key == exact_key:
			target.status_effects.remove_at(index)
			return true
	return false

func arena_size() -> Vector2:
	return _arena_size

func active_fighters() -> Array[FighterState]:
	return fighters.duplicate()

func fighters_for_team(team_id: int) -> Array[FighterState]:
	var result: Array[FighterState] = []
	for fighter in fighters:
		if fighter.team_id == team_id and fighter.hp > 0.0: result.append(fighter)
	return result

func hostile_fighters(side: int) -> Array[FighterState]:
	var result: Array[FighterState] = []
	for fighter in fighters:
		if fighter.team_id != side and fighter.hp > 0.0: result.append(fighter)
	return result

func fighter_for_uid(uid: int) -> FighterState:
	if uid < 0: return null
	for fighter in fighters:
		if fighter.fighter_uid == uid: return fighter
	return null

func fighter_for_side(side: int) -> FighterState:
	if _execution_fighter != null and _execution_fighter.team_id == side and _execution_fighter.hp > 0.0: return _execution_fighter
	var team := team_for_id(side)
	if team == null: return null
	for fighter in team.active_fighters:
		if fighter.hp > 0.0: return fighter
	return team.last_fighter

func opponent_for_side(side: int) -> FighterState:
	var source := fighter_for_side(side)
	if source != null:
		var nearest := nearest_hostile_fighter(source)
		if nearest != null: return nearest
	for fighter in fighter_history:
		if fighter.team_id != side: return fighter
	return null

func nearest_hostile_fighter(source: FighterState) -> FighterState:
	if source == null: return null
	var nearest: FighterState = null
	var nearest_distance := INF
	for candidate in fighters:
		if candidate.hp <= 0.0 or candidate.team_id == source.team_id: continue
		var distance := source.pos.distance_squared_to(candidate.pos)
		if distance < nearest_distance - 0.0001 or (is_equal_approx(distance, nearest_distance) and (nearest == null or candidate.fighter_uid < nearest.fighter_uid)):
			nearest = candidate
			nearest_distance = distance
	return nearest

func side_for_fighter(fighter: FighterState) -> int:
	return fighter.team_id if fighter != null else -1

func team_for_id(team_id: int) -> TeamState:
	for team in teams:
		if team.team_id == team_id: return team
	return null

func _set_execution_fighter(fighter: FighterState) -> FighterState:
	var previous := _execution_fighter
	_execution_fighter = fighter
	return previous

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
	if direction.x > 0.001: distances.append((_arena_size.x - origin.x) / direction.x)
	elif direction.x < -0.001: distances.append((0.0 - origin.x) / direction.x)
	if direction.y > 0.001: distances.append((_arena_size.y - origin.y) / direction.y)
	elif direction.y < -0.001: distances.append((0.0 - origin.y) / direction.y)
	var minimum := INF
	for value in distances:
		if value > 0.0: minimum = minf(minimum, value)
	return origin if is_inf(minimum) else origin + direction * minimum

func _check_finish() -> void:
	_process_pending_deaths()
	if not _pending_replacements.is_empty():
		return
	var surviving_teams: Array[TeamState] = []
	for team in teams:
		if not team.eliminated: surviving_teams.append(team)
	if surviving_teams.is_empty():
		_set_draw("同归于尽")
	elif surviving_teams.size() == 1:
		_set_winner(surviving_teams[0].team_id, "击败")
	elif elapsed >= max_battle_time:
		var timeout_winner := teams[0]
		var best_ratio := -1.0
		for team in teams:
			var ratio := team_remaining_hp_ratio(team)
			if ratio > best_ratio + 0.0001 or (is_equal_approx(ratio, best_ratio) and team.team_id < timeout_winner.team_id):
				timeout_winner = team
				best_ratio = ratio
		_set_winner(timeout_winner.team_id, "时限判定")

func team_remaining_hp_ratio(team: TeamState) -> float:
	return clampf(team_remaining_hp(team) / maxf(1.0, team_total_max_hp(team)), 0.0, 1.0)

func team_remaining_hp(team: TeamState) -> float:
	var remaining_hp := 0.0
	for roster_index in range(team.roster.size()):
		var maximum := team.roster_max_hp[roster_index]
		if roster_index >= team.next_roster_index: remaining_hp += maximum
	for fighter in team.active_fighters: remaining_hp += maxf(0.0, fighter.hp)
	return remaining_hp

func team_total_max_hp(team: TeamState) -> float:
	return team.total_max_hp

func _set_winner(team_id: int, reason: String) -> void:
	if finished: return
	finished = true
	winner_team_id = team_id
	var winner_team := team_for_id(team_id)
	var winner_fighter := fighter_for_side(team_id)
	winner_id = winner_fighter.id if winner_fighter != null else ""
	if teams.size() > 0 and team_id == teams[0].team_id: winner_side = "left"
	elif teams.size() > 1 and team_id == teams[1].team_id: winner_side = "right"
	else: winner_side = str(team_id)
	finish_reason = reason
	team_events.append({"kind": "battle_finished", "elapsed": elapsed, "result": "win", "winner_team_id": team_id, "winner_name": winner_team.display_name if winner_team != null else "", "reason": reason})
	if winner_fighter != null: spawn_ring(winner_fighter.pos, Color("ffe35c"), winner_fighter.radius, 260.0, 1.2)

func _set_draw(reason: String) -> void:
	if finished: return
	finished = true
	winner_team_id = -1
	winner_id = ""
	winner_side = ""
	finish_reason = reason
	team_events.append({
		"kind": "battle_finished",
		"elapsed": elapsed,
		"result": "draw",
		"winner_team_id": -1,
		"winner_name": "",
		"reason": reason,
	})

func is_draw() -> bool:
	return finished and winner_team_id < 0

func winner() -> FighterState:
	return fighter_for_side(winner_team_id)

func snapshot() -> Dictionary:
	var fighter_snapshots: Array[Dictionary] = []
	for fighter in fighters:
		fighter_snapshots.append({"fighter_uid": fighter.fighter_uid, "team_id": fighter.team_id, "roster_index": fighter.roster_index, "ball_id": fighter.id, "hp": fighter.hp, "max_hp": fighter.max_hp, "pos": fighter.pos, "velocity": fighter.velocity})
	var team_snapshots: Array[Dictionary] = []
	for team in teams:
		team_snapshots.append({"team_id": team.team_id, "name": team.display_name, "active_limit": team.active_limit, "next_roster_index": team.next_roster_index, "queued_count": team.queued_count(), "eliminated": team.eliminated, "remaining_hp_ratio": team_remaining_hp_ratio(team)})
	var result := {
		"elapsed": elapsed, "arena_size": _arena_size, "setup": battle_setup.snapshot(),
		"pending_replacements": _pending_replacements.duplicate(true),
		"replacement_pause_remaining": _replacement_pause_remaining,
		"world_stop_remaining": _world_stop_remaining,
		"world_stop_source_fighter_uid": _world_stop_source_fighter_uid,
		"handoff_pause_duration_seconds": handoff_pause_duration_seconds,
		"finished": finished, "is_draw": is_draw(), "winner_id": winner_id, "winner_side": winner_side,
		"winner_team_id": winner_team_id, "fighters": fighter_snapshots, "teams": team_snapshots,
		"team_events": team_events.duplicate(true),
		"left_clones": count_entities(teams[0].team_id, "clone") if not teams.is_empty() else 0,
		"right_clones": count_entities(teams[1].team_id, "clone") if teams.size() > 1 else 0,
		"projectiles": entity_list(-1, "projectile").size(), "stats": stats.duplicate(true),
		"combat_report": combat_report(),
	}
	return result

func _historical_fighter(uid: int) -> FighterState:
	for fighter in fighter_history:
		if fighter.fighter_uid == uid:
			return fighter
	return null

func _fighter_combat_identity(fighter: FighterState) -> Dictionary:
	if fighter == null:
		return {}
	return {"fighter_uid": fighter.fighter_uid, "team_id": fighter.team_id,
		"category_id": "body", "category_name": "本体与技能", "origin_fighter_uid": fighter.fighter_uid}

func _combat_source_identity(source: FighterState, source_side: int, source_unit = null) -> Dictionary:
	if source_unit is Dictionary:
		return source_unit.duplicate(true)
	if source_unit is BallEntity:
		return source_unit.combat_identity()
	if source_unit is FighterState:
		return _fighter_combat_identity(source_unit)
	if not _combat_status_source.is_empty() \
			and (source_side < 0 or int(_combat_status_source.get("team_id", -1)) == source_side):
		return _combat_status_source.duplicate(true)
	if _combat_execution_entity != null \
			and (source_side < 0 or _combat_execution_entity.owner_side == source_side):
		return _combat_execution_entity.combat_identity()
	return _fighter_combat_identity(source)

func combat_report() -> Dictionary:
	var participants: Array[Dictionary] = []
	for team in teams:
		for roster_index in range(team.roster.size()):
			var participant: FighterState = null
			for fighter in fighter_history:
				if fighter.team_id == team.team_id and fighter.roster_index == roster_index:
					participant = fighter
					break
			var uid := participant.fighter_uid if participant != null else -1
			var rows: Array[Dictionary] = combat_ledger.rows_for(uid)
			for row in rows:
				var origin := _historical_fighter(int(row["origin_fighter_uid"]))
				row["controlled"] = origin != null and origin.fighter_uid != uid
				row["origin_name"] = "%s·%s(%d号)" % [team_for_id(origin.team_id).display_name, origin.display_name, origin.roster_index + 1] if origin != null else ""
			participants.append({"fighter_uid": uid, "team_id": team.team_id, "team_name": team.display_name,
				"team_color": team.color.to_html(), "roster_index": roster_index,
				"ball_id": String(team.roster[roster_index]),
				"name": participant.display_name if participant != null else BallRegistry.get_module(team.roster[roster_index]).display_name,
				"state": "未上场" if participant == null else ("落败" if participant.hp <= 0.0 else "存活"),
				"rows": rows, "totals": combat_ledger.totals_for(uid)})
	return {"version": 1, "fighters": participants}
