class_name BallRenderContext
extends RefCounted

## Read-only renderer port. Feature entities receive only stable presentation data,
## never the concrete BattleSimulation or BattleView implementation.

var origin := Vector2.ZERO
var scale_factor := 1.0
var viewport_size := Vector2.ZERO
var shake_offset := Vector2.ZERO
var elapsed := 0.0

var _left_fighter
var _right_fighter
var _entity_counter: Callable

func _init(
	context_origin: Vector2,
	context_scale: float,
	context_viewport_size: Vector2,
	context_shake_offset: Vector2,
	context_elapsed: float,
	left_fighter,
	right_fighter,
	entity_counter: Callable
) -> void:
	origin = context_origin
	scale_factor = context_scale
	viewport_size = context_viewport_size
	shake_offset = context_shake_offset
	elapsed = context_elapsed
	_left_fighter = left_fighter
	_right_fighter = right_fighter
	_entity_counter = entity_counter

func point(world_position: Vector2) -> Vector2:
	return origin + world_position * scale_factor

func fighter_for_side(side: int):
	return _left_fighter if side == 0 else _right_fighter

func count_entities(owner_side: int, tag: String) -> int:
	return int(_entity_counter.call(owner_side, tag))
