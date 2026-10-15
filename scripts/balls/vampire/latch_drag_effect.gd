extends BallStatusEffect

const STATUS_KEY := "vampire_latch_drag"

func _init(duration: float, effect_source_side: int) -> void:
	key = STATUS_KEY
	remaining = maxf(0.0, duration)
	source_side = effect_source_side

func preserves_external_velocity() -> bool:
	return true

func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_FORCED

func on_wall_hit(battle, target) -> void:
	var source = battle.fighter_for_uid(source_fighter_uid)
	if source == null:
		source = battle.fighter_for_side(source_side)
	if source == null or source == target or source.hp <= 0.0:
		return
	# The wall resolver has already reflected the dragged target. Propagate that
	# resolved velocity to the latch owner so the pair leaves the wall together.
	source.velocity = target.velocity
