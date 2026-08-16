extends BallModule

const AbilityScript := preload("res://scripts/balls/black_hole/ability.gd")
const VisualScript := preload("res://scripts/balls/black_hole/visual.gd")

func _init() -> void:
	super({
		"id": "black_hole",
		"name": "黑洞球",
		"color": "24123f",
		"accent": "bc63ff",
		"title_color": "9f55e8",
		"max_hp": 225.0,
		"speed": 172.0,
		"radius": 30.0,
		"cooldown": 6.3,
		"ability": "远域捕获敌方附属物 · 原色轨道 · 事件视界吞噬",
		"sound_kind": "judgment",
		"sort_order": 40,
	}, AbilityScript, VisualScript)
