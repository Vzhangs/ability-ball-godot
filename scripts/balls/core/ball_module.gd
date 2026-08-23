class_name BallModule
extends RefCounted

var id := ""
var display_name := ""
var color := Color.WHITE
var accent := Color.WHITE
var title_color := Color.WHITE
var max_hp := 100.0
var speed := 180.0
var radius := 27.0
var cooldown := 4.0
var ability_description := ""
var sound_kind := "impact"
var sort_order := 0
var ability_script: Script
var visual_script: Script
var _audio_samples: Dictionary = {}
var _setting_specs := {}
var _setting_values := {}

func _init(config: Dictionary = {}, behavior: Script = null, visual: Script = null) -> void:
	if config.is_empty():
		return
	id = String(config.get("id", ""))
	display_name = String(config.get("name", ""))
	color = Color(String(config.get("color", "ffffff")))
	accent = Color(String(config.get("accent", "ffffff")))
	title_color = Color(String(config.get("title_color", config.get("color", "ffffff"))))
	max_hp = float(config.get("max_hp", 100.0))
	speed = float(config.get("speed", 180.0))
	radius = float(config.get("radius", 27.0))
	cooldown = float(config.get("cooldown", 4.0))
	ability_description = String(config.get("ability", ""))
	sound_kind = String(config.get("sound_kind", "impact"))
	sort_order = int(config.get("sort_order", 0))
	ability_script = behavior
	visual_script = visual
	var configured_audio_samples = config.get("audio_samples", {})
	if configured_audio_samples is Dictionary:
		for event_kind in configured_audio_samples:
			_audio_samples[String(event_kind)] = configured_audio_samples[event_kind]
	_register_setting("max_hp", {
		"label": "生命值", "group": "基础属性", "default": max_hp,
		"min": 1.0, "max": 10000.0, "step": 1.0, "kind": "float", "order": 10,
	})
	_register_setting("speed", {
		"label": "移动速度", "group": "基础属性", "default": speed,
		"min": 20.0, "max": 1000.0, "step": 1.0, "kind": "float", "order": 20,
	})
	_register_setting("radius", {
		"label": "本体半径", "group": "基础属性", "default": radius,
		"min": 8.0, "max": 80.0, "step": 1.0, "kind": "float", "order": 30,
	})
	_register_setting("cooldown", {
		"label": "技能冷却", "group": "基础属性", "default": cooldown,
		"min": 0.1, "max": 60.0, "step": 0.05, "kind": "float", "order": 40,
		"suffix": " 秒",
	})
	var tuning: Dictionary = config.get("tuning", {})
	for key in tuning:
		_register_setting(String(key), tuning[key])
	apply_settings({})

func create_ability():
	assert(ability_script != null and ability_script.can_instantiate(), "%s ability script cannot instantiate" % id)
	var ability = ability_script.new()
	ability.configure(self)
	return ability

func create_visual(runtime_ability: BallAbility = null):
	assert(visual_script != null and visual_script.can_instantiate(), "%s visual script cannot instantiate" % id)
	var visual = visual_script.new()
	visual.configure(self, runtime_ability)
	return visual

func fighter_spec() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"color": color,
		"accent": accent,
		"max_hp": max_hp,
		"speed": speed,
		"radius": radius,
		"cooldown": cooldown,
		"minimum_speed": speed,
		"maximum_speed": speed,
	}

func apply_settings(overrides: Dictionary) -> void:
	for key in _setting_specs:
		var spec: Dictionary = _setting_specs[key]
		_setting_values[key] = _normalize_setting_value(spec, overrides.get(key, spec["default"]))
	max_hp = settingf("max_hp")
	speed = settingf("speed")
	radius = settingf("radius")
	cooldown = settingf("cooldown")

func setting(key: String):
	assert(_setting_values.has(key), "%s has no setting %s" % [id, key])
	return _setting_values[key]

func settingf(key: String) -> float:
	return float(setting(key))

func settingi(key: String) -> int:
	return int(setting(key))

func setting_specs() -> Dictionary:
	return _setting_specs.duplicate(true)

func ordered_setting_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in _setting_specs:
		keys.append(String(key))
	keys.sort_custom(func(left: String, right: String) -> bool:
		var left_order := int(_setting_specs[left].get("order", 0))
		var right_order := int(_setting_specs[right].get("order", 0))
		return left_order < right_order if left_order != right_order else left < right
	)
	return keys

func settings_snapshot() -> Dictionary:
	return _setting_values.duplicate(true)

func default_settings_snapshot() -> Dictionary:
	var result := {}
	for key in _setting_specs:
		result[key] = _setting_specs[key]["default"]
	return result

func audio_samples() -> Dictionary:
	return _audio_samples.duplicate()

func _register_setting(key: String, raw_spec) -> void:
	assert(not key.is_empty() and not _setting_specs.has(key), "%s has duplicate setting %s" % [id, key])
	assert(raw_spec is Dictionary, "%s setting %s must be a dictionary" % [id, key])
	var spec: Dictionary = (raw_spec as Dictionary).duplicate(true)
	assert(spec.has("label") and spec.has("default"), "%s setting %s needs label/default" % [id, key])
	spec["group"] = String(spec.get("group", "能力参数"))
	spec["kind"] = String(spec.get("kind", "float"))
	spec["min"] = float(spec.get("min", 0.0))
	spec["max"] = float(spec.get("max", 10000.0))
	spec["step"] = maxf(0.0001, float(spec.get("step", 1.0)))
	spec["order"] = int(spec.get("order", 1000))
	assert(float(spec["max"]) >= float(spec["min"]), "%s setting %s has invalid range" % [id, key])
	spec["default"] = _normalize_setting_value(spec, spec["default"])
	_setting_specs[key] = spec

func _normalize_setting_value(spec: Dictionary, raw_value):
	var numeric := float(spec["default"])
	if raw_value is int or raw_value is float:
		numeric = float(raw_value)
	numeric = clampf(numeric, float(spec["min"]), float(spec["max"]))
	numeric = snappedf(numeric, float(spec["step"]))
	return int(round(numeric)) if String(spec["kind"]) == "int" else numeric

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("module id is empty")
	if display_name.is_empty():
		errors.append("%s display name is empty" % id)
	if max_hp <= 0.0 or speed <= 0.0 or radius <= 0.0 or cooldown <= 0.0:
		errors.append("%s has invalid positive numeric fields" % id)
	if ability_script == null or not ability_script.can_instantiate():
		errors.append("%s has no ability script" % id)
	elif not ability_script.new() is BallAbility:
		errors.append("%s ability script must extend BallAbility" % id)
	if visual_script == null or not visual_script.can_instantiate():
		errors.append("%s has no visual script" % id)
	elif not visual_script.new() is BallVisual:
		errors.append("%s visual script must extend BallVisual" % id)
	for event_kind in _audio_samples:
		if String(event_kind).is_empty():
			errors.append("%s has an empty audio event key" % id)
		elif not _audio_samples[event_kind] is Dictionary:
			errors.append("%s audio event %s must provide a sample specification" % [id, event_kind])
		else:
			var sample_spec: Dictionary = _audio_samples[event_kind]
			if not sample_spec.get("stream") is AudioStream:
				errors.append("%s audio event %s must provide an AudioStream" % [id, event_kind])
			var gain_db = sample_spec.get("gain_db")
			if not (gain_db is int or gain_db is float):
				errors.append("%s audio event %s must provide a numeric gain_db" % [id, event_kind])
			var looped = sample_spec.get("loop", false)
			if not looped is bool:
				errors.append("%s audio event %s loop flag must be boolean" % [id, event_kind])
	return errors
