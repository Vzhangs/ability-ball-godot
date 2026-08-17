extends BallModule

const AbilityScript := preload("res://scripts/balls/sonic/ability.gd")
const VisualScript := preload("res://scripts/balls/sonic/visual.gd")

func _init() -> void:
	super({
		"id": "sonic",
		"name": "音速球",
		"color": "1677dc",
		"accent": "73e7ff",
		"max_hp": 100.0,
		"speed": 260.0,
		"radius": 25.0,
		"cooldown": 1.0,
		"ability": "每秒加速 10% · 速度转化撞击伤害",
		"sound_kind": "impact",
		"sort_order": 60,
		"tuning": {
			"speed_growth_ratio": {"label": "每次速度增长比例", "default": 0.10, "min": 0.0, "max": 5.0, "step": 0.01, "order": 110, "tooltip": "按技能冷却间隔复利叠加；默认每 1 秒把当前目标速度乘以 1.10。"},
			"body_impact_damage": {"label": "初速撞击伤害", "default": 12.25, "min": 0.0, "max": 500.0, "step": 0.25, "order": 120, "tooltip": "处于初始速度时的撞击伤害；实际伤害会按实时速度同比增长。"},
		},
	}, AbilityScript, VisualScript)
