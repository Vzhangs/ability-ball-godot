extends BallModule

const AbilityScript := preload("res://scripts/balls/vampire/ability.gd")
const VisualScript := preload("res://scripts/balls/vampire/visual.gd")

func _init() -> void:
	super({
		"id": "vampire",
		"name": "吸血鬼",
		"color": "8f0b27",
		"accent": "ff3858",
		"title_color": "ff8294",
		"max_hp": 100.0,
		"speed": 205.0,
		"radius": 28.0,
		"cooldown": 8.0,
		"ability": "吸血鬼会周期性远程吸取敌人的生命并转化为自身生命，治疗能够突破原本生命上限。\n\n• 与敌方主球或大型附属单位相撞时，会把目标暂时吸住；吸血鬼在此期间无敌并反复吸取生命。\n• 贴身吸血结束后，双方会被强制弹开。\n• 地形不属于吸血目标，不会被吸附拖拽，也不能为吸血鬼提供生命。",
		"sound_kind": "blood",
		"sort_order": 10,
		"tuning": {
			"remote_drain_damage": {"label": "血线抽血伤害", "group": "血线抽取", "default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 110},
			"remote_heal_ratio": {"label": "血线治疗比例", "group": "血线抽取", "default": 1.0, "min": 0.0, "max": 5.0, "step": 0.05, "order": 120},
			"remote_strand_count": {"label": "血线数量", "group": "血线抽取", "default": 4, "min": 2, "max": 12, "step": 1, "kind": "int", "order": 130},
			"remote_travel_duration": {"label": "血线生长时间", "group": "血线抽取", "default": 0.35, "min": 0.1, "max": 4.0, "step": 0.05, "order": 140, "suffix": " 秒"},
			"remote_strand_stagger": {"label": "血线错峰间隔", "group": "血线抽取", "default": 0.07, "min": 0.0, "max": 0.5, "step": 0.01, "order": 150, "suffix": " 秒"},
			"remote_suction_duration": {"label": "血线回收时间", "group": "血线抽取", "default": 0.3, "min": 0.1, "max": 3.0, "step": 0.02, "order": 160, "suffix": " 秒"},
			"latch_duration": {"label": "碰撞吸附时间", "group": "碰撞吸附", "default": 2.0, "min": 0.1, "max": 10.0, "step": 0.1, "order": 210, "suffix": " 秒"},
			"latch_drain_interval": {"label": "吸附抽血间隔", "group": "碰撞吸附", "default": 0.6, "min": 0.1, "max": 5.0, "step": 0.05, "order": 220, "suffix": " 秒"},
			"latch_drain_damage": {"label": "每次吸附伤害", "group": "碰撞吸附", "default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 230},
			"latch_heal_ratio": {"label": "吸附治疗比例", "group": "碰撞吸附", "default": 1.0, "min": 0.0, "max": 5.0, "step": 0.05, "order": 240},
			"latch_gap": {"label": "吸附贴合间距", "group": "碰撞吸附", "default": 1.5, "min": 0.0, "max": 40.0, "step": 0.5, "order": 250},
			"latch_release_speed": {"label": "吸完弹开速度", "group": "碰撞吸附", "default": 250.0, "min": 0.0, "max": 1200.0, "step": 10.0, "order": 260},
			"latch_release_duration": {"label": "弹开保持时间", "group": "碰撞吸附", "default": 0.22, "min": 0.02, "max": 2.0, "step": 0.02, "order": 270, "suffix": " 秒"},
		},
	}, AbilityScript, VisualScript)
