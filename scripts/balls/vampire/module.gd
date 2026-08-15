extends BallModule

const AbilityScript := preload("res://scripts/balls/vampire/ability.gd")
const VisualScript := preload("res://scripts/balls/vampire/visual.gd")

func _init() -> void:
	super({
		"id": "vampire",
		"name": "吸血鬼",
		"color": "b80d2b",
		"accent": "ff5267",
		"max_hp": 205.0,
		"speed": 205.0,
		"radius": 28.0,
		"contact_damage": 10.0,
		"cooldown": 4.8,
		"ability": "吸血碰撞 · 血爆回复",
		"sound_kind": "blood",
		"sort_order": 10,
	}, AbilityScript, VisualScript)
