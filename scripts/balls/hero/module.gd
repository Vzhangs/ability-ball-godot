extends BallModule

const AbilityScript := preload("res://scripts/balls/hero/ability.gd")
const VisualScript := preload("res://scripts/balls/hero/visual.gd")

func _init() -> void:
	super({
		"id": "hero",
		"name": "勇者球",
		"color": "2455a6",
		"accent": "ffd86a",
		"title_color": "ffe7a3",
		"max_hp": 100.0,
		"speed": 185.0,
		"radius": 25.0,
		"cooldown": 4.0,
		"ability": "勇者球会不断让竞技场出现随机属性泡泡，只有生成泡泡的勇者球能够拾取并永久获得对应强化。\n\n• 翅膀泡泡提高移动速度，生命泡泡扩充生命上限。\n• 剑刃泡泡强化撞击，爱心泡泡赋予持续恢复能力。\n• 没有及时拾取的泡泡会暂时留在场上；黑洞可以抢先吞掉它们，尤里球无法控制它们。",
		"sound_kind": "track",
		"sort_order": 195,
		"tuning": {
			"max_bubbles": {
				"label": "场上泡泡上限", "group": "属性泡泡", "kind": "int",
				"default": 12, "min": 1, "max": 100, "step": 1, "order": 110,
			},
			"bubble_radius": {
				"label": "泡泡拾取半径", "group": "属性泡泡", "suffix": " px",
				"default": 17.0, "min": 6.0, "max": 60.0, "step": 1.0, "order": 120,
			},
			"pickup_icon_duration": {
				"label": "拾取图标持续时间", "group": "属性泡泡", "suffix": " 秒",
				"default": 0.75, "min": 0.1, "max": 3.0, "step": 0.05, "order": 130,
			},
			"speed_spawn_probability": {
				"label": "加速泡泡刷新概率", "group": "刷新概率", "suffix": "%",
				"default": 25.0, "min": 0.0, "max": 100.0, "step": 1.0, "order": 210,
				"tooltip": "四类概率按相对值自动归一化，不要求总和恰好为 100%。",
			},
			"max_hp_spawn_probability": {
				"label": "生命泡泡刷新概率", "group": "刷新概率", "suffix": "%",
				"default": 25.0, "min": 0.0, "max": 100.0, "step": 1.0, "order": 220,
				"tooltip": "四类概率按相对值自动归一化，不要求总和恰好为 100%。",
			},
			"impact_spawn_probability": {
				"label": "攻击泡泡刷新概率", "group": "刷新概率", "suffix": "%",
				"default": 25.0, "min": 0.0, "max": 100.0, "step": 1.0, "order": 230,
				"tooltip": "四类概率按相对值自动归一化，不要求总和恰好为 100%。",
			},
			"regen_spawn_probability": {
				"label": "秒回泡泡刷新概率", "group": "刷新概率", "suffix": "%",
				"default": 25.0, "min": 0.0, "max": 100.0, "step": 1.0, "order": 240,
				"tooltip": "四类概率按相对值自动归一化，不要求总和恰好为 100%。",
			},
			"speed_bonus_ratio": {
				"label": "每层速度加成比例", "group": "属性加成",
				"default": 0.20, "min": 0.0, "max": 5.0, "step": 0.01, "order": 310,
				"tooltip": "0.20 表示每个加速泡泡让基础速度增加 20%，同类泡泡按基础速度累加。",
			},
			"max_hp_bonus": {
				"label": "每层生命上限加成", "group": "属性加成",
				"default": 10.0, "min": 0.0, "max": 1000.0, "step": 1.0, "order": 320,
			},
			"initial_impact_damage": {
				"label": "初始撞击攻击力", "group": "属性加成",
				"default": 3.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 325,
			},
			"impact_damage_bonus": {
				"label": "每层撞击攻击加成", "group": "属性加成",
				"default": 3.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 330,
			},
			"regen_per_second": {
				"label": "每层每秒回复", "group": "属性加成",
				"default": 0.5, "min": 0.0, "max": 500.0, "step": 0.5, "order": 340,
			},
			"regen_tick_interval": {
				"label": "自动回复间隔", "group": "属性加成", "suffix": " 秒",
				"default": 2.0, "min": 0.1, "max": 10.0, "step": 0.1, "order": 350,
			},
		},
	}, AbilityScript, VisualScript)
