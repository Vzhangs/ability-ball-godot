extends BallAbility

const CloneEntity := preload("res://scripts/balls/splitter/clone_entity.gd")

var _next_clone_id := 0

func max_clones() -> int:
	return settingi("max_clones")

func activate(battle, fighter, _opponent, side: int) -> void:
	var clone_count: int = battle.count_entities(side, "splitter_clone")
	var amount := settingi("early_spawn_count") if clone_count < settingi("early_clone_threshold") else settingi("late_spawn_count")
	var spawn_count: int = mini(amount, max_clones() - clone_count)
	for _index in range(spawn_count):
		_spawn_clone(battle, fighter, side)
	if spawn_count <= 0:
		return
	_emit_split_event(battle, spawn_count)
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius, 112.0, 0.55)
	battle.spawn_particles(fighter.pos, fighter.color, 8 + clone_count + spawn_count, 150.0)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return settingf("body_impact_damage")

func after_contact(battle, _fighter, _opponent, _damage_dealt: float) -> void:
	battle.emit_combat_event("ram_impact", 0.68)

func after_damage_dealt(battle, fighter, _opponent, amount: float) -> void:
	if amount <= 0.0 or battle.random_float() >= settingf("damage_split_chance"):
		return
	var side: int = battle.side_for_fighter(fighter)
	if battle.count_entities(side, "splitter_clone") < max_clones():
		_spawn_clone(battle, fighter, side)
		_emit_split_event(battle, 1)

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
	var clone_radius := settingf("clone_radius")
	var spawn_distance: float = fighter.radius + clone_radius + settingf("clone_spawn_gap")
	var spawn_position: Vector2 = fighter.pos + direction * spawn_distance
	var arena_size: Vector2 = battle.arena_size()
	spawn_position.x = clampf(spawn_position.x, clone_radius, arena_size.x - clone_radius)
	spawn_position.y = clampf(spawn_position.y, clone_radius, arena_size.y - clone_radius)
	var spawn_velocity: Vector2 = direction * battle.random_range(
		settingf("clone_spawn_speed_min"),
		settingf("clone_spawn_speed_max")
	) + fighter.velocity * settingf("clone_owner_velocity_ratio")
	battle.add_entity(CloneEntity.new(
		side,
		spawn_position,
		spawn_velocity,
		fighter.color,
		fighter.accent,
		_next_clone_id,
		{
			"max_hp": settingf("clone_max_hp"),
			"radius": clone_radius,
			"impact_damage": settingf("clone_impact_damage"),
			"impact_wear": settingf("clone_impact_wear"),
			"contact_interval": settingf("clone_contact_interval"),
			"minimum_speed": settingf("clone_min_speed"),
			"maximum_speed": settingf("clone_max_speed"),
			"wall_bounce_spread": settingf("clone_wall_bounce_spread"),
			"target_velocity_ratio": settingf("clone_target_velocity_ratio"),
		}
	))
	_next_clone_id += 1
	battle.record_stat("clones_spawned")

func _emit_split_event(battle, spawn_count: int) -> void:
	battle.emit_combat_event("split", minf(0.78, 0.5 + float(spawn_count) * 0.08))

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
	var cell_size := maxf(1.0, settingf("clone_radius") * settingf("clone_collision_cell_factor"))
	return Vector2i(
		floori(position.x / cell_size),
		floori(position.y / cell_size)
	)
