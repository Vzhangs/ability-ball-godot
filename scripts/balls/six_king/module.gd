extends BallModule

const AbilityScript := preload("res://scripts/balls/six_king/ability.gd")
const VisualScript := preload("res://scripts/balls/six_king/visual.gd")
const ShowcaseAbilityScript := preload("res://scripts/balls/six_king/showcase_ability.gd")

func _init() -> void:
	super({
		"id": "six_king",
		"name": "六王球",
		"color": "f0cf32",
		"accent": "75dfff",
		"max_hp": 220.0,
		"speed": 190.0,
		"radius": 28.0,
		"cooldown": 3.8,
		"ability": "六向锚点 · 轨道审判",
		"sound_kind": "judgment",
		"sort_order": 20,
	}, AbilityScript, VisualScript)
	register_profile("showcase", {
		"max_hp": 194.0,
		"speed": 138.0,
		"minimum_speed": 138.0,
		"maximum_speed": 390.0,
		"radius": 29.0,
		"cooldown": 999.0,
	}, ShowcaseAbilityScript)
