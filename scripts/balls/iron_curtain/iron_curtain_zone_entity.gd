extends BallEntity

const InvulnerabilityStatusEffectScript := preload("res://scripts/balls/core/invulnerability_status_effect.gd")
const INVULNERABILITY_KEY := "iron_curtain_invulnerability"
const PROTECTION_MODE := "protection"
const HAZARD_MODE := "hazard"

var _mode := PROTECTION_MODE
var _duration := 3.0
var _damage_interval := 0.5
var _damage := 1.0
var _invulnerability_duration := 3.0
var _damage_timer := 0.5
var _absorption_radius := 22.0
var _protected_target_ids := {}

func _init(spawn_owner_side: int, spawn_position: Vector2, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_mode = String(config.get("mode", PROTECTION_MODE))
	_duration = maxf(0.1, float(config.get("duration", 3.0)))
	remaining = _duration
	radius = maxf(1.0, float(config.get("radius", 112.0)))
	_damage_interval = maxf(0.01, float(config.get("damage_interval", 0.5)))
	_damage = maxf(0.0, float(config.get("damage", 1.0)))
	_invulnerability_duration = maxf(0.0, float(config.get("invulnerability_duration", 3.0)))
	_damage_timer = _damage_interval
	_absorption_radius = maxf(1.0, float(config.get("absorption_radius", 22.0)))
	tags = PackedStringArray(["iron_curtain_field", "iron_curtain_%s_field" % _mode])
	draw_layer = -36

func step(battle, delta: float) -> void:
	if _mode == PROTECTION_MODE:
		_protect_allies_in_range(battle)
	_damage_timer -= delta
	while _damage_timer <= 0.0 and not removed:
		_damage_timer += _damage_interval
		if _mode == PROTECTION_MODE:
			_damage_hostiles_in_range(battle)
		else:
			_damage_everyone_in_range(battle)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var draw_radius := radius * context.scale_factor
	var progress := clampf(1.0 - remaining / maxf(_duration, 0.001), 0.0, 1.0)
	var appear := clampf(progress / 0.08, 0.0, 1.0)
	var fade := clampf(remaining / minf(0.65, _duration), 0.0, 1.0)
	var alpha := appear * fade * (0.48 if not is_captured() else 0.22)
	var phase := context.elapsed * (2.8 if _mode == PROTECTION_MODE else -4.6) + pos.x * 0.013
	var outer_color := Color("ff3228") if _mode == PROTECTION_MODE else Color("b40f19")
	var inner_color := Color("ff8a68") if _mode == PROTECTION_MODE else Color("ff2b1f")
	canvas.draw_circle(center, draw_radius, Color(0.12, 0.005, 0.008, alpha * 0.72))
	canvas.draw_circle(center, draw_radius * 0.86, Color(outer_color.r, outer_color.g, outer_color.b, alpha * 0.18))
	canvas.draw_circle(center, draw_radius * 0.48, Color(inner_color.r, inner_color.g, inner_color.b, alpha * 0.12))
	for ring_index in range(4):
		var ring_radius := draw_radius * (0.28 + float(ring_index) * 0.2)
		var ring_angle := phase * (1.0 + float(ring_index) * 0.12) + float(ring_index) * 1.37
		canvas.draw_arc(
			center,
			ring_radius,
			ring_angle,
			ring_angle + PI * (1.22 if _mode == PROTECTION_MODE else 0.76),
			32,
			Color(inner_color.r, inner_color.g, inner_color.b, alpha * (0.9 - float(ring_index) * 0.12)),
			maxf(1.3, draw_radius * (0.025 - float(ring_index) * 0.003)),
			true
		)
	for ray_index in range(12):
		var angle := phase * 0.34 + TAU * float(ray_index) / 12.0
		var direction := Vector2.from_angle(angle)
		var inner := center + direction * draw_radius * (0.18 if _mode == PROTECTION_MODE else 0.08)
		var outer := center + direction * draw_radius * (0.78 + 0.08 * sin(phase + ray_index))
		canvas.draw_line(
			inner,
			outer,
			Color(outer_color.r, outer_color.g, outer_color.b, alpha * (0.18 if _mode == PROTECTION_MODE else 0.32)),
			maxf(0.8, draw_radius * 0.009),
			true
		)
	canvas.draw_arc(center, draw_radius, 0.0, TAU, 72, Color(inner_color.r, inner_color.g, inner_color.b, alpha), maxf(2.2, draw_radius * 0.028), true)

func field_mode() -> String:
	return _mode

func damage_value() -> float:
	return _damage

func damage_interval() -> float:
	return _damage_interval

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_radius() -> float:
	return minf(radius, _absorption_radius)

func absorption_visual_color() -> Color:
	return Color("ff3429")

func _protect_allies_in_range(battle) -> void:
	if _invulnerability_duration <= 0.0:
		return
	for fighter in battle.active_fighters():
		if fighter.team_id != owner_side or not _overlaps(fighter.pos, fighter.radius):
			continue
		var target_key := "fighter:%d" % fighter.fighter_uid
		if _protected_target_ids.has(target_key):
			continue
		_protected_target_ids[target_key] = true
		battle.apply_status(fighter, InvulnerabilityStatusEffectScript.new(
			_invulnerability_duration,
			owner_side,
			INVULNERABILITY_KEY
		))
		battle.record_stat("iron_curtain_allies_protected")
	for entity: BallEntity in battle.entities():
		if (
			entity == self
			or entity.owner_side != owner_side
			or not entity.can_receive_attack(-1)
			or not _overlaps(entity.pos, entity.radius)
		):
			continue
		var target_key := "entity:%d" % entity.get_instance_id()
		if _protected_target_ids.has(target_key):
			continue
		_protected_target_ids[target_key] = true
		battle.apply_status(entity, InvulnerabilityStatusEffectScript.new(
			_invulnerability_duration,
			owner_side,
			INVULNERABILITY_KEY
		))
		battle.record_stat("iron_curtain_allies_protected")

func _damage_hostiles_in_range(battle) -> void:
	var source = battle.owner_for_entity(self)
	for fighter in battle.hostile_fighters(owner_side):
		if _overlaps(fighter.pos, fighter.radius):
			battle.damage(fighter, _damage, Color("ff6657"), source)
			battle.record_stat("iron_curtain_hostile_ticks")
	for entity: BallEntity in battle.damageable_entities_in_circle(owner_side, pos, radius):
		if battle.damage_entity(entity, _damage, Color("ff6657"), owner_side) > 0.0:
			battle.record_stat("iron_curtain_hostile_ticks")

func _damage_everyone_in_range(battle) -> void:
	var source = battle.owner_for_entity(self)
	for fighter in battle.active_fighters():
		if _overlaps(fighter.pos, fighter.radius):
			if battle.damage(fighter, _damage, Color("ff392e"), source) > 0.0:
				battle.record_stat("iron_dragon_hazard_ticks")
	for entity: BallEntity in battle.entities():
		if entity == self or not entity.can_receive_attack(-1) or not _overlaps(entity.pos, entity.radius):
			continue
		if battle.damage_entity(entity, _damage, Color("ff392e"), -1) > 0.0:
			battle.record_stat("iron_dragon_hazard_ticks")

func _overlaps(target_position: Vector2, target_radius: float) -> bool:
	return pos.distance_squared_to(target_position) <= pow(radius + target_radius, 2.0)
