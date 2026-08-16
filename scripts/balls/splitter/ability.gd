extends BallAbility

const CloneEntity := preload("res://scripts/balls/splitter/clone_entity.gd")
const MAX_CLONES := 100
const COLLISION_CELL_SIZE := CloneEntity.BODY_RADIUS * 2.2

var _next_clone_id := 0

func activate(battle, fighter, _opponent, side: int) -> void:
	var clone_count: int = battle.count_entities(side, "splitter_clone")
	var amount := 2 if clone_count < 4 else 3
	var spawn_count: int = mini(amount, MAX_CLONES - clone_count)
	for _index in range(spawn_count):
		_spawn_clone(battle, fighter, side)
	if spawn_count <= 0:
		return
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 112.0, 0.55)
	battle.spawn_particles(fighter.pos, fighter.color, 8 + clone_count + spawn_count, 150.0)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 5.0

func after_damage_dealt(battle, fighter, _opponent, amount: float) -> void:
	if amount <= 0.0 or battle.random_float() >= 0.22:
		return
	var side: int = battle.side_for_fighter(fighter)
	if battle.count_entities(side, "splitter_clone") < MAX_CLONES:
		_spawn_clone(battle, fighter, side)

func after_entities_step(battle, _fighter, _opponent, side: int, _delta: float) -> void:
	var clones: Array[BallEntity] = battle.entities(side, "splitter_clone")
	_resolve_local_clone_collisions(battle, clones)
	if side == 0:
		_resolve_hostile_clone_collisions(battle, clones, battle.entities(1, "splitter_clone"))
	clones = battle.entities(side, "splitter_clone")
	clones.sort_custom(func(left: BallEntity, right: BallEntity) -> bool:
		return int(left.call("clone_id")) < int(right.call("clone_id"))
	)
	for index in range(clones.size()):
		clones[index].call("set_health_bar_index", index)

func _spawn_clone(battle, fighter, side: int) -> void:
	var direction := Vector2.from_angle(battle.random_range(0.0, TAU))
	var spawn_distance: float = fighter.radius + CloneEntity.BODY_RADIUS + 4.0
	var spawn_position: Vector2 = fighter.pos + direction * spawn_distance
	var arena_size: Vector2 = battle.arena_size()
	spawn_position.x = clampf(spawn_position.x, CloneEntity.BODY_RADIUS, arena_size.x - CloneEntity.BODY_RADIUS)
	spawn_position.y = clampf(spawn_position.y, CloneEntity.BODY_RADIUS, arena_size.y - CloneEntity.BODY_RADIUS)
	var spawn_velocity: Vector2 = direction * battle.random_range(205.0, 265.0) + fighter.velocity * 0.28
	battle.add_entity(CloneEntity.new(
		side,
		spawn_position,
		spawn_velocity,
		fighter.color,
		fighter.accent,
		_next_clone_id
	))
	_next_clone_id += 1
	battle.record_stat("clones_spawned")

func _resolve_local_clone_collisions(battle, clones: Array[BallEntity]) -> void:
	var grid: Dictionary = {}
	for clone in clones:
		if clone.removed:
			continue
		var cell := _collision_cell(clone.pos)
		for cell_x in range(cell.x - 1, cell.x + 2):
			for cell_y in range(cell.y - 1, cell.y + 2):
				var bucket: Array = grid.get(Vector2i(cell_x, cell_y), [])
				for other in bucket:
					if clone.removed:
						break
					clone.call("resolve_clone_collision", battle, other)
		if clone.removed:
			continue
		var own_bucket: Array = grid.get(cell, [])
		own_bucket.append(clone)
		grid[cell] = own_bucket

func _resolve_hostile_clone_collisions(
	battle,
	clones: Array[BallEntity],
	hostile_clones: Array[BallEntity]
) -> void:
	if hostile_clones.is_empty():
		return
	var hostile_grid: Dictionary = {}
	for hostile_clone in hostile_clones:
		var cell := _collision_cell(hostile_clone.pos)
		var bucket: Array = hostile_grid.get(cell, [])
		bucket.append(hostile_clone)
		hostile_grid[cell] = bucket
	for clone in clones:
		if clone.removed:
			continue
		var cell := _collision_cell(clone.pos)
		for cell_x in range(cell.x - 1, cell.x + 2):
			for cell_y in range(cell.y - 1, cell.y + 2):
				var bucket: Array = hostile_grid.get(Vector2i(cell_x, cell_y), [])
				for other in bucket:
					if clone.removed:
						break
					clone.call("resolve_clone_collision", battle, other)

func _collision_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / COLLISION_CELL_SIZE),
		floori(position.y / COLLISION_CELL_SIZE)
	)
