extends BallModule

const AbilityScript := preload("res://scripts/balls/laser/ability.gd")
const VisualScript := preload("res://scripts/balls/laser/visual.gd")

func _init() -> void:
	super({
		"id": "laser",
		"name": "激光球",
		"color": "d3186c",
		"accent": "ff86c4",
		"max_hp": 195.0,
		"speed": 198.0,
		"radius": 26.0,
		"contact_damage": 9.0,
		"cooldown": 4.0,
		"ability": "锁定蓄力 · 穿透光束",
		"sound_kind": "judgment",
		"sort_order": 90,
	}, AbilityScript, VisualScript)
