extends BallStatusEffect

var _direction := Vector2.RIGHT
var _speed := 0.0

func _init(side: int, direction: Vector2, speed: float, duration: float) -> void:
	key = "creeper_blast_knockback"
	source_side = side
	_direction = direction
	_speed = speed
	remaining = duration

func refresh_from(other: BallStatusEffect) -> void:
	super(other)
	_direction = other.get("_direction")
	_speed = float(other.get("_speed"))

func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_FORCED

func tick(battle, target, delta: float) -> void:
	var motion_delta := minf(delta, remaining)
	super(battle, target, delta)
	for effect: BallStatusEffect in target.status_effects:
		if effect != self and not effect.is_expired() and effect.movement_control_priority() >= movement_control_priority():
			return
	# Add a finite displacement without acquiring or restoring the target's velocity.
	# This avoids the main-body speed cap and leaves later movement owners intact.
	if target is BallEntity and target.fighter_collision_inverse_mass() <= 0.0:
		return
	var bounds: Vector2 = battle.arena_size()
	target.pos += _direction * _speed * motion_delta
	target.pos.x = clampf(target.pos.x, target.radius, maxf(target.radius, bounds.x - target.radius))
	target.pos.y = clampf(target.pos.y, target.radius, maxf(target.radius, bounds.y - target.radius))
