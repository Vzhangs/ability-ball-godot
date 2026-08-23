extends BallModule

const AbilityScript := preload("res://scripts/balls/test_ball/ability.gd")
const VisualScript := preload("res://scripts/balls/test_ball/visual.gd")

func _init() -> void:
	super({
		"id": "test_ball",
		"name": "测试球",
		"color": "778493",
		"accent": "d9e2eb",
		"title_color": "d9e2eb",
		"max_hp": 100.0,
		"speed": 180.0,
		"radius": 27.0,
		"cooldown": 4.0,
		"ability": "无特殊能力 · 仅基础属性",
		"sound_kind": "impact",
		"sort_order": 200,
	}, AbilityScript, VisualScript)
