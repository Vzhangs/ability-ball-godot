extends BallModule

const AbilityScript := preload("res://scripts/balls/prime/ability.gd")
const VisualScript := preload("res://scripts/balls/prime/visual.gd")

func _init() -> void:
	super({
		"id": "prime",
		"name": "哥德巴赫球",
		"color": "0d3c5a",
		"accent": "f6c85f",
		"title_color": "ffe3a0",
		"max_hp": 100.0,
		"speed": 205.0,
		"radius": 28.0,
		"cooldown": 4.0,
		"ability": "哥德巴赫球的下一次有效撞击伤害会按素数序列逐步提高。\n\n• 每次成功撞到敌方主球或大型附属单位后，下一击都会继续变强。\n• 没有真正伤到敌人的碰撞不会消耗当前伤害。",
		"sound_kind": "impact",
		"sort_order": 198,
		"tuning": {
			"impact_flash_duration": {
				"label": "撞击闪光持续时间", "group": "视觉表现", "suffix": " 秒",
				"default": 0.32, "min": 0.10, "max": 1.50, "step": 0.02,
				"order": 110,
			},
		},
	}, AbilityScript, VisualScript)
