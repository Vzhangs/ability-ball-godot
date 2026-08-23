extends "res://scripts/balls/core/invulnerability_status_effect.gd"

const STATUS_KEY := "chess_elephant_invulnerability"

func _init(duration: float, effect_source_side: int) -> void:
	super(duration, effect_source_side, STATUS_KEY)

func preserves_external_velocity() -> bool:
	return true

func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_FORCED + 10
