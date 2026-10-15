extends BallModule

const AbilityScript := preload("res://scripts/balls/spider_web/ability.gd")
const VisualScript := preload("res://scripts/balls/spider_web/visual.gd")

func _init() -> void:
	super({
		"id": "spider_web",
		"name": "蜘蛛网",
		"color": "241c38",
		"accent": "d8f6ff",
		"title_color": "e8fbff",
		"max_hp": 100.0,
		"speed": 192.0,
		"radius": 27.0,
		"cooldown": 1.0,
		"ability": "蜘蛛网每次撞墙都会把真实撞墙点和自己连成一根永久蛛丝，蛛丝的一端固定在墙面，另一端跟着蜘蛛网移动。\n\n• 敌方主球或附属单位被蛛丝扫过时会受到伤害；持续压在同一根线上不会连续掉血，完全离开后再次穿过才会重新受伤。\n• 黑洞可以把蛛丝从两端扯断并吞噬。",
		"sound_kind": "web_attach",
		"sort_order": 150,
		"tuning": {
			"web_damage": {
				"label": "单根蛛丝触发伤害",
				"group": "永久蛛丝",
				"default": 1.0,
				"min": 0.0,
				"max": 1000.0,
				"step": 0.5,
				"order": 110,
			},
			"web_collision_half_width": {
				"label": "蛛丝判定半宽",
				"group": "永久蛛丝",
				"default": 2.5,
				"min": 0.0,
				"max": 80.0,
				"step": 0.5,
				"order": 120,
				"suffix": " px",
			},
		},
	}, AbilityScript, VisualScript)
