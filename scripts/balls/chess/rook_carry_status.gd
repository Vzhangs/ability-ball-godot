extends BallStatusEffect

const STATUS_KEY := "chess_rook_carry"

var _direction := Vector2.RIGHT
var _speed := 0.0
var _wall_damage := 0.0
var _accent := Color("f6d89a")
var _duration := 0.0
var _age := 0.0
var _wall_impact_resolved := false

func _init(
	duration: float,
	effect_source_side: int,
	direction: Vector2,
	speed: float,
	wall_damage: float,
	accent: Color
) -> void:
	key = STATUS_KEY
	remaining = maxf(0.0, duration)
	source_side = effect_source_side
	_direction = direction.normalized()
	if _direction.length_squared() <= 0.0001:
		_direction = Vector2.RIGHT if source_side == 0 else Vector2.LEFT
	_speed = maxf(0.0, speed)
	_wall_damage = maxf(0.0, wall_damage)
	_accent = accent
	_duration = maxf(0.001, remaining)

func tick(battle, target, delta: float) -> void:
	super(battle, target, delta)
	_age += delta
	if not is_expired() and not _wall_impact_resolved:
		target.velocity = _direction * _speed

func preserves_external_velocity() -> bool:
	return true

func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_FORCED

func on_wall_hit(battle, target) -> void:
	resolve_wall_impact(battle, target)

func resolve_wall_impact(battle, target) -> float:
	if _wall_impact_resolved or target == null or target.hp <= 0.0:
		return 0.0
	_wall_impact_resolved = true
	remaining = 0.0
	var source = battle.fighter_for_side(source_side)
	var applied: float = battle.damage(target, _wall_damage, _accent, source)
	battle.spawn_ring(target.pos, Color.WHITE, target.radius * 0.35, target.radius * 3.2, 0.42)
	battle.spawn_ring(target.pos, _accent, target.radius * 0.8, target.radius * 2.5, 0.34)
	battle.spawn_particles(target.pos, _accent, 18, 235.0)
	battle.shake_camera(9.0)
	battle.emit_combat_event("ram_impact", 1.0)
	battle.record_stat("chess_rook_wall_hits")
	return applied

func wall_impact_resolved() -> bool:
	return _wall_impact_resolved

func draw_overlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var normal := _direction.orthogonal()
	var pulse := 0.82 + sin(_age * TAU * 7.0) * 0.12
	var front := position + _direction * radius * 0.98
	var back := position - _direction * radius * 0.72
	var half_width := radius * (1.08 + pulse * 0.08)
	var points := PackedVector2Array([
		back - normal * half_width,
		front - normal * half_width,
		front + normal * half_width,
		back + normal * half_width,
		back - normal * half_width,
	])
	canvas.draw_polyline(
		points,
		Color(_accent.r, _accent.g, _accent.b, 0.22),
		maxf(5.0, radius * 0.18),
		true
	)
	canvas.draw_polyline(
		points,
		Color(1.0, 0.93, 0.62, 0.84),
		maxf(1.6, radius * 0.065),
		true
	)
	for offset_scale in [-0.34, 0.34]:
		var center: Vector2 = position + normal * half_width * offset_scale + _direction * radius * 0.18
		canvas.draw_line(
			center - _direction * radius * 0.32,
			center + _direction * radius * 0.36,
			Color(1.0, 0.96, 0.74, 0.76),
			maxf(1.4, radius * 0.055),
			true
		)
