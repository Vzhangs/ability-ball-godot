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
		"ability": "盖伦球始终举着一柄长剑，并让剑尖朝向最近的敌方主球。敌方主球或附属单位第一次碰到剑刃会受到伤害；持续贴住不会反复受伤，离开后再次触剑才会重新结算。\n\n• 盖伦球会周期性让剑刃高速旋转并横扫四周。\n• 旋转期间单次触剑威力会发生变化，但高速扫过能让剑刃反复穿过目标。",
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
				"default": 80.0, "min": 20.0, "max": 500.0, "step": 5.0, "order": 110,
			},
			"sword_width": {
				"label": "剑刃宽度", "group": "长剑", "suffix": " px",
				"default": 12.0, "min": 2.0, "max": 100.0, "step": 1.0, "order": 120,
			},
			"sword_damage": {
				"label": "普通触剑伤害", "group": "长剑",
				"default": 6.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 130,
			},
			"spin_duration": {
				"label": "剑刃旋转持续时间", "group": "剑刃旋转", "suffix": " 秒",
				"default": 3.5, "min": 0.1, "max": 30.0, "step": 0.1, "order": 210,
			},
			"spin_turns_per_second": {
				"label": "每秒旋转圈数", "group": "剑刃旋转", "suffix": " 圈/秒",
				"default": 2.0, "min": 0.1, "max": 20.0, "step": 0.1, "order": 220,
			},
			"spin_sword_damage": {
				"label": "旋转触剑伤害", "group": "剑刃旋转",
				"default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 230,
			},
		},
	}, AbilityScript, VisualScript)
