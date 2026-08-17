extends BallModule

const AbilityScript := preload("res://scripts/balls/yuri/ability.gd")
const VisualScript := preload("res://scripts/balls/yuri/visual.gd")

func _init() -> void:
	super({
		"id": "yuri",
		"name": "尤里球",
		"color": "4c205f",
		"accent": "f07cff",
		"title_color": "f7b6ff",
		"max_hp": 100.0,
		"speed": 182.0,
		"radius": 27.0,
		"cooldown": 4.2,
		"ability": "永久夺取非投射附属物并改由自身统率",
		"sound_kind": "psychic_pulse",
		"sort_order": 120,
		"tuning": {
			"control_range": {"label": "心灵控制范围", "group": "心灵控制", "default": 360.0, "min": 20.0, "max": 1000.0, "step": 5.0, "order": 110},
			"max_control_per_cast": {"label": "单次控制数量", "group": "心灵控制", "default": 2, "min": 1, "max": 100, "step": 1, "kind": "int", "order": 120},
			"max_controlled_total": {"label": "控制总数上限", "group": "心灵控制", "default": 18, "min": 1, "max": 300, "step": 1, "kind": "int", "order": 130},
			"controlled_velocity_multiplier": {"label": "倒戈速度倍率", "group": "心灵控制", "default": 1.05, "min": 0.1, "max": 5.0, "step": 0.05, "order": 140},
			"control_backlash_damage": {"label": "夺取反噬伤害", "group": "心灵控制", "default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 150},
			"pulse_duration": {"label": "精神波持续时间", "group": "视觉表现", "default": 0.72, "min": 0.1, "max": 5.0, "step": 0.05, "order": 310, "suffix": " 秒"},
			"link_duration": {"label": "控制链持续时间", "group": "视觉表现", "default": 0.55, "min": 0.1, "max": 5.0, "step": 0.05, "order": 320, "suffix": " 秒"},
		},
	}, AbilityScript, VisualScript)
