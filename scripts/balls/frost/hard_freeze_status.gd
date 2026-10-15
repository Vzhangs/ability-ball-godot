extends BallStatusEffect

const IceSlowStatusEffectScript := preload("res://scripts/balls/core/ice_slow_status_effect.gd")
const KEY := "frost_hard_freeze"
const STALLED_SPEED := 0.04
const VISUAL_PULSE_INTERVAL := 0.22
const MOVEMENT_PRIORITY := MOVEMENT_CONTROL_PRIORITY_FORCED + 5

var _damage_per_tick := 0.0
var _tick_interval := 1.0
var _tick_timer := 1.0
var _resume_velocity := Vector2.ZERO
var _stall_direction := Vector2.RIGHT
var _post_freeze_speed_multiplier := 1.0
var _color := Color("73e9ff")
var _age := 0.0
var _visual_timer := 0.0

func _init(
	duration: float,
	effect_source_side: int,
	spawn_damage_per_tick: float,
	damage_interval: float,
	initial_velocity: Vector2,
	spawn_post_freeze_speed_multiplier: float,
	spawn_effect_color: Color
) -> void:
	key = KEY
	remaining = maxf(0.0, duration)
	source_side = effect_source_side
	_damage_per_tick = maxf(0.0, spawn_damage_per_tick)
	_tick_interval = maxf(0.001, damage_interval)
	_tick_timer = _tick_interval
	_resume_velocity = initial_velocity
	if initial_velocity.length_squared() > 0.001:
		_stall_direction = initial_velocity.normalized()
	elif effect_source_side % 2 != 0:
		_stall_direction = Vector2.LEFT
	_post_freeze_speed_multiplier = clampf(spawn_post_freeze_speed_multiplier, 0.0, 1.0)
	_color = spawn_effect_color

func damage_per_tick() -> float:
	return _damage_per_tick

func tick_interval() -> float:
	return _tick_interval

func post_freeze_speed_multiplier() -> float:
	return _post_freeze_speed_multiplier

func effect_color() -> Color:
	return _color

func tick(battle, target, delta: float) -> void:
	var active_delta := minf(maxf(0.0, delta), remaining)
	var expires_now := remaining <= delta + 0.0001
	_age += active_delta
	_visual_timer -= active_delta
	if active_delta > 0.0 and _visual_timer <= 0.0:
		_visual_timer += VISUAL_PULSE_INTERVAL
		battle.spawn_particles(target.pos, _color, 2, 34.0)
	if not target is BallEntity \
			and not expires_now \
			and battle.movement_control_priority(target) <= MOVEMENT_PRIORITY:
		target.velocity = _stall_direction * STALLED_SPEED
	_tick_timer -= active_delta
	while active_delta > 0.0 and _tick_timer <= 0.0001:
		_tick_timer += _tick_interval
		if _apply_damage_tick(battle, target) <= 0.0 and float(target.get("hp")) <= 0.0:
			break
	super(battle, target, delta)
	if expires_now and not target is BallEntity \
			and battle.movement_control_priority(target) <= MOVEMENT_PRIORITY:
		_restore_velocity_with_active_slow(target)

func refresh_from(other: BallStatusEffect) -> void:
	super(other)
	_damage_per_tick = maxf(_damage_per_tick, float(other.call("damage_per_tick")))
	_tick_interval = minf(_tick_interval, float(other.call("tick_interval")))
	_tick_timer = minf(_tick_timer, _tick_interval)
	_post_freeze_speed_multiplier = minf(
		_post_freeze_speed_multiplier,
		float(other.call("post_freeze_speed_multiplier"))
	)
	_color = other.call("effect_color") as Color

func preserves_external_velocity() -> bool:
	return true

func entity_step_multiplier() -> float:
	return 0.0

func movement_control_priority() -> int:
	return MOVEMENT_PRIORITY

func draw_overlay(canvas: CanvasItem, _target, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var pulse := 0.96 + sin(_age * TAU * 2.0) * 0.035
	canvas.draw_circle(position, radius * 1.04, Color(0.28, 0.84, 1.0, 0.22))
	canvas.draw_arc(position, radius * 1.08 * pulse, 0.0, TAU, 40, Color(0.78, 0.98, 1.0, 0.88), maxf(2.0, radius * 0.08), true)
	for shard_index in range(8):
		var angle := TAU * float(shard_index) / 8.0 + (0.12 if shard_index % 2 == 0 else -0.08)
		var radial := Vector2.from_angle(angle)
		var tangent := radial.rotated(PI * 0.5)
		var base := position + radial * radius * 0.58
		var tip := position + radial * radius * (1.12 + float(shard_index % 3) * 0.08)
		var half_width := radius * (0.09 + float(shard_index % 2) * 0.025)
		canvas.draw_colored_polygon(PackedVector2Array([
			base - tangent * half_width,
			tip,
			base + tangent * half_width,
		]), Color(0.74, 0.96, 1.0, 0.58))
	for crack_index in range(5):
		var angle := -PI * 0.82 + float(crack_index) * PI * 0.41
		var direction := Vector2.from_angle(angle)
		var root := position + direction * radius * 0.18
		var elbow := position + direction * radius * 0.56 + direction.rotated(PI * 0.5) * radius * (0.08 if crack_index % 2 == 0 else -0.08)
		var tip := position + direction * radius * 0.92
		canvas.draw_polyline(PackedVector2Array([root, elbow, tip]), Color(0.9, 1.0, 1.0, 0.72), maxf(1.0, radius * 0.04), true)

func _apply_damage_tick(battle, target) -> float:
	var source = battle.fighter_for_uid(source_fighter_uid)
	if source == null:
		source = battle.fighter_for_side(source_side)
	var applied := 0.0
	if target is BallEntity:
		var entity := target as BallEntity
		if entity.removed:
			return 0.0
		applied = battle.damage_entity(entity, _damage_per_tick, _color, source_side)
	else:
		if target.hp <= 0.0:
			return 0.0
		applied = battle.damage(target, _damage_per_tick, _color, source)
	if applied > 0.0:
		battle.record_stat("frost_freeze_damage_ticks")
	return applied

func _restore_velocity_with_active_slow(target) -> void:
	var direction := _resume_velocity.normalized()
	if direction.length_squared() <= 0.001:
		direction = _stall_direction
	var speed := _resume_velocity.length()
	var slow_multiplier := _post_freeze_speed_multiplier
	for effect: BallStatusEffect in target.status_effects:
		if effect == self or effect.is_expired() or effect.key != IceSlowStatusEffectScript.KEY:
			continue
		slow_multiplier = minf(slow_multiplier, float(effect.call("slow_multiplier")))
		var baseline := float(effect.call("baseline_speed"))
		if baseline >= 0.0:
			speed = baseline
	if speed <= 0.001:
		speed = maxf(0.0, float(target.base_speed))
	target.velocity = direction * speed * slow_multiplier
