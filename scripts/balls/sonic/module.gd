extends BallModule

const AbilityScript := preload("res://scripts/balls/sonic/ability.gd")
const VisualScript := preload("res://scripts/balls/sonic/visual.gd")

func _init() -> void:
	super({
		"id": "sonic",
		"name": "音速球",
		"color": "1677dc",
		"accent": "73e7ff",
		"max_hp": 190.0,
		"speed": 260.0,
		"radius": 25.0,
		"contact_damage": 11.0,
		"cooldown": 3.0,
		"ability": "持续加速 · 音爆冲撞",
		"sound_kind": "impact",
		"sort_order": 60,
	}, AbilityScript, VisualScript)
