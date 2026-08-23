extends BallModule

const AbilityScript := preload("res://scripts/balls/garen/ability.gd")
const VisualScript := preload("res://scripts/balls/garen/visual.gd")
const SwordHitSound := preload("res://scripts/balls/garen/audio/sword_hit.ogg")
const SpinWhooshSound := preload("res://scripts/balls/garen/audio/spin_whoosh.ogg")

func _init() -> void:
	super({
		"id": "garen",
		"name": "盖伦球",
		"color": "214f9c",
		"accent": "f3c969",
		"title_color": "ffe49a",
		"max_hp": 100.0,
		"speed": 175.0,
		"radius": 31.0,
		"cooldown": 6.0,
		"ability": "常驻长剑 · 离剑重置触伤 · 剑刃旋转",
		"sound_kind": "garen_spin_whoosh",
		"audio_samples": {
			"garen_sword_hit": {
				"stream": SwordHitSound,
				"gain_db": -10.0,
			},
			"garen_spin_whoosh": {
				"stream": SpinWhooshSound,
				"gain_db": -10.0,
				"loop": true,
			},
		},
		"sort_order": 180,
		"tuning": {
			"sword_length": {
				"label": "剑刃长度", "group": "长剑", "suffix": " px",
				"default": 110.0, "min": 20.0, "max": 500.0, "step": 5.0, "order": 110,
			},
			"sword_width": {
				"label": "剑刃宽度", "group": "长剑", "suffix": " px",
				"default": 16.0, "min": 2.0, "max": 100.0, "step": 1.0, "order": 120,
			},
			"sword_damage": {
				"label": "普通触剑伤害", "group": "长剑",
				"default": 10.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 130,
			},
			"spin_duration": {
				"label": "剑刃旋转持续时间", "group": "剑刃旋转", "suffix": " 秒",
				"default": 2.5, "min": 0.1, "max": 30.0, "step": 0.1, "order": 210,
			},
			"spin_turns_per_second": {
				"label": "每秒旋转圈数", "group": "剑刃旋转", "suffix": " 圈/秒",
				"default": 1.5, "min": 0.1, "max": 20.0, "step": 0.1, "order": 220,
			},
			"spin_sword_damage": {
				"label": "旋转触剑伤害", "group": "剑刃旋转",
				"default": 6.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 230,
			},
		},
	}, AbilityScript, VisualScript)
