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
var contact_damage := 8.0
var cooldown := 4.0
var ability_description := ""
var sound_kind := "impact"
var sort_order := 0
var ability_script: Script
var visual_script: Script

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
	contact_damage = float(config.get("contact_damage", 8.0))
	cooldown = float(config.get("cooldown", 4.0))
	ability_description = String(config.get("ability", ""))
	sound_kind = String(config.get("sound_kind", "impact"))
	sort_order = int(config.get("sort_order", 0))
	ability_script = behavior
	visual_script = visual

func create_ability():
	assert(ability_script != null and ability_script.can_instantiate(), "%s ability script cannot instantiate" % id)
	var ability = ability_script.new()
	ability.configure(self)
	return ability

func create_visual():
	assert(visual_script != null and visual_script.can_instantiate(), "%s visual script cannot instantiate" % id)
	var visual = visual_script.new()
	visual.configure(self)
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
		"contact_damage": contact_damage,
		"cooldown": cooldown,
	}

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
