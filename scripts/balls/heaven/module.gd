extends BallModule

const AbilityScript := preload("res://scripts/balls/heaven/ability.gd")
const VisualScript := preload("res://scripts/balls/heaven/visual.gd")

func _init() -> void:
	super({
		"id": "heaven",
		"name": "天堂球",
		"color": "f5f0cf",
		"accent": "ffd84f",
		"max_hp": 180.0,
		"speed": 225.0,
		"radius": 27.0,
		"cooldown": 4.8,
		"ability": "短暂无敌 · 神圣冲刺",
		"sound_kind": "impact",
		"sort_order": 50,
	}, AbilityScript, VisualScript)
