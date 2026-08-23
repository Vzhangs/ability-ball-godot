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
		"ability": "撞墙结网 · 越线触发伤害",
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
