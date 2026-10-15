extends BallModule

const AbilityScript := preload("res://scripts/balls/flame/ability.gd")
const VisualScript := preload("res://scripts/balls/flame/visual.gd")

func _init() -> void:
	super({
		"id": "flame",
		"name": "火焰球",
		"color": "e04416",
		"accent": "ffd052",
		"max_hp": 100.0,
		"speed": 208.0,
		"radius": 27.0,
		"cooldown": 3.8,
		"ability": "火焰球经过的位置会持续燃烧，沿移动路线连成能够封锁场地的火路。\n\n• 敌方主球进入火路后会持续受伤，并被施加离开火路后仍会继续生效的灼烧。\n• 分身、植物和其他能够受伤的附属单位同样会被火路和灼烧伤害。\n• 火焰球撞到敌方主球或可碰撞附属物时会引发爆燃，点燃接触点附近的所有敌方单位。",
		"sound_kind": "blood",
		"sort_order": 100,
		"tuning": {
			"trail_spacing": {"label": "火焰路径间距", "default": 14.0, "min": 2.0, "max": 120.0, "step": 1.0, "group": "火焰路径", "order": 110},
			"max_fire_zones": {"label": "火区数量上限", "default": 42, "min": 1, "max": 400, "step": 1, "kind": "int", "group": "火焰路径", "order": 120},
			"fire_zone_duration": {"label": "火区持续时间", "default": 2.5, "min": 0.1, "max": 30.0, "step": 0.1, "suffix": " 秒", "group": "火焰路径", "order": 130},
			"fire_zone_radius": {"label": "火区半径", "default": 28.0, "min": 2.0, "max": 200.0, "step": 1.0, "group": "火焰路径", "order": 140},
			"fire_zone_absorption_radius_cap": {"label": "火区可吞噬半径上限", "default": 12.0, "min": 1.0, "max": 200.0, "step": 1.0, "group": "火焰路径", "order": 150},
			"fire_zone_absorption_radius_ratio": {"label": "火区可吞噬半径比例", "default": 0.35, "min": 0.01, "max": 2.0, "step": 0.01, "group": "火焰路径", "order": 160},
			"trail_damage_interval": {"label": "路径伤害间隔", "default": 0.5, "min": 0.05, "max": 5.0, "step": 0.05, "suffix": " 秒", "group": "路径伤害", "order": 210},
			"trail_damage": {"label": "每次路径伤害", "default": 2.5, "min": 0.0, "max": 500.0, "step": 0.1, "group": "路径伤害", "order": 220},
			"burn_debuff_duration": {"label": "灼烧持续时间", "default": 3.0, "min": 0.1, "max": 30.0, "step": 0.1, "suffix": " 秒", "group": "灼烧 DEBUFF", "order": 310},
			"burn_debuff_tick_interval": {"label": "灼烧伤害间隔", "default": 1.0, "min": 0.05, "max": 5.0, "step": 0.05, "suffix": " 秒", "group": "灼烧 DEBUFF", "order": 320},
			"burn_debuff_damage": {"label": "每次灼烧伤害", "default": 1.0, "min": 0.0, "max": 500.0, "step": 0.1, "group": "灼烧 DEBUFF", "order": 330},
			"combustion_radius": {"label": "爆燃范围", "default": 105.0, "min": 10.0, "max": 500.0, "step": 1.0, "group": "碰撞爆燃", "order": 410},
			"combustion_damage": {"label": "爆燃伤害", "default": 5.0, "min": 0.0, "max": 500.0, "step": 0.5, "group": "碰撞爆燃", "order": 420},
			"combustion_effect_duration": {"label": "爆燃表现时长", "default": 0.6, "min": 0.1, "max": 5.0, "step": 0.05, "suffix": " 秒", "group": "碰撞爆燃", "order": 430},
		},
	}, AbilityScript, VisualScript)
