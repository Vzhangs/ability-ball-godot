extends BallAbility

const ShowcaseAnchorEntity := preload("res://scripts/balls/six_king/showcase_anchor_entity.gd")
const ShowcaseCheckerEntity := preload("res://scripts/balls/six_king/showcase_checker_entity.gd")
const ShowcaseTrackEntity := preload("res://scripts/balls/six_king/showcase_track_entity.gd")
const ShowcaseCarriageEntity := preload("res://scripts/balls/six_king/showcase_carriage_entity.gd")

var _anchor_timer := 0.0
var _track_timer := 0.0
var _checker_timer := 0.0
var _tether_damage_timer := 0.0
var _track_damage_timer := 0.0
var _carriage_damage_timer := 0.0
var _crown_level := 1

func automatic_activation_enabled() -> bool:
	return false

func crown_level() -> int:
	return _crown_level

func on_battle_started(battle, fighter, _opponent, side: int) -> void:
	_anchor_timer = settingf("showcase_anchor_initial_delay")
	_track_timer = settingf("showcase_track_initial_delay")
	_checker_timer = settingf("showcase_checker_initial_delay")
	battle.add_entity(ShowcaseCarriageEntity.new(side, fighter, self, {
		"radius": settingf("showcase_carriage_hit_radius"),
		"orbit_radius": settingf("showcase_carriage_orbit_radius"),
		"orbit_radius_per_level": settingf("showcase_carriage_orbit_per_level"),
		"orbit_speed": settingf("showcase_carriage_orbit_speed"),
		"orbit_speed_per_level": settingf("showcase_carriage_speed_per_level"),
	}))

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
	var desired_anchor_count: int = settingi("showcase_anchor_base_count") + _crown_level * settingi("showcase_anchor_per_level")
	if _anchor_timer <= 0.0 and anchors.size() < desired_anchor_count:
		_anchor_timer = maxf(
			settingf("showcase_anchor_interval_min"),
			settingf("showcase_anchor_interval") - _crown_level * settingf("showcase_anchor_interval_level_reduction")
		)
		_spawn_anchor(battle, fighter, side, anchors.size())

	if _checker_timer <= 0.0:
		_checker_timer = maxf(
			settingf("showcase_checker_interval_min"),
			settingf("showcase_checker_interval") - _crown_level * settingf("showcase_checker_interval_level_reduction")
		)
		_activate_checkerboard(battle, fighter, opponent, side)

	if _track_timer <= 0.0:
		_track_timer = maxf(
			settingf("showcase_track_interval_min"),
			settingf("showcase_track_interval") - _crown_level * settingf("showcase_track_interval_level_reduction")
		)
		_spawn_track(battle, fighter, side)

	anchors = battle.entities(side, "showcase_anchor")
	if anchors.is_empty() or _tether_damage_timer > 0.0:
		return
	_tether_damage_timer = settingf("showcase_tether_tick")
	var crossings := 0
	for anchor in anchors:
		if _distance_to_segment(opponent.pos, fighter.pos, anchor.pos) <= opponent.radius * settingf("showcase_tether_hit_radius_factor"):
			crossings += 1
	if crossings > 0:
		var tether_damage := _tether_damage(crossings)
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
		var entity_damage := _tether_damage(entity_crossings)
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
		_track_damage_timer = settingf("showcase_track_tick")
		var track_damage := settingf("showcase_track_base_damage") + _crown_level * settingf("showcase_track_level_damage")
		var track_knockback := settingf("showcase_track_knockback")
		if touching_track:
			battle.damage(opponent, track_damage, Color("e5bd83"), fighter, false)
			opponent.velocity += (opponent.pos - fighter.pos).normalized() * track_knockback
		for entity: BallEntity in track_targets:
			battle.damage_entity(entity, track_damage, Color("e5bd83"), side, false)
			entity.velocity += (entity.pos - fighter.pos).normalized() * track_knockback
		battle.record_stat("track_hits")
		battle.emit_combat_event("track", 0.45)

	var carriages: Array[BallEntity] = battle.entities(side, "showcase_carriage")
	if carriages.is_empty() or _carriage_damage_timer > 0.0:
		return
	var carriage := carriages[0]
	var carriage_hit_radius := settingf("showcase_carriage_hit_radius")
	var carriage_hits_opponent: bool = carriage.pos.distance_to(opponent.pos) <= opponent.radius + carriage_hit_radius
	var carriage_targets: Array[BallEntity] = battle.damageable_entities_in_circle(side, carriage.pos, carriage_hit_radius)
	if not carriage_hits_opponent and carriage_targets.is_empty():
		return
	_carriage_damage_timer = settingf("showcase_carriage_hit_interval")
	var carriage_damage := settingf("showcase_carriage_damage") + _crown_level * settingf("showcase_carriage_level_damage")
	var carriage_knockback := settingf("showcase_carriage_knockback")
	if carriage_hits_opponent:
		battle.damage(opponent, carriage_damage, Color("f4f4f4"), fighter)
		opponent.velocity += (opponent.pos - carriage.pos).normalized() * carriage_knockback
	for entity: BallEntity in carriage_targets:
		battle.damage_entity(entity, carriage_damage, Color("f4f4f4"), side)
		entity.velocity += (entity.pos - carriage.pos).normalized() * carriage_knockback
	battle.shake_camera(7.0)

func _spawn_anchor(battle, fighter, side: int, index: int) -> void:
	var edge_side := index % 4
	var slot := int(index / 4)
	var slots_per_edge := settingi("showcase_anchor_slots_per_edge")
	var spread := settingf("showcase_anchor_first_offset") + float(slot % slots_per_edge) * settingf("showcase_anchor_slot_spacing")
	var arena_size: Vector2 = battle.arena_size()
	var edge_margin := settingf("showcase_anchor_edge_margin")
	var corner_guard := settingf("showcase_anchor_corner_guard")
	var horizontal_spread := clampf(spread, corner_guard, arena_size.x - corner_guard)
	var vertical_spread := clampf(spread, corner_guard, arena_size.y - corner_guard)
	var position := Vector2.ZERO
	var inward := Vector2.ZERO
	match edge_side:
		0:
			position = Vector2(horizontal_spread, edge_margin)
			inward = Vector2.DOWN
		1:
			position = Vector2(arena_size.x - edge_margin, vertical_spread)
			inward = Vector2.LEFT
		2:
			position = Vector2(arena_size.x - horizontal_spread, arena_size.y - edge_margin)
			inward = Vector2.UP
		_:
			position = Vector2(edge_margin, arena_size.y - vertical_spread)
			inward = Vector2.RIGHT
	battle.add_entity(ShowcaseAnchorEntity.new(side, fighter, position, inward, index))
	battle.record_stat("anchors_spawned")
	battle.spawn_ring(position, Color("22ff4d"), 3.0, 38.0, 0.45)

func _activate_checkerboard(battle, fighter, opponent, side: int) -> void:
	var cells: Array[Dictionary] = []
	var grid_count := settingi("showcase_checker_grid")
	var pattern_divisor := settingi("showcase_checker_pattern_divisor")
	var cell_size: float = battle.arena_size().x / float(grid_count)
	for y in range(grid_count):
		for x in range(grid_count):
			var active: bool = ((x + y + _crown_level + int(battle.elapsed)) % pattern_divisor == 0) or battle.random_float() < settingf("showcase_checker_active_chance")
			var value: int = battle.random_int(1, settingi("showcase_checker_value_max"))
			cells.append({
				"rect": Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size),
				"active": active,
				"value": value,
			})
	battle.add_entity(ShowcaseCheckerEntity.new(side, cells, settingf("showcase_checker_duration")))
	var cell_x := clampi(int(opponent.pos.x / cell_size), 0, grid_count - 1)
	var cell_y := clampi(int(opponent.pos.y / cell_size), 0, grid_count - 1)
	var current: Dictionary = cells[cell_y * grid_count + cell_x]
	var hit_something := false
	if bool(current["active"]):
		var damage: float = _checker_damage(int(current["value"]))
		battle.damage(opponent, damage, Color("fff06a"), fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities(side):
		var entity_cell_x := clampi(int(entity.pos.x / cell_size), 0, grid_count - 1)
		var entity_cell_y := clampi(int(entity.pos.y / cell_size), 0, grid_count - 1)
		var entity_cell: Dictionary = cells[entity_cell_y * grid_count + entity_cell_x]
		if not bool(entity_cell["active"]):
			continue
		var entity_damage: float = _checker_damage(int(entity_cell["value"]))
		battle.damage_entity(entity, entity_damage, Color("fff06a"), side)
		hit_something = true
	if hit_something:
		battle.record_stat("checker_hits")
		battle.emit_combat_event("judgment", 0.9)

func _spawn_track(battle, fighter, side: int) -> void:
	var config := {
		"angle": battle.random_range(0.0, TAU),
		"arms": settingi("showcase_track_arms_base") + _crown_level,
		"length": settingf("showcase_track_length") + _crown_level * settingf("showcase_track_length_per_level"),
		"lifetime": settingf("showcase_track_lifetime") + _crown_level * settingf("showcase_track_lifetime_per_level"),
		"angular_speed": battle.random_range(
			settingf("showcase_track_angular_speed_min"),
			settingf("showcase_track_angular_speed_max")
		) * (-1.0 if battle.random_float() < settingf("showcase_track_clockwise_chance") else 1.0),
		"width": settingf("showcase_track_width") + _crown_level * settingf("showcase_track_width_per_level"),
	}
	battle.add_entity(ShowcaseTrackEntity.new(side, fighter, config))
	battle.record_stat("tracks_spawned")
	battle.spawn_ring(fighter.pos, Color("c9a978"), 26.0, 110.0, 0.55)

func _update_crown_level(battle, fighter, opponent) -> void:
	var next_level := 1
	if battle.elapsed >= settingf("showcase_level_3_time") or opponent.hp_ratio() <= settingf("showcase_level_3_hp_ratio"):
		next_level = 3
	elif battle.elapsed >= settingf("showcase_level_2_time") or opponent.hp_ratio() <= settingf("showcase_level_2_hp_ratio"):
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

func _tether_damage(crossings: int) -> float:
	return minf(
		settingf("showcase_tether_damage_cap"),
		settingf("showcase_tether_base_damage")
		+ crossings * (settingf("showcase_tether_crossing_damage") + _crown_level * settingf("showcase_tether_level_damage"))
	)

func _checker_damage(value: int) -> float:
	return (
		settingf("showcase_checker_base_damage")
		+ float(value) * settingf("showcase_checker_value_damage")
		+ _crown_level * settingf("showcase_checker_level_damage")
	)
