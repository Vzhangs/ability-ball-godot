extends BallAbility

const TrackEntityScript := preload("res://scripts/balls/train_conductor/track_entity.gd")
const TrainCarEntityScript := preload("res://scripts/balls/train_conductor/train_car_entity.gd")
const EPSILON := 0.0001

var _building_track: BallEntity
var _settlement_timer := 0.0
var _settlement_count := 0
var _departure_count := 0
var _route_wall_contact_count := 0
var _pending_departures: Array[Dictionary] = []

func on_battle_started(_battle, _fighter, _opponent, _side: int) -> void:
	_building_track = null
	_settlement_timer = 0.0
	_settlement_count = 0
	_departure_count = 0
	_route_wall_contact_count = 0
	_pending_departures.clear()

func automatic_activation_enabled() -> bool:
	return false

func on_step(battle, fighter, _opponent, _side: int, delta: float) -> void:
	_step_pending_departures(battle, delta)
	if not _has_live_building_track():
		_building_track = null
		_settlement_timer = 0.0
		_route_wall_contact_count = 0
		return
	_building_track.call("append_path_to", fighter.pos, false)
	_settlement_timer -= delta
	while _settlement_timer <= 0.0:
		_settlement_timer += settingf("track_settlement_interval")
		if bool(_building_track.call("commit_pending")):
			_settlement_count += 1
			battle.record_stat("train_track_settlements")
			battle.spawn_ring(fighter.pos, fighter.accent, 2.0, 24.0, 0.18)
			battle.emit_combat_event("track", 0.26)

func after_wall_hit(
	battle,
	fighter,
	_opponent,
	side: int,
	contact_position: Vector2
) -> bool:
	if fighter.hp <= 0.0:
		return false
	if _has_live_building_track():
		_building_track.call("append_path_to", contact_position, true)
		_route_wall_contact_count += 1
		battle.record_stat("train_route_wall_contacts")
		if _route_wall_contact_count >= settingi("wall_contacts_per_departure"):
			_finalize_route(battle, fighter, side)
		elif bool(_building_track.call("commit_pending")):
			_settlement_count += 1
			battle.record_stat("train_track_settlements")
	else:
		if _route_cycle_active(battle, side, fighter.fighter_uid):
			return false
		_start_route(battle, fighter, side, contact_position)
	battle.spawn_ring(contact_position, fighter.accent, 3.0, 38.0, 0.25)
	battle.spawn_particles(contact_position, fighter.accent, 5, 86.0)
	return true

func is_recording_route() -> bool:
	return _has_live_building_track()

func settlement_count() -> int:
	return _settlement_count

func departure_count() -> int:
	return _departure_count

func route_wall_contact_count() -> int:
	return _route_wall_contact_count

func pending_departure_count() -> int:
	return _pending_departures.size()

func active_route_point_count() -> int:
	if not _has_live_building_track():
		return 0
	return int(_building_track.call("point_count"))

func active_committed_point_count() -> int:
	if not _has_live_building_track():
		return 0
	return int(_building_track.call("committed_point_count"))

func _start_route(battle, fighter, side: int, contact_position: Vector2) -> void:
	_building_track = TrackEntityScript.new(
		side,
		contact_position,
		fighter.color,
		fighter.accent,
		settingf("track_sample_spacing"),
		settingf("track_absorption_radius")
	)
	_building_track.call("append_path_to", fighter.pos, true)
	battle.add_entity(_building_track)
	_settlement_timer = settingf("track_settlement_interval")
	_route_wall_contact_count = 1
	battle.record_stat("train_routes_started")
	battle.record_stat("train_route_wall_contacts")

func _finalize_route(battle, fighter, side: int) -> void:
	var route_points: PackedVector2Array = _building_track.call("route_points")
	var route_length := float(_building_track.call("route_length"))
	if route_points.size() < 2 or route_length < settingf("track_minimum_length"):
		_building_track.removed = true
		battle.record_stat("train_routes_too_short")
		_building_track = null
		return
	var train_speed := settingf("train_speed")
	var car_radius := settingf("train_car_radius")
	var car_spacing := settingf("train_car_spacing")
	var carriage_count := settingi("train_carriage_count")
	var passage_duration := (
		settingf("train_entry_delay") * train_speed
		+ route_length
		+ float(carriage_count) * car_spacing
		+ car_radius * 2.8
	) / train_speed
	_building_track.call(
		"finalize_route",
		passage_duration + settingf("finalized_track_linger")
	)
	var departure_route := route_points.duplicate()
	var finalized_track := _building_track
	_pending_departures.append({
		"remaining": settingf("train_entry_delay"),
		"just_queued": true,
		"side": side,
		"owner_fighter_uid": fighter.fighter_uid,
		"route_points": departure_route,
		"track": finalized_track,
		"body_color": fighter.color,
		"accent_color": fighter.accent,
	})
	_building_track = null
	_route_wall_contact_count = 0
	battle.spawn_ring(route_points[route_points.size() - 1], fighter.accent, 8.0, 52.0, 0.36)
	battle.spawn_ring(route_points[0], fighter.accent, 5.0, 42.0, 0.28)
	battle.emit_combat_event("train_conductor_whistle", 0.92)

func _step_pending_departures(battle, delta: float) -> void:
	for index in range(_pending_departures.size() - 1, -1, -1):
		var departure: Dictionary = _pending_departures[index]
		var departure_track: BallEntity = departure.get("track") as BallEntity
		if (
			departure_track == null
			or departure_track.removed
			or departure_track.is_captured()
		):
			_pending_departures.remove_at(index)
			battle.record_stat("train_departures_cancelled")
			continue
		var remaining := float(departure["remaining"])
		if bool(departure.get("just_queued", false)):
			departure["just_queued"] = false
			_pending_departures[index] = departure
			if remaining > EPSILON:
				continue
		else:
			remaining = maxf(0.0, remaining - delta)
			departure["remaining"] = remaining
			_pending_departures[index] = departure
		if remaining > EPSILON:
			continue
		var route_points: PackedVector2Array = departure["route_points"]
		var accent_color: Color = departure["accent_color"]
		_spawn_train(
			battle,
			int(departure["side"]),
			int(departure["owner_fighter_uid"]),
			route_points,
			departure["body_color"],
			accent_color
		)
		_pending_departures.remove_at(index)
		_departure_count += 1
		battle.record_stat("train_departures")
		battle.spawn_ring(route_points[0], accent_color, 5.0, 58.0, 0.3)
		battle.spawn_particles(route_points[0], accent_color, 12, 128.0)

func _spawn_train(
	battle,
	side: int,
	owner_fighter_uid: int,
	route_points: PackedVector2Array,
	body_color: Color,
	accent_color: Color
) -> void:
	var requested_units := 1 + settingi("train_carriage_count")
	var maximum_units := settingi("max_active_train_units")
	var active_units: Array[BallEntity] = []
	for existing_unit: BallEntity in battle.entities(side, "train_convoy"):
		if (
			existing_unit.owner_fighter_uid == owner_fighter_uid
			and not existing_unit.is_captured()
		):
			active_units.append(existing_unit)
	var units_to_remove := maxi(0, active_units.size() + requested_units - maximum_units)
	for index in range(mini(units_to_remove, active_units.size())):
		active_units[index].removed = true
	var units_to_spawn := mini(requested_units, maximum_units)
	var convoy_contact_state := {
		"fighter_next_hit": {},
		"entity_next_hit": {},
	}
	for unit_index in range(units_to_spawn):
		var unit: BallEntity = TrainCarEntityScript.new(
			side,
			route_points,
			-float(unit_index) * settingf("train_car_spacing"),
			unit_index == 0,
			body_color,
			accent_color,
			{
				"speed": settingf("train_speed"),
				"radius": settingf("train_car_radius"),
				"damage": settingf("train_contact_damage"),
				"contact_interval": settingf("train_contact_interval"),
				"absorption_radius": settingf("train_absorption_radius"),
				"convoy_contact_state": convoy_contact_state,
			}
		)
		battle.add_entity(unit)

func _route_cycle_active(battle, side: int, owner_fighter_uid: int) -> bool:
	if not _pending_departures.is_empty():
		return true
	for existing_track: BallEntity in battle.entities(side, "train_track"):
		if (
			existing_track.owner_fighter_uid == owner_fighter_uid
			and not existing_track.removed
			and not existing_track.is_captured()
		):
			return true
	for existing_unit: BallEntity in battle.entities(side, "train_convoy"):
		if (
			existing_unit.owner_fighter_uid == owner_fighter_uid
			and not existing_unit.removed
			and not existing_unit.is_captured()
		):
			return true
	return false

func _has_live_building_track() -> bool:
	return (
		_building_track != null
		and not _building_track.removed
		and not _building_track.is_captured()
		and not bool(_building_track.call("is_finalized"))
	)
