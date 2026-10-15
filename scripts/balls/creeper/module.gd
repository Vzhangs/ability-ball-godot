extends BallModule

const AbilityScript := preload("res://scripts/balls/creeper/ability.gd")
const VisualScript := preload("res://scripts/balls/creeper/visual.gd")
const FuseSound := preload("res://scripts/balls/creeper/audio/fuse.ogg")
const ExplosionSound := preload("res://scripts/balls/creeper/audio/explode.ogg")

func _init() -> void:
	super({
		"id": "creeper", "name": "苦力怕球",
		"color": "569b35", "accent": "b4eb79", "title_color": "b4eb79",
		"max_hp": 100.0, "speed": 185.0, "radius": 27.0, "cooldown": 2.0,
		"ability": "碰到敌方主球或可碰撞附属物后点燃引信，随后在自身所在位置爆炸。\n\n• 爆炸伤害范围内的敌方主球与可受击附属物，并向外击退主球和可移动单位，不伤自己与友军。\n• 点燃后离开碰撞目标仍会爆炸，重复碰撞不会推迟引爆；敌人可以提前远离来躲避。\n• 爆炸后需要恢复才能再次点燃，普通碰撞不额外造成伤害；引爆前被击败则不会爆炸。",
		"sound_kind": "",
		"audio_samples": {
			"creeper_fuse": {"stream": FuseSound, "gain_db": 0.0},
			"creeper_explosion": {"stream": ExplosionSound, "gain_db": -3.0},
		},
		"sort_order": 205,
		"tuning": {
			"fuse_duration": {"label": "碰撞后引爆延迟", "group": "爆炸", "suffix": " 秒", "default": 1.0, "min": 0.05, "max": 10.0, "step": 0.05, "order": 110},
			"blast_radius": {"label": "爆炸半径", "group": "爆炸", "suffix": " px", "default": 180.0, "min": 1.0, "max": 2000.0, "step": 5.0, "order": 120},
			"blast_damage": {"label": "爆炸伤害", "group": "爆炸", "default": 24.0, "min": 0.0, "max": 1000.0, "step": 1.0, "order": 130},
			"knockback_speed": {"label": "击退速度", "group": "击退", "suffix": " px/s", "default": 600.0, "min": 0.0, "max": 4000.0, "step": 10.0, "order": 210},
			"knockback_duration": {"label": "击退持续时间", "group": "击退", "suffix": " 秒", "default": 0.25, "min": 0.0, "max": 3.0, "step": 0.05, "order": 220},
			"blast_effect_duration": {"label": "爆炸烟尘消散时间", "group": "爆炸", "suffix": " 秒", "default": 0.55, "min": 0.1, "max": 3.0, "step": 0.05, "order": 140},
		},
	}, AbilityScript, VisualScript)
