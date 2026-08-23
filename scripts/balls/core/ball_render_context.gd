class_name BallRenderContext
extends RefCounted

## Read-only renderer port. Feature entities receive only stable presentation data,
## never the concrete BattleSimulation or BattleView implementation.

var origin := Vector2.ZERO
var scale_factor := 1.0
var viewport_size := Vector2.ZERO
var shake_offset := Vector2.ZERO
var elapsed := 0.0

var _fighters: Array = []
var _entity_counter: Callable

func _init(
	context_origin: Vector2,
	context_scale: float,
	context_viewport_size: Vector2,
	context_shake_offset: Vector2,
	context_elapsed: float,
	fighters: Array,
	entity_counter: Callable
) -> void:
	origin = context_origin
	scale_factor = context_scale
	viewport_size = context_viewport_size
	shake_offset = context_shake_offset
	elapsed = context_elapsed
	_fighters = fighters.duplicate()
	_entity_counter = entity_counter

func point(world_position: Vector2) -> Vector2:
	return origin + world_position * scale_factor

func fighter_for_side(side: int):
	for fighter in _fighters:
		if fighter.team_id == side and fighter.hp > 0.0:
			return fighter
	return null

func fighter_for_uid(fighter_uid: int):
	for fighter in _fighters:
		if fighter.fighter_uid == fighter_uid and fighter.hp > 0.0:
			return fighter
	return null

func owner_for_entity(entity: BallEntity):
	var owner = fighter_for_uid(entity.owner_fighter_uid)
	return owner if owner != null else fighter_for_side(entity.owner_side)

func opponent_for_fighter(source):
	if source == null:
		return null
	var nearest = null
	var nearest_distance := INF
	for fighter in _fighters:
		if fighter.hp <= 0.0 or fighter.team_id == source.team_id:
			continue
		var distance: float = source.pos.distance_squared_to(fighter.pos)
		if distance < nearest_distance - 0.0001 or (is_equal_approx(distance, nearest_distance) and (nearest == null or fighter.fighter_uid < nearest.fighter_uid)):
			nearest = fighter
			nearest_distance = distance
	return nearest

func opponent_for_entity(entity: BallEntity):
	return opponent_for_fighter(owner_for_entity(entity))

func count_entities(owner_side: int, tag: String) -> int:
	return int(_entity_counter.call(owner_side, tag))
