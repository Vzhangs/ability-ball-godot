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
		"max_hp": 1000.0,
		"speed": 180.0,
		"radius": 27.0,
		"cooldown": 4.0,
		"ability": "测试球没有主动技能、被动技能或撞击伤害，只会按照开局方向移动，撞墙反弹，碰到其他球时彼此弹开。\n\n• 它不会突然反击或释放隐藏能力，适合用作观察其他能力的陪练目标。",
		"sound_kind": "impact",
		"sort_order": 200,
	}, AbilityScript, VisualScript)
