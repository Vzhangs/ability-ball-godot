extends BallModule

const AbilityScript := preload("res://scripts/balls/hammer/ability.gd")
const VisualScript := preload("res://scripts/balls/hammer/visual.gd")

func _init() -> void:
	super({
		"id": "hammer",
		"name": "锤子球",
		"color": "8c5b32",
		"accent": "e8d6bd",
		"max_hp": 100.0,
		"speed": 165.0,
		"radius": 31.0,
		"cooldown": 1.15,
		"ability": "旋转长锤 · 范围重击",
		"sound_kind": "track",
		"sort_order": 80,
		"tuning": {
			"orbit_speed": {"label": "锤头旋转速度", "default": 2.56, "min": 0.0, "max": 20.0, "step": 0.05, "order": 110},
			"hammer_reach": {"label": "锤柄长度", "default": 118.0, "min": 20.0, "max": 400.0, "step": 1.0, "order": 120},
			"hammer_hit_radius": {"label": "锤头命中半径", "default": 48.0, "min": 1.0, "max": 200.0, "step": 1.0, "order": 130},
			"sweep_range": {"label": "横扫命中距离", "default": 158.0, "min": 1.0, "max": 500.0, "step": 1.0, "order": 140},
			"hammer_damage": {"label": "重击伤害", "default": 14.2, "min": 0.0, "max": 500.0, "step": 0.2, "order": 150},
		},
	}, AbilityScript, VisualScript)
