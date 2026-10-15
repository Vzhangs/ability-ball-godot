extends BallModule

const AbilityScript := preload("res://scripts/balls/plant/ability.gd")
const VisualScript := preload("res://scripts/balls/plant/visual.gd")

func _init() -> void:
	super({
		"id": "plant",
		"name": "植物球",
		"color": "39f05f",
		"accent": "d8ff67",
		"title_color": "83ff73",
		"max_hp": 100.0,
		"speed": 182.0,
		"radius": 27.0,
		"cooldown": 4.5,
		"ability": "植物球会周期性在脚下种下种子，成熟后随机长成火豌豆、冰豌豆、机枪豌豆或向日葵；种子阶段不会受伤，但能被控制或吞噬。\n\n• 火豌豆会附加灼烧，冰豌豆会施加不能叠加的减速，机枪豌豆会快速连射。\n• 向日葵会把阳光送到场地中，同阵营任意主球拾取后都能恢复生命。\n• 成熟植物能够挡路、挡子弹，也能伤害敌方主球与附属单位，但自身同样可以被消灭。",
		"sound_kind": "track",
		"sort_order": 130,
		"tuning": {
			"max_plants": {"label": "植物数量上限", "group": "种植与成长", "default": 12, "min": 1, "max": 100, "step": 1, "kind": "int", "order": 110},
			"seed_radius": {"label": "种子半径", "group": "种植与成长", "default": 9.0, "min": 3.0, "max": 40.0, "step": 1.0, "order": 120},
			"plant_max_hp": {"label": "成熟植物生命值", "group": "种植与成长", "default": 10.0, "min": 1.0, "max": 1000.0, "step": 1.0, "order": 130},
			"plant_radius": {"label": "成熟植物半径", "group": "种植与成长", "default": 17.0, "min": 5.0, "max": 60.0, "step": 1.0, "order": 140},
			"growth_delay": {"label": "种子发育时间", "group": "种植与成长", "default": 4.0, "min": 0.1, "max": 60.0, "step": 0.1, "order": 150, "suffix": " 秒"},
			"sunflower_growth_weight": {"label": "向日葵发育权重", "group": "种植与成长", "default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 160},
			"fire_pea_growth_weight": {"label": "火豌豆发育权重", "group": "种植与成长", "default": 2.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 170},
			"ice_pea_growth_weight": {"label": "冰豌豆发育权重", "group": "种植与成长", "default": 2.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 180},
			"gatling_pea_growth_weight": {"label": "机关枪豌豆发育权重", "group": "种植与成长", "default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 190},
			"plant_contact_damage": {"label": "成熟植物接触伤害", "group": "成熟植物碰撞", "default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 210},
			"plant_contact_interval": {"label": "成熟植物接触间隔", "group": "成熟植物碰撞", "default": 0.32, "min": 0.05, "max": 5.0, "step": 0.01, "order": 220, "suffix": " 秒"},

			"fire_fire_interval": {"label": "火豌豆射击间隔", "group": "火豌豆射手", "default": 3.0, "min": 0.1, "max": 30.0, "step": 0.1, "order": 310, "suffix": " 秒"},
			"fire_pea_damage": {"label": "火豌豆命中伤害", "group": "火豌豆射手", "default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 320},
			"fire_burn_damage": {"label": "燃烧每跳伤害", "group": "火豌豆射手", "default": 1.0, "min": 0.0, "max": 500.0, "step": 0.1, "order": 330},
			"fire_burn_tick_interval": {"label": "燃烧伤害间隔", "group": "火豌豆射手", "default": 1.0, "min": 0.1, "max": 30.0, "step": 0.1, "order": 340, "suffix": " 秒"},
			"fire_burn_duration": {"label": "燃烧持续时间", "group": "火豌豆射手", "default": 4.0, "min": 0.1, "max": 60.0, "step": 0.1, "order": 350, "suffix": " 秒"},

			"ice_fire_interval": {"label": "冰豌豆射击间隔", "group": "冰豌豆射手", "default": 3.0, "min": 0.1, "max": 30.0, "step": 0.1, "order": 410, "suffix": " 秒"},
			"ice_pea_damage": {"label": "冰豌豆命中伤害", "group": "冰豌豆射手", "default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 420},
			"ice_slow_multiplier": {"label": "冰豌豆速度倍率", "group": "冰豌豆射手", "default": 0.65, "min": 0.1, "max": 1.0, "step": 0.01, "order": 430},
			"ice_slow_duration": {"label": "冰冻减速时间", "group": "冰豌豆射手", "default": 2.5, "min": 0.1, "max": 30.0, "step": 0.1, "order": 440, "suffix": " 秒"},

			"gatling_fire_interval": {"label": "机关枪射击间隔", "group": "机关枪豌豆", "default": 0.3, "min": 0.08, "max": 10.0, "step": 0.01, "order": 510, "suffix": " 秒"},
			"gatling_pea_damage": {"label": "机关枪单发伤害", "group": "机关枪豌豆", "default": 1.0, "min": 0.0, "max": 500.0, "step": 0.1, "order": 520},

			"pea_projectile_speed": {"label": "豌豆飞行速度", "group": "豌豆弹丸", "default": 310.0, "min": 10.0, "max": 2000.0, "step": 5.0, "order": 610},
			"pea_projectile_radius": {"label": "豌豆弹丸半径", "group": "豌豆弹丸", "default": 4.5, "min": 1.0, "max": 30.0, "step": 0.5, "order": 620},
			"pea_projectile_lifetime": {"label": "豌豆弹丸寿命", "group": "豌豆弹丸", "default": 3.0, "min": 0.1, "max": 20.0, "step": 0.1, "order": 630, "suffix": " 秒"},
			"pea_projectile_spread": {"label": "豌豆散布角", "group": "豌豆弹丸", "default": 0.045, "min": 0.0, "max": 1.5, "step": 0.005, "order": 640},
			"projectile_spawn_gap": {"label": "弹丸出生间距", "group": "豌豆弹丸", "default": 2.0, "min": 0.0, "max": 100.0, "step": 0.5, "order": 650},
			"projectile_boundary_padding": {"label": "弹丸越界余量", "group": "豌豆弹丸", "default": 20.0, "min": 0.0, "max": 300.0, "step": 1.0, "order": 660},

			"sun_launch_interval": {"label": "阳光抛出间隔", "group": "向日葵", "default": 8.0, "min": 0.1, "max": 60.0, "step": 0.1, "order": 710, "suffix": " 秒"},
			"sun_travel_duration": {"label": "阳光飞行时间", "group": "向日葵", "default": 1.2, "min": 0.1, "max": 10.0, "step": 0.1, "order": 720, "suffix": " 秒"},
			"sun_arc_height": {"label": "阳光抛物线高度", "group": "向日葵", "default": 55.0, "min": 0.0, "max": 500.0, "step": 5.0, "order": 730},
			"sun_pickup_heal": {"label": "阳光拾取回复量", "group": "向日葵", "default": 10.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 740},
			"sun_pickup_radius": {"label": "阳光拾取半径", "group": "向日葵", "default": 10.0, "min": 3.0, "max": 50.0, "step": 1.0, "order": 750},
			"sun_pickup_lifetime": {"label": "阳光落地停留时间", "group": "向日葵", "default": 18.0, "min": 1.0, "max": 120.0, "step": 1.0, "order": 760, "suffix": " 秒"},
			"sun_pickup_margin": {"label": "阳光落点边界间距", "group": "向日葵", "default": 18.0, "min": 0.0, "max": 200.0, "step": 1.0, "order": 770},

			"planting_icon_duration": {"label": "种植图标持续时间", "group": "视觉表现", "default": 0.7, "min": 0.1, "max": 5.0, "step": 0.05, "order": 810, "suffix": " 秒"},
			"growth_animation_duration": {"label": "成长动画时间", "group": "视觉表现", "default": 0.6, "min": 0.1, "max": 5.0, "step": 0.05, "order": 820, "suffix": " 秒"},
		},
	}, AbilityScript, VisualScript)
