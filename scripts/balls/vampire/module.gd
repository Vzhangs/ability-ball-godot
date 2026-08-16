extends BallModule

const AbilityScript := preload("res://scripts/balls/vampire/ability.gd")
const VisualScript := preload("res://scripts/balls/vampire/visual.gd")

func _init() -> void:
	super({
		"id": "vampire",
		"name": "吸血鬼",
		"color": "b80d2b",
		"accent": "ff5267",
		"max_hp": 100.0,
		"speed": 205.0,
		"radius": 28.0,
		"cooldown": 4.8,
		"ability": "吸血碰撞 · 血爆回复",
		"sound_kind": "blood",
		"sort_order": 10,
		"tuning": {
			"burst_radius": {"label": "血爆半径", "default": 155.0, "min": 20.0, "max": 500.0, "step": 1.0, "order": 110},
			"burst_damage": {"label": "血爆伤害", "default": 14.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 120},
			"burst_heal": {"label": "血爆治疗", "default": 12.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 130},
			"body_impact_damage": {"label": "本体撞击伤害", "default": 11.25, "min": 0.0, "max": 500.0, "step": 0.25, "order": 140},
			"impact_lifesteal_ratio": {"label": "撞击吸血比例", "default": 0.34, "min": 0.0, "max": 2.0, "step": 0.01, "order": 150},
		},
	}, AbilityScript, VisualScript)
