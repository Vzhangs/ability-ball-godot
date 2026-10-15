extends BallStatusEffect

const PRIORITY := MOVEMENT_CONTROL_PRIORITY_FORCED
const STALLED_SPEED := 0.04
var _resume := Vector2.ZERO
var _owns_motion := false
var _age := 0.0

func _init(duration: float, side: int) -> void:
	key = "qing_paralysis"
	remaining = duration
	source_side = side

func tick(battle, target, delta: float) -> void:
	_age += delta
	var expires := remaining <= delta + 0.000001
	if not target is BallEntity:
		if battle.movement_control_priority(target) > PRIORITY:
			_owns_motion = false
		elif not expires:
			if not _owns_motion:
				_resume = target.velocity
				_owns_motion = true
			var direction := _resume.normalized()
			if direction.length_squared() < 0.001: direction = Vector2.RIGHT
			target.velocity = direction * STALLED_SPEED
	super(battle, target, delta)
	if expires and _owns_motion and battle.movement_control_priority(target) <= PRIORITY:
		var restored := _resume
		for effect: BallStatusEffect in target.status_effects:
			if effect is IceSlowStatusEffect and not effect.is_expired():
				var baseline: float = effect.baseline_speed()
				if baseline >= 0.0:
					restored = restored.normalized() * baseline * effect.slow_multiplier()
		if restored.length_squared() > 0.001:
			target.velocity = restored
		_owns_motion = false

func preserves_external_velocity() -> bool:
	return true

func movement_control_priority() -> int:
	return PRIORITY

func entity_step_multiplier() -> float:
	return 0.0

func draw_overlay(canvas: CanvasItem, _target, context: Dictionary) -> void:
	var p: Vector2 = context["position"]
	var r: float = context["radius"]
	for index in range(3):
		var a := _age * 12.0 + index * TAU / 3.0
		var n := Vector2.from_angle(a)
		var t := n.orthogonal()
		var root := p + n * r * 1.08
		canvas.draw_polyline(PackedVector2Array([root - t * r * 0.2, root + n * r * 0.2, root + t * r * 0.2]), Color("b8f6ff"), maxf(1.3, r * 0.065), true)
