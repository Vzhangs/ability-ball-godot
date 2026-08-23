extends BallStatusEffect

func _init(duration: float, effect_source_side: int) -> void:
	key = "vampire_latch_release:%d" % effect_source_side
	remaining = maxf(duration, 0.0)
	source_side = effect_source_side

func preserves_external_velocity() -> bool:
	return true

func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_FORCED
