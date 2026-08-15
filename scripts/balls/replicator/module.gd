extends BallModule

const AbilityScript := preload("res://scripts/balls/replicator/ability.gd")
const VisualScript := preload("res://scripts/balls/replicator/visual.gd")

func _init() -> void:
	super({
		"id": "replicator",
		"name": "复制器",
		"color": "26a883",
		"accent": "83ffd9",
		"max_hp": 220.0,
		"speed": 185.0,
		"radius": 27.0,
		"contact_damage": 9.0,
		"cooldown": 3.0,
		"ability": "复制镜像 · 齐射弹幕",
		"sound_kind": "track",
		"sort_order": 70,
	}, AbilityScript, VisualScript)
