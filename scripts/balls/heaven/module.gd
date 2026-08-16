extends BallModule

const AbilityScript := preload("res://scripts/balls/heaven/ability.gd")
const VisualScript := preload("res://scripts/balls/heaven/visual.gd")

func _init() -> void:
	super({
		"id": "heaven",
		"name": "天堂球",
		"color": "f5f0cf",
		"accent": "ffd84f",
		"max_hp": 100.0,
		"speed": 225.0,
		"radius": 27.0,
		"cooldown": 4.8,
		"ability": "短暂无敌 · 神圣冲刺",
		"sound_kind": "impact",
		"sort_order": 50,
		"tuning": {
			"invulnerability_duration": {"label": "无敌持续时间", "default": 0.85, "min": 0.0, "max": 20.0, "step": 0.05, "order": 110, "suffix": " 秒"},
			"dash_speed": {"label": "神圣冲刺速度", "default": 540.0, "min": 20.0, "max": 1500.0, "step": 5.0, "order": 120},
			"strike_range": {"label": "冲刺攻击距离", "default": 270.0, "min": 0.0, "max": 900.0, "step": 5.0, "order": 130},
			"strike_damage": {"label": "冲刺攻击伤害", "default": 14.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 140},
			"strike_width": {"label": "冲刺命中宽度", "default": 4.0, "min": 0.0, "max": 100.0, "step": 0.5, "order": 150},
		},
	}, AbilityScript, VisualScript)
