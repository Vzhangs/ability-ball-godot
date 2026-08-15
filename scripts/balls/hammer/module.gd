extends BallModule

const AbilityScript := preload("res://scripts/balls/hammer/ability.gd")
const VisualScript := preload("res://scripts/balls/hammer/visual.gd")

func _init() -> void:
	super({
		"id": "hammer",
		"name": "锤子球",
		"color": "8c5b32",
		"accent": "e8d6bd",
		"max_hp": 215.0,
		"speed": 165.0,
		"radius": 31.0,
		"contact_damage": 11.0,
		"cooldown": 1.15,
		"ability": "旋转长锤 · 范围重击",
		"sound_kind": "track",
		"sort_order": 80,
	}, AbilityScript, VisualScript)
