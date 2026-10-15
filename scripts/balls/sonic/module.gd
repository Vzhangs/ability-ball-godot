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
		"speed": 220.0,
		"radius": 25.0,
		"cooldown": 1.6,
		"ability": "音速球会周期性同步提升速度与撞击伤害，已经获得的加速会保留到对局结束。它的伤害只取决于累计的加速次数，不受某次碰撞的瞬时速度影响。\n\n• 每次加速都会让后续撞击继续变强。\n• 冲撞既能伤害敌方主球，也能撞伤具备实体碰撞能力的敌方附属单位。",
		"sound_kind": "impact",
		"sort_order": 60,
		"tuning": {
			"speed_growth_ratio": {"label": "每次速度增长比例", "default": 0.07, "min": 0.0, "max": 5.0, "step": 0.01, "order": 110, "tooltip": "按技能冷却间隔复利叠加；默认每 1.6 秒把当前目标速度乘以 1.07。"},
			"body_impact_damage": {"label": "初始撞击伤害", "default": 3.0, "min": 0.0, "max": 500.0, "step": 0.25, "order": 120, "tooltip": "技能尚未发动时的撞击伤害；之后只按累计加速倍率同比增长，不受碰撞瞬时速度影响。"},
		},
	}, AbilityScript, VisualScript)
