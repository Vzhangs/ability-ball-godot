class_name BallStatusEffect
extends RefCounted

## Stable fighter-effect contract. Ball-specific effects live beside their owning ball.

const MOVEMENT_CONTROL_PRIORITY_NONE := 0
const MOVEMENT_CONTROL_PRIORITY_ABILITY := 10
const MOVEMENT_CONTROL_PRIORITY_FORCED := 100

var key := ""
var remaining := 0.0
var source_side := -1
var source_fighter_uid := -1

func tick(_battle, _target, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)

func is_expired() -> bool:
	return remaining <= 0.0

func refresh_from(other: BallStatusEffect) -> void:
	remaining = maxf(remaining, other.remaining)
	source_side = other.source_side
	source_fighter_uid = other.source_fighter_uid

func preserves_external_velocity() -> bool:
	return false

## Higher-priority movement owners suppress lower-priority ability-local velocity writes.
func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_NONE

func blocks_damage(_battle, _target, _amount: float, _source) -> bool:
	return false

func on_damage_blocked(_battle, _target, _source, _show_text: bool) -> void:
	pass

func on_wall_hit(_battle, _target) -> void:
	pass

func draw_overlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass

func draw_topmost_overlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass
