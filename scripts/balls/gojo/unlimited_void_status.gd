extends BallStatusEffect

const STALLED_SPEED := 0.04

var _source_ref: WeakRef
var _damage_per_tick := 2.0
var _tick_interval := 0.5
var _tick_remaining := 0.5
var _resume_velocity := Vector2.RIGHT
var _stall_direction := Vector2.RIGHT
var _color := Color("8e6dff")

func _init(
	source,
	duration: float,
	damage_per_tick: float,
	tick_interval: float,
	initial_velocity: Vector2
) -> void:
	key = "gojo_unlimited_void:%d" % int(source.fighter_uid)
	remaining = maxf(0.05, duration)
	source_side = int(source.team_id)
	source_fighter_uid = int(source.fighter_uid)
	_source_ref = weakref(source)
	_damage_per_tick = maxf(0.0, damage_per_tick)
	_tick_interval = maxf(0.05, tick_interval)
	_tick_remaining = _tick_interval
	_resume_velocity = initial_velocity
	if _resume_velocity.length_squared() > 0.0001:
		_stall_direction = _resume_velocity.normalized()

func tick(battle, target, delta: float) -> void:
	var active_delta := minf(maxf(0.0, delta), remaining)
	var expires_now := remaining <= delta + 0.0001
	_tick_remaining -= active_delta
	if not expires_now:
		target.velocity = _stall_direction * STALLED_SPEED
		if not target is BallEntity:
			target.ability_timer = maxf(float(target.ability_timer), remaining + 0.05)
	super(battle, target, delta)
	while _tick_remaining <= 0.0001 and _damage_per_tick > 0.0:
		_tick_remaining += _tick_interval
		var source = _source_ref.get_ref() if _source_ref != null else null
		if target is BallEntity:
			if target.removed:
				break
			battle.damage_entity(target, _damage_per_tick, _color, source_side)
		else:
			if target.hp <= 0.0:
				break
			battle.damage(target, _damage_per_tick, _color, source)
		battle.record_stat("gojo_unlimited_void_damage_ticks")
		if active_delta <= 0.0:
			break
	if expires_now:
		target.velocity = _resume_velocity

func preserves_external_velocity() -> bool:
	return true

func entity_step_multiplier() -> float:
	return 0.0

func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_FORCED

func draw_overlay(canvas: CanvasItem, _target, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	canvas.draw_circle(position, radius * 1.12, Color(0.18, 0.08, 0.38, 0.26))
	for index in range(6):
		var angle := elapsed * 0.45 + TAU * float(index) / 6.0
		var point := position + Vector2.from_angle(angle) * radius * (0.72 + 0.08 * sin(elapsed * 3.0 + index))
		canvas.draw_circle(point, maxf(1.5, radius * 0.055), Color(0.72, 0.86, 1.0, 0.82))
	canvas.draw_arc(position, radius * 1.1, elapsed, elapsed + PI * 1.35, 30, Color(0.58, 0.4, 1.0, 0.8), 2.0, true)
