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
