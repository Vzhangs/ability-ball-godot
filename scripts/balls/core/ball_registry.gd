class_name BallRegistry
extends RefCounted

const BALLS_PATH := "res://scripts/balls"

static var _loaded := false
static var _modules := {}
static var _ordered_modules: Array = []
static var _errors := PackedStringArray()
static var _runtime_settings := {}
static var _audio_samples := {}

static func configure_settings(settings: Dictionary) -> void:
	_runtime_settings = settings.duplicate(true)
	reload()

static func settings_snapshot() -> Dictionary:
	_ensure_loaded()
	var result := {}
	for module: BallModule in _ordered_modules:
		result[module.id] = module.settings_snapshot()
	return result

static func audio_samples() -> Dictionary:
	_ensure_loaded()
	return _audio_samples.duplicate()

static func reload() -> void:
	_loaded = false
	_modules.clear()
	_ordered_modules.clear()
	_errors.clear()
	_audio_samples.clear()
	_ensure_loaded()

static func ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for module in _ordered_modules:
		result.append(module.id)
	return result

static func modules() -> Array:
	_ensure_loaded()
	return _ordered_modules.duplicate()

static func has_id(ball_id: String) -> bool:
	_ensure_loaded()
	return _modules.has(ball_id)

static func get_module(ball_id: String):
	_ensure_loaded()
	return _modules.get(ball_id)

static func validation_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()

static func is_valid() -> bool:
	return validation_errors().is_empty()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var directories := DirAccess.get_directories_at(BALLS_PATH)
	directories.sort()
	for directory in directories:
		var entry_path := "%s/%s/module.gd" % [BALLS_PATH, directory]
		if not ResourceLoader.exists(entry_path):
			continue
		var entry_script := load(entry_path) as Script
		if entry_script == null or not entry_script.can_instantiate():
			_errors.append("cannot load %s" % entry_path)
			continue
		var module = entry_script.new()
		if not module is BallModule:
			_errors.append("%s does not extend BallModule" % entry_path)
			continue
		var module_settings: Dictionary = _runtime_settings.get(module.id, {})
		module.apply_settings(module_settings)
		for error in module.validation_errors():
			_errors.append(error)
		if module.id.is_empty():
			continue
		if _modules.has(module.id):
			_errors.append("duplicate ball id: %s" % module.id)
			continue
		for event_kind in module.audio_samples():
			if _audio_samples.has(event_kind):
				_errors.append("duplicate sampled audio event: %s" % event_kind)
				continue
			_audio_samples[event_kind] = module.audio_samples()[event_kind]
		_modules[module.id] = module
		_ordered_modules.append(module)
	_ordered_modules.sort_custom(func(left, right): return left.sort_order < right.sort_order)
