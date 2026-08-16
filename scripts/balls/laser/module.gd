extends BallModule

const AbilityScript := preload("res://scripts/balls/laser/ability.gd")
const VisualScript := preload("res://scripts/balls/laser/visual.gd")

func _init() -> void:
	super({
		"id": "laser",
		"name": "激光球",
		"color": "d3186c",
		"accent": "ff86c4",
		"max_hp": 100.0,
		"speed": 198.0,
		"radius": 26.0,
		"cooldown": 4.0,
		"ability": "锁定蓄力 · 穿透光束",
		"sound_kind": "judgment",
		"sort_order": 90,
		"tuning": {
			"laser_damage": {"label": "激光伤害", "default": 20.6, "min": 0.0, "max": 1000.0, "step": 0.2, "order": 110},
			"laser_hit_width": {"label": "激光命中宽度", "default": 5.0, "min": 0.0, "max": 100.0, "step": 0.5, "order": 120},
		},
	}, AbilityScript, VisualScript)
