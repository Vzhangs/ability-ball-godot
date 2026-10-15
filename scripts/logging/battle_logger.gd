class_name BattleLogger
extends RefCounted

const SCHEMA_VERSION := 2
const DEFAULT_LOG_ROOT := "res://builds/logs"

var log_root := DEFAULT_LOG_ROOT
var battle_id := ""
var log_path := ""
var started_at_utc := ""
var started_ticks_msec := 0
var active := false

func _init(custom_log_root: String = DEFAULT_LOG_ROOT) -> void:
	log_root = custom_log_root

func begin(simulation: BattleSimulation, context: Dictionary = {}) -> Error:
	if active:
		return ERR_ALREADY_IN_USE
	started_at_utc = _utc_timestamp()
	started_ticks_msec = Time.get_ticks_msec()
	battle_id = _make_battle_id(simulation)
	var date_directory := started_at_utc.substr(0, 10).replace("-", "")
	var absolute_directory := ProjectSettings.globalize_path("%s/%s" % [log_root, date_directory])
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error
	log_path = absolute_directory.path_join("%s.jsonl" % battle_id)
	var write_error := _append_event({
		"schema_version": SCHEMA_VERSION,
		"event": "battle_started",
		"battle_id": battle_id,
		"timestamp_utc": started_at_utc,
		"process": _process_payload(),
		"runtime": _runtime_payload(),
		"context": _json_safe(context),
		"battle": _battle_payload(simulation),
	})
	active = write_error == OK
	return write_error

func finish(
	simulation: BattleSimulation,
	outcome: String = "completed",
	reason: String = ""
) -> Error:
	if not active:
		return OK
	var finished_at_utc := _utc_timestamp()
	var write_error := _append_event({
		"schema_version": SCHEMA_VERSION,
		"event": "battle_finished",
		"battle_id": battle_id,
		"timestamp_utc": finished_at_utc,
		"started_at_utc": started_at_utc,
		"wall_duration_seconds": maxf(0.0, float(Time.get_ticks_msec() - started_ticks_msec) / 1000.0),
		"outcome": outcome,
		"reason": reason,
		"battle": _battle_payload(simulation),
	})
	active = false
	return write_error

func _battle_payload(simulation: BattleSimulation) -> Dictionary:
	return {
		"seed": simulation.seed_value,
		"elapsed_seconds": simulation.elapsed,
		"maximum_battle_seconds": simulation.max_battle_time,
		"arena_size": _json_safe(simulation.arena_size()),
		"finished": simulation.finished,
		"result": "draw" if simulation.is_draw() else ("win" if simulation.finished else "pending"),
		"is_draw": simulation.is_draw(),
		"winner_id": simulation.winner_id,
		"winner_side": simulation.winner_side,
		"winner_team_id": simulation.winner_team_id,
		"finish_reason": simulation.finish_reason,
		"setup": _json_safe(simulation.battle_setup.snapshot()),
		"rules": {
			"fixed_step_seconds": BattleSimulation.FIXED_STEP,
			"physics_hz": int(round(1.0 / BattleSimulation.FIXED_STEP)),
			"damage_scale": simulation.damage_scale,
			"recovery_scale": simulation.recovery_scale,
			"contact_cooldown": simulation.contact_cooldown,
			"collision_impulse": simulation.collision_impulse,
			"trail_interval": simulation.trail_interval,
		},
		"participants": {
			"left": _participant_payload(simulation.fighter_for_side(simulation.teams[0].team_id), simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)), simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id))),
			"right": _participant_payload(simulation.fighter_for_side(simulation.teams[1].team_id), simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[1].team_id)), simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[1].team_id))),
			"fighters": _fighter_history_payload(simulation),
		},
		"teams": _json_safe(simulation.snapshot()["teams"]),
		"team_events": _json_safe(simulation.team_events),
		"snapshot": _json_safe(simulation.snapshot()),
		"statistics": _json_safe(simulation.stats.duplicate(true)),
		"combat_report": _json_safe(simulation.combat_report()),
		"entities": _objects_payload(simulation.entities),
		"visual_state": {
			"impact_rings": _json_safe(simulation.impact_rings),
			"particles": _json_safe(simulation.particles),
			"floating_texts": _json_safe(simulation.floating_texts),
			"beams": _json_safe(simulation.beams),
			"camera_shake": simulation.camera_shake,
		},
	}

func _participant_payload(fighter, module: BallModule, ability: BallAbility) -> Dictionary:
	var statuses: Array = []
	for effect: BallStatusEffect in fighter.status_effects:
		statuses.append(_object_payload(effect))
	return {
		"fighter": {
			"fighter_uid": fighter.fighter_uid,
			"team_id": fighter.team_id,
			"roster_index": fighter.roster_index,
			"id": fighter.id,
			"display_name": fighter.display_name,
			"color": _json_safe(fighter.color),
			"accent": _json_safe(fighter.accent),
			"position": _json_safe(fighter.pos),
			"velocity": _json_safe(fighter.velocity),
			"radius": fighter.radius,
			"hp": fighter.hp,
			"max_hp": fighter.max_hp,
			"hp_ratio": fighter.hp_ratio(),
			"base_speed": fighter.base_speed,
			"minimum_speed": fighter.minimum_speed,
			"maximum_speed": fighter.maximum_speed,
			"cooldown": fighter.cooldown,
			"ability_timer": fighter.ability_timer,
			"rotation": fighter.rotation,
			"hit_flash": fighter.hit_flash,
			"trail": _json_safe(fighter.trail),
			"status_effects": statuses,
		},
		"module": {
			"id": module.id,
			"display_name": module.display_name,
			"ability_description": module.ability_description,
			"sound_kind": module.sound_kind,
			"sort_order": module.sort_order,
			"color": _json_safe(module.color),
			"accent": _json_safe(module.accent),
			"title_color": _json_safe(module.title_color),
			"settings": _json_safe(module.settings_snapshot()),
			"setting_specs": _json_safe(module.setting_specs()),
		},
		"ability_state": _object_payload(ability),
	}

func _fighter_history_payload(simulation: BattleSimulation) -> Array:
	var result: Array = []
	for fighter in simulation.fighter_history:
		result.append(_participant_payload(
			fighter,
			simulation.module_for_fighter(fighter),
			simulation.ability_for_fighter(fighter)
		))
	return result

func _objects_payload(objects: Array) -> Array:
	var result: Array = []
	for object in objects:
		result.append(_object_payload(object))
	return result

func _object_payload(object: Object) -> Dictionary:
	if object == null:
		return {}
	var script_path := ""
	var script = object.get_script()
	if script is Script:
		script_path = String((script as Script).resource_path)
	var properties := {}
	for property_info in object.get_property_list():
		if int(property_info.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var property_name := String(property_info.get("name", ""))
		if property_name.is_empty():
			continue
		properties[property_name] = _json_safe(object.get(property_name))
	return {
		"class": object.get_class(),
		"script": script_path,
		"properties": properties,
	}

func _process_payload() -> Dictionary:
	return {
		"process_id": OS.get_process_id(),
		"mode": "recording" if "--render-video" in OS.get_cmdline_user_args() else "interactive",
	}

func _runtime_payload() -> Dictionary:
	return {
		"project_name": ProjectSettings.get_setting("application/config/name", ""),
		"godot": _json_safe(Engine.get_version_info()),
		"os": {
			"name": OS.get_name(),
			"version": OS.get_version(),
			"model": OS.get_model_name(),
			"locale": OS.get_locale(),
			"processor_name": OS.get_processor_name(),
			"processor_count": OS.get_processor_count(),
		},
		"display_server": DisplayServer.get_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"physics_ticks_per_second": ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60),
	}

func _append_event(payload: Dictionary) -> Error:
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE
	var file := FileAccess.open(log_path, mode)
	if file == null:
		return FileAccess.get_open_error()
	if mode == FileAccess.READ_WRITE:
		file.seek_end()
	file.store_line(JSON.stringify(_json_safe(payload)))
	file.flush()
	file.close()
	return OK

func _make_battle_id(simulation: BattleSimulation) -> String:
	var compact_time := started_at_utc.replace("-", "").replace(":", "").replace("T", "-").trim_suffix("Z")
	var roster_ids: Array[String] = []
	for team_spec in simulation.battle_setup.teams:
		roster_ids.append("-".join(team_spec["roster"]))
	return "%s-%06d-p%d-%s-%s-seed-%d" % [
		compact_time,
		Time.get_ticks_usec() % 1000000,
		OS.get_process_id(),
		simulation.battle_setup.mode,
		"-vs-".join(roster_ids),
		simulation.seed_value,
	]

func _utc_timestamp() -> String:
	return "%sZ" % Time.get_datetime_string_from_system(true, false)

func _json_safe(value, depth: int = 0):
	if depth >= 8 and typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		return str(value)
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		TYPE_RECT2:
			return {
				"position": _json_safe(value.position, depth + 1),
				"size": _json_safe(value.size, depth + 1),
			}
		TYPE_COLOR:
			return {
				"r": value.r,
				"g": value.g,
				"b": value.b,
				"a": value.a,
				"html": value.to_html(true),
			}
		TYPE_DICTIONARY:
			var dictionary := {}
			for key in value:
				dictionary[str(key)] = _json_safe(value[key], depth + 1)
			return dictionary
		TYPE_ARRAY:
			var array: Array = []
			for item in value:
				array.append(_json_safe(item, depth + 1))
			return array
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			var packed_array: Array = []
			for item in value:
				packed_array.append(_json_safe(item, depth + 1))
			return packed_array
		TYPE_OBJECT:
			if value == null:
				return null
			var object: Object = value
			var script = object.get_script()
			return {
				"class": object.get_class(),
				"script": String(script.resource_path) if script is Script else "",
				"instance_id": object.get_instance_id(),
			}
		_:
			return str(value)
