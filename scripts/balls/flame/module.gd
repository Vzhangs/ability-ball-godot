extends BallModule

const AbilityScript := preload("res://scripts/balls/flame/ability.gd")
const VisualScript := preload("res://scripts/balls/flame/visual.gd")

func _init() -> void:
	super({
		"id": "flame",
		"name": "火焰球",
		"color": "e04416",
		"accent": "ffd052",
		"max_hp": 195.0,
		"speed": 208.0,
		"radius": 27.0,
		"cooldown": 3.8,
		"ability": "灼烧轨迹 · 烈焰爆发",
		"sound_kind": "blood",
		"sort_order": 100,
	}, AbilityScript, VisualScript)
