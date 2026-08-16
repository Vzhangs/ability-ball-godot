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
var _profiles := {}

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

func create_ability():
	return create_profile_ability("default")

func create_profile_ability(profile: String = "default"):
	var selected_script: Script = ability_script
	if profile != "default":
		assert(_profiles.has(profile), "%s has no profile %s" % [id, profile])
		selected_script = _profiles[profile]["ability"] as Script
	assert(selected_script != null and selected_script.can_instantiate(), "%s/%s ability script cannot instantiate" % [id, profile])
	var ability = selected_script.new()
	ability.configure(self)
	return ability

func create_visual(runtime_ability: BallAbility = null, profile: String = "default"):
	var selected_script: Script = visual_script
	if profile != "default":
		assert(_profiles.has(profile), "%s has no profile %s" % [id, profile])
		selected_script = _profiles[profile]["visual"] as Script
	assert(selected_script != null and selected_script.can_instantiate(), "%s/%s visual script cannot instantiate" % [id, profile])
	var visual = selected_script.new()
	visual.configure(self, runtime_ability)
	return visual

func fighter_spec(profile: String = "default") -> Dictionary:
	var result := {
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
	if profile != "default":
		assert(_profiles.has(profile), "%s has no profile %s" % [id, profile])
		result.merge(_profiles[profile]["fighter"], true)
	return result

func register_profile(profile: String, fighter_overrides: Dictionary, behavior: Script, visual: Script = null) -> void:
	assert(not profile.is_empty() and profile != "default", "Custom ball profile requires a non-default name")
	_profiles[profile] = {
		"fighter": fighter_overrides.duplicate(true),
		"ability": behavior,
		"visual": visual if visual != null else visual_script,
	}

func has_profile(profile: String) -> bool:
	return profile == "default" or _profiles.has(profile)

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
	return errors
