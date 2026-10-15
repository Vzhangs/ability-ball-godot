extends BallModule

const AbilityScript := preload("res://scripts/balls/wdc/ability.gd")
const VisualScript := preload("res://scripts/balls/wdc/visual.gd")

func _init() -> void:
	super({
		"id": "wdc",
		"name": "WDC",
		"color": "282457",
		"accent": "6de5ff",
		"title_color": "c6f7ff",
		"max_hp": 100.0,
		"speed": 210.0,
		"radius": 27.0,
		"cooldown": 8.0,
		"ability": "WDC 会周期性把竞技场划分为九宫格，每格获得一个随机伤害值，并且高伤害格更罕见。\n\n• 技能期间，WDC 在哪一格撞到敌方主球或附属单位，就造成该格对应的伤害。\n• 九宫格结束后，WDC 的普通碰撞不再造成伤害。",
		"sound_kind": "judgment",
		"sort_order": 140,
		"tuning": {
			"skill_duration": {
				"label": "九宫格持续时间", "group": "地图改写",
				"default": 5.0, "min": 0.1, "max": 30.0, "step": 0.1,
				"order": 110, "suffix": " 秒",
			},
			"damage_max": {
				"label": "九宫格伤害上限", "group": "伤害分布",
				"default": 50, "min": 0, "max": 500, "step": 1,
				"kind": "int", "order": 210,
			},
			"weight_0_10": {
				"label": "0～10 权重", "group": "伤害分布",
				"default": 8.0, "min": 0.0, "max": 100.0, "step": 0.1,
				"order": 220,
			},
			"weight_11_20": {
				"label": "11～20 权重", "group": "伤害分布",
				"default": 6.0, "min": 0.0, "max": 100.0, "step": 0.1,
				"order": 230,
			},
			"weight_21_30": {
				"label": "21～30 权重", "group": "伤害分布",
				"default": 4.0, "min": 0.0, "max": 100.0, "step": 0.1,
				"order": 240,
			},
			"weight_31_40": {
				"label": "31～40 权重", "group": "伤害分布",
				"default": 2.0, "min": 0.0, "max": 100.0, "step": 0.1,
				"order": 250,
			},
			"weight_41_50": {
				"label": "41～50 权重", "group": "伤害分布",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1,
				"order": 260,
			},
			"grid_fade_duration": {
				"label": "地图淡入淡出时间", "group": "视觉表现",
				"default": 0.35, "min": 0.05, "max": 3.0, "step": 0.05,
				"order": 310, "suffix": " 秒",
			},
			"cast_icon_duration": {
				"label": "施法图标持续时间", "group": "视觉表现",
				"default": 0.72, "min": 0.1, "max": 3.0, "step": 0.05,
				"order": 320, "suffix": " 秒",
			},
		},
	}, AbilityScript, VisualScript)
