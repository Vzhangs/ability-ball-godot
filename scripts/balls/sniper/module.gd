extends BallModule

const AbilityScript := preload("res://scripts/balls/sniper/ability.gd")
const VisualScript := preload("res://scripts/balls/sniper/visual.gd")

func _init() -> void:
	super({
		"id": "sniper",
		"name": "狙击球",
		"color": "17242b",
		"accent": "93e6ba",
		"title_color": "c9ffe2",
		"max_hp": 100.0,
		"speed": 178.0,
		"radius": 28.0,
		"cooldown": 5.0,
		"ability": "狙击球会周期性锁定敌方主球，短暂瞄准后沿锁定方向射出高速狙击弹。\n\n• 狙击弹能够打穿分身、植物等附属单位，但每次穿透都会按目标承受的伤害削减剩余威力，威力耗尽后消失。\n• 如果狙击弹没有命中主球而撞上墙壁，就会分裂成向四周散射的小型弹丸。",
		"sound_kind": "sniper_aim",
		"sort_order": 160,
		"tuning": {
			"aim_duration": {
				"label": "瞄准时间", "group": "狙击弹", "suffix": " 秒",
				"default": 1.5, "min": 0.1, "max": 10.0, "step": 0.1, "order": 110,
			},
			"bullet_damage": {
				"label": "狙击弹伤害", "group": "狙击弹",
				"default": 23.0, "min": 0.0, "max": 2000.0, "step": 1.0, "order": 120,
			},
			"bullet_speed": {
				"label": "狙击弹速度", "group": "狙击弹", "suffix": " px/s",
				"default": 500.0, "min": 50.0, "max": 8000.0, "step": 50.0, "order": 130,
			},
			"bullet_radius": {
				"label": "狙击弹判定半径", "group": "狙击弹", "suffix": " px",
				"default": 4.0, "min": 0.5, "max": 30.0, "step": 0.5, "order": 140,
			},
			"bullet_lifetime": {
				"label": "狙击弹最长存在时间", "group": "狙击弹", "suffix": " 秒",
				"default": 2.0, "min": 0.1, "max": 20.0, "step": 0.1, "order": 150,
			},
			"muzzle_distance_multiplier": {
				"label": "枪口距球心倍率", "group": "狙击弹", "suffix": "×半径",
				"default": 3.4, "min": 2.4, "max": 8.0, "step": 0.1, "order": 160,
			},
			"scatter_count": {
				"label": "散弹数量", "group": "撞墙散弹", "kind": "int",
				"default": 24, "min": 1, "max": 64, "step": 1, "order": 210,
			},
			"scatter_damage": {
				"label": "单颗散弹伤害上限", "group": "撞墙散弹",
				"default": 5.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 220,
			},
			"scatter_speed": {
				"label": "散弹速度", "group": "撞墙散弹", "suffix": " px/s",
				"default": 400.0, "min": 20.0, "max": 4000.0, "step": 20.0, "order": 230,
			},
			"scatter_radius": {
				"label": "散弹判定半径", "group": "撞墙散弹", "suffix": " px",
				"default": 2.5, "min": 0.5, "max": 20.0, "step": 0.5, "order": 240,
			},
			"scatter_spread_degrees": {
				"label": "散弹扇面角度", "group": "撞墙散弹", "suffix": "°",
				"default": 360.0, "min": 0.0, "max": 360.0, "step": 5.0, "order": 250,
			},
			"scatter_lifetime": {
				"label": "散弹存在时间", "group": "撞墙散弹", "suffix": " 秒",
				"default": 1.8, "min": 0.1, "max": 15.0, "step": 0.1, "order": 260,
			},
		},
	}, AbilityScript, VisualScript)
