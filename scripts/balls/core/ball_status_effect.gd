class_name BallStatusEffect
extends RefCounted

## Stable fighter-effect contract. Ball-specific effects live beside their owning ball.

var key := ""
var remaining := 0.0
var source_side := -1

func tick(_battle, _target, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)

func is_expired() -> bool:
	return remaining <= 0.0

func refresh_from(other: BallStatusEffect) -> void:
	remaining = maxf(remaining, other.remaining)
	source_side = other.source_side

func preserves_external_velocity() -> bool:
	return false

func blocks_damage(_battle, _target, _amount: float, _source) -> bool:
	return false

func on_damage_blocked(_battle, _target, _source, _show_text: bool) -> void:
	pass

func on_wall_hit(_battle, _target) -> void:
	pass

func draw_overlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass
