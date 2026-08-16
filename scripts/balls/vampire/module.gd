extends BallModule

const AbilityScript := preload("res://scripts/balls/vampire/ability.gd")
const VisualScript := preload("res://scripts/balls/vampire/visual.gd")
const ShowcaseAbilityScript := preload("res://scripts/balls/vampire/showcase_ability.gd")

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
			"showcase_speed": {"label": "展示档移动速度", "group": "展示档", "default": 155.0, "min": 20.0, "max": 1000.0, "step": 1.0, "order": 510},
			"showcase_max_speed": {"label": "展示档最高速度", "group": "展示档", "default": 470.0, "min": 20.0, "max": 1500.0, "step": 1.0, "order": 520},
			"showcase_radius": {"label": "展示档本体半径", "group": "展示档", "default": 31.0, "min": 8.0, "max": 80.0, "step": 1.0, "order": 530},
			"showcase_dash_initial_delay": {"label": "首次冲刺延迟", "group": "展示档", "default": 2.6, "min": 0.0, "max": 30.0, "step": 0.1, "order": 540, "suffix": " 秒"},
			"showcase_dash_interval": {"label": "冲刺间隔", "group": "展示档", "default": 3.6, "min": 0.1, "max": 30.0, "step": 0.1, "order": 550, "suffix": " 秒"},
			"showcase_dash_speed": {"label": "冲刺速度", "group": "展示档", "default": 446.0, "min": 20.0, "max": 1500.0, "step": 1.0, "order": 560},
			"showcase_dash_spread": {"label": "冲刺方向随机角", "group": "展示档", "default": 0.16, "min": 0.0, "max": 1.5, "step": 0.01, "order": 565},
			"showcase_burst_initial_delay": {"label": "首次血爆延迟", "group": "展示档", "default": 5.4, "min": 0.0, "max": 30.0, "step": 0.1, "order": 570, "suffix": " 秒"},
			"showcase_burst_interval": {"label": "血爆间隔", "group": "展示档", "default": 5.5, "min": 0.1, "max": 30.0, "step": 0.1, "order": 580, "suffix": " 秒"},
			"showcase_burst_radius": {"label": "血爆半径", "group": "展示档", "default": 142.0, "min": 20.0, "max": 500.0, "step": 1.0, "order": 590},
			"showcase_burst_damage": {"label": "血爆伤害", "group": "展示档", "default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 600},
			"showcase_burst_heal": {"label": "血爆治疗", "group": "展示档", "default": 9.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 610},
			"showcase_impact_damage": {"label": "本体撞击伤害", "group": "展示档", "default": 5.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 620},
			"showcase_impact_heal": {"label": "每次撞击治疗", "group": "展示档", "default": 3.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 630},
		},
	}, AbilityScript, VisualScript)
	register_profile("showcase", {}, ShowcaseAbilityScript, null, {
		"speed": "showcase_speed",
		"minimum_speed": "showcase_speed",
		"maximum_speed": "showcase_max_speed",
		"radius": "showcase_radius",
	})
