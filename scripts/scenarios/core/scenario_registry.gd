class_name BattleScenarioRegistry
extends RefCounted

const SCENARIOS_PATH := "res://scripts/scenarios"
const BattleScenarioScript := preload("res://scripts/scenarios/core/battle_scenario.gd")

static var _loaded := false
static var _scenarios: Array = []
static var _errors := PackedStringArray()

static func reload() -> void:
	_loaded = false
	_scenarios.clear()
	_errors.clear()
	_ensure_loaded()

static func resolve(left_id: String, right_id: String):
	_ensure_loaded()
	for scenario in _scenarios:
		if scenario.matches(left_id, right_id):
			return scenario
	return BattleScenarioScript.new()

static func validation_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var directories := DirAccess.get_directories_at(SCENARIOS_PATH)
	directories.sort()
	for directory in directories:
		if directory == "core":
			continue
		var entry_path := "%s/%s/module.gd" % [SCENARIOS_PATH, directory]
		if not ResourceLoader.exists(entry_path):
			continue
		var entry_script := load(entry_path) as Script
		if entry_script == null or not entry_script.can_instantiate():
			_errors.append("cannot load %s" % entry_path)
			continue
		var scenario = entry_script.new()
		if not scenario is BattleScenario:
			_errors.append("%s does not extend BattleScenario" % entry_path)
			continue
		if scenario.id.is_empty() or scenario.left_ball_id.is_empty() or scenario.right_ball_id.is_empty():
			_errors.append("%s has incomplete identity" % entry_path)
			continue
		_scenarios.append(scenario)
