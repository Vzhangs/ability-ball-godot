class_name BallStatusEffect
extends RefCounted

## Stable combat-target effect contract. Fighters and world entities share the
## lifecycle; each hook applies only to targets that support that capability.

const MOVEMENT_CONTROL_PRIORITY_NONE := 0
const MOVEMENT_CONTROL_PRIORITY_ABILITY := 10
const MOVEMENT_CONTROL_PRIORITY_FORCED := 100

var key := ""
var remaining := 0.0
var source_side := -1
var source_fighter_uid := -1
## Immutable event-time producer, including its attachment category and owner.
var combat_source: Dictionary = {}

func tick(_battle, _target, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)

func is_expired() -> bool:
	return remaining <= 0.0

func refresh_from(other: BallStatusEffect) -> void:
	remaining = maxf(remaining, other.remaining)
	source_side = other.source_side
	source_fighter_uid = other.source_fighter_uid
	combat_source = other.combat_source.duplicate(true)

func preserves_external_velocity() -> bool:
	return false

## Ordinary movement modifiers compose with the owning ability's speed. Forced
## movement still owns velocity through preserves_external_velocity/priority.
func fighter_speed_multiplier() -> float:
	return 1.0

## Attachments use this multiplier for their ball-local step. Keeping it on the
## status contract lets a debuff affect movement, orbiting, and autonomous
## actions without the core knowing the concrete entity type.
func entity_step_multiplier() -> float:
	return 1.0

## Higher-priority movement owners suppress lower-priority ability-local velocity writes.
func movement_control_priority() -> int:
	return MOVEMENT_CONTROL_PRIORITY_NONE

func blocks_damage(_battle, _target, _amount: float, _source) -> bool:
	return false

## Non-binary defenses and vulnerabilities share this neutral-by-default hook.
## The health/ledger pipeline still owns the final applied damage.
func modify_incoming_damage(_battle, _target, amount: float, _source) -> float:
	return amount

func on_damage_blocked(_battle, _target, _source, _show_text: bool) -> void:
	pass

func on_wall_hit(_battle, _target) -> void:
	pass

func draw_overlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass

func draw_topmost_overlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass
