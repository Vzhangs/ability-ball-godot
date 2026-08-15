extends BallModule

const AbilityScript := preload("res://scripts/balls/black_hole/ability.gd")
const VisualScript := preload("res://scripts/balls/black_hole/visual.gd")

func _init() -> void:
	super({
		"id": "black_hole",
		"name": "黑洞球",
		"color": "24123f",
		"accent": "bc63ff",
		"title_color": "9f55e8",
		"max_hp": 225.0,
		"speed": 172.0,
		"radius": 30.0,
		"contact_damage": 8.0,
		"cooldown": 4.2,
		"ability": "引力牵引 · 事件视界",
		"sound_kind": "judgment",
		"sort_order": 40,
	}, AbilityScript, VisualScript)
