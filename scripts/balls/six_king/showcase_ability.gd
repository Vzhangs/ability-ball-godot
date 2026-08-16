extends BallAbility

const ShowcaseAnchorEntity := preload("res://scripts/balls/six_king/showcase_anchor_entity.gd")
const ShowcaseCheckerEntity := preload("res://scripts/balls/six_king/showcase_checker_entity.gd")
const ShowcaseTrackEntity := preload("res://scripts/balls/six_king/showcase_track_entity.gd")
const ShowcaseCarriageEntity := preload("res://scripts/balls/six_king/showcase_carriage_entity.gd")

var _anchor_timer := 0.6
var _track_timer := 2.5
var _checker_timer := 3.0
var _tether_damage_timer := 0.0
var _track_damage_timer := 0.0
var _carriage_damage_timer := 0.0
var _crown_level := 1

func automatic_activation_enabled() -> bool:
	return false

func crown_level() -> int:
	return _crown_level

func on_battle_started(battle, fighter, _opponent, side: int) -> void:
	battle.add_entity(ShowcaseCarriageEntity.new(side, fighter, self))

func before_motion(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_anchor_timer -= delta
	_track_timer -= delta
	_checker_timer -= delta
	_tether_damage_timer = maxf(0.0, _tether_damage_timer - delta)
	_track_damage_timer = maxf(0.0, _track_damage_timer - delta)
	_carriage_damage_timer = maxf(0.0, _carriage_damage_timer - delta)

func on_step(battle, fighter, opponent, side: int, _delta: float) -> void:
	_update_crown_level(battle, fighter, opponent)
	var anchors: Array[BallEntity] = battle.entities(side, "showcase_anchor")
	var desired_anchor_count: int = 8 + _crown_level * 7
	if _anchor_timer <= 0.0 and anchors.size() < desired_anchor_count:
		_anchor_timer = maxf(0.7, 1.55 - _crown_level * 0.22)
		_spawn_anchor(battle, fighter, side, anchors.size())

	if _checker_timer <= 0.0:
		_checker_timer = maxf(3.5, 5.8 - _crown_level * 0.55)
		_activate_checkerboard(battle, fighter, opponent, side)

	if _track_timer <= 0.0:
		_track_timer = maxf(4.6, 8.2 - _crown_level)
		_spawn_track(battle, fighter, side)

	anchors = battle.entities(side, "showcase_anchor")
	if anchors.is_empty() or _tether_damage_timer > 0.0:
		return
	_tether_damage_timer = 0.20
	var crossings := 0
	for anchor in anchors:
		if _distance_to_segment(opponent.pos, fighter.pos, anchor.pos) <= opponent.radius * 0.72:
			crossings += 1
	if crossings > 0:
		var tether_damage := minf(26.0, 2.4 + crossings * (1.6 + _crown_level * 0.55))
		battle.damage(opponent, tether_damage, Color("7be8ff"), fighter, false)
		battle.record_stat("tether_hits")
		battle.spawn_particles(opponent.pos, Color("8defff"), mini(8, crossings + 2), 95.0)
	for entity: BallEntity in battle.damageable_entities(side):
		var entity_crossings := 0
		for anchor in anchors:
			if _distance_to_segment(entity.pos, fighter.pos, anchor.pos) <= entity.radius:
				entity_crossings += 1
		if entity_crossings <= 0:
			continue
		var entity_damage := minf(26.0, 2.4 + entity_crossings * (1.6 + _crown_level * 0.55))
		battle.damage_entity(entity, entity_damage, Color("7be8ff"), side, false)
		battle.record_stat("tether_hits")
		battle.spawn_particles(entity.pos, Color("8defff"), mini(8, entity_crossings + 2), 95.0)

func after_entities_step(battle, fighter, opponent, side: int, _delta: float) -> void:
	var touching_track := false
	var tracks: Array[BallEntity] = battle.entities(side, "showcase_track")
	for track: BallEntity in tracks:
		if bool(track.call("touches", opponent)):
			touching_track = true
			break
	var track_targets: Array[BallEntity] = []
	for entity: BallEntity in battle.damageable_entities(side):
		for track: BallEntity in tracks:
			if bool(track.call("touches", entity)):
				track_targets.append(entity)
				break
	if _track_damage_timer <= 0.0 and (touching_track or not track_targets.is_empty()):
		_track_damage_timer = 0.16
		var track_damage := 7.0 + _crown_level * 3.5
		if touching_track:
			battle.damage(opponent, track_damage, Color("e5bd83"), fighter, false)
			opponent.velocity += (opponent.pos - fighter.pos).normalized() * 28.0
		for entity: BallEntity in track_targets:
			battle.damage_entity(entity, track_damage, Color("e5bd83"), side, false)
			entity.velocity += (entity.pos - fighter.pos).normalized() * 28.0
		battle.record_stat("track_hits")
		battle.emit_combat_event("track", 0.45)

	var carriages: Array[BallEntity] = battle.entities(side, "showcase_carriage")
	if carriages.is_empty() or _carriage_damage_timer > 0.0:
		return
	var carriage := carriages[0]
	var carriage_hits_opponent: bool = carriage.pos.distance_to(opponent.pos) <= opponent.radius + 31.0
	var carriage_targets: Array[BallEntity] = battle.damageable_entities_in_circle(side, carriage.pos, 31.0)
	if not carriage_hits_opponent and carriage_targets.is_empty():
		return
	_carriage_damage_timer = 0.65
	var carriage_damage := 25.0 + _crown_level * 8.0
	if carriage_hits_opponent:
		battle.damage(opponent, carriage_damage, Color("f4f4f4"), fighter)
		opponent.velocity += (opponent.pos - carriage.pos).normalized() * 110.0
	for entity: BallEntity in carriage_targets:
		battle.damage_entity(entity, carriage_damage, Color("f4f4f4"), side)
		entity.velocity += (entity.pos - carriage.pos).normalized() * 110.0
	battle.shake_camera(7.0)

func _spawn_anchor(battle, fighter, side: int, index: int) -> void:
	var edge_side := index % 4
	var slot := int(index / 4)
	var spread := 72.0 + float(slot % 7) * 82.0
	var position := Vector2.ZERO
	var inward := Vector2.ZERO
	match edge_side:
		0:
			position = Vector2(clampf(spread, 22.0, 618.0), 7.0)
			inward = Vector2.DOWN
		1:
			position = Vector2(633.0, clampf(spread, 22.0, 618.0))
			inward = Vector2.LEFT
		2:
			position = Vector2(clampf(battle.arena_size().x - spread, 22.0, 618.0), 633.0)
			inward = Vector2.UP
		_:
			position = Vector2(7.0, clampf(battle.arena_size().y - spread, 22.0, 618.0))
			inward = Vector2.RIGHT
	battle.add_entity(ShowcaseAnchorEntity.new(side, fighter, position, inward, index))
	battle.record_stat("anchors_spawned")
	battle.spawn_ring(position, Color("22ff4d"), 3.0, 38.0, 0.45)

func _activate_checkerboard(battle, fighter, opponent, side: int) -> void:
	var cells: Array[Dictionary] = []
	var grid_count := 6
	var cell_size: float = battle.arena_size().x / float(grid_count)
	for y in range(grid_count):
		for x in range(grid_count):
			var active: bool = ((x + y + _crown_level + int(battle.elapsed)) % 3 == 0) or battle.random_float() < 0.14
			var value: int = battle.random_int(1, 30)
			cells.append({
				"rect": Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size),
				"active": active,
				"value": value,
			})
	battle.add_entity(ShowcaseCheckerEntity.new(side, cells))
	var cell_x := clampi(int(opponent.pos.x / cell_size), 0, grid_count - 1)
	var cell_y := clampi(int(opponent.pos.y / cell_size), 0, grid_count - 1)
	var current: Dictionary = cells[cell_y * grid_count + cell_x]
	var hit_something := false
	if bool(current["active"]):
		var damage: float = 24.0 + float(current["value"]) * 0.75 + _crown_level * 7.0
		battle.damage(opponent, damage, Color("fff06a"), fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities(side):
		var entity_cell_x := clampi(int(entity.pos.x / cell_size), 0, grid_count - 1)
		var entity_cell_y := clampi(int(entity.pos.y / cell_size), 0, grid_count - 1)
		var entity_cell: Dictionary = cells[entity_cell_y * grid_count + entity_cell_x]
		if not bool(entity_cell["active"]):
			continue
		var entity_damage: float = 24.0 + float(entity_cell["value"]) * 0.75 + _crown_level * 7.0
		battle.damage_entity(entity, entity_damage, Color("fff06a"), side)
		hit_something = true
	if hit_something:
		battle.record_stat("checker_hits")
		battle.emit_combat_event("judgment", 0.9)

func _spawn_track(battle, fighter, side: int) -> void:
	var config := {
		"angle": battle.random_range(0.0, TAU),
		"arms": 2 + _crown_level,
		"length": 250.0 + _crown_level * 45.0,
		"lifetime": 10.0 + _crown_level * 2.0,
		"angular_speed": battle.random_range(0.18, 0.34) * (-1.0 if battle.random_float() < 0.5 else 1.0),
		"width": 19.0 + _crown_level * 2.0,
	}
	battle.add_entity(ShowcaseTrackEntity.new(side, fighter, config))
	battle.record_stat("tracks_spawned")
	battle.spawn_ring(fighter.pos, Color("c9a978"), 26.0, 110.0, 0.55)

func _update_crown_level(battle, fighter, opponent) -> void:
	var next_level := 1
	if battle.elapsed >= 74.0 or opponent.hp_ratio() <= 0.36:
		next_level = 3
	elif battle.elapsed >= 37.0 or opponent.hp_ratio() <= 0.68:
		next_level = 2
	if next_level <= _crown_level:
		return
	var advances := next_level - _crown_level
	_crown_level = next_level
	battle.record_stat("crown_advances", advances)
	battle.emit_combat_event("judgment", 0.9)
	battle.shake_camera(8.0)
	battle.spawn_ring(fighter.pos, Color("ffe75a"), 24.0, 170.0, 1.0)
	battle.spawn_particles(fighter.pos, Color("ffe75a"), 18, 210.0)

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)
