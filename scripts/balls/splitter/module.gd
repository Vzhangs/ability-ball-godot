extends BallModule

const AbilityScript := preload("res://scripts/balls/splitter/ability.gd")
const VisualScript := preload("res://scripts/balls/splitter/visual.gd")

func _init() -> void:
	super({
		"id": "splitter",
		"name": "分裂球",
		"color": "4fd0e8",
		"accent": "b9f8ff",
		"max_hp": 210.0,
		"speed": 192.0,
		"radius": 27.0,
		"cooldown": 3.5,
		"ability": "百体分裂 · 独立撞击",
		"sound_kind": "impact",
		"sort_order": 30,
	}, AbilityScript, VisualScript)
