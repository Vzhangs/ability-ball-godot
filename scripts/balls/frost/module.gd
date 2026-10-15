extends BallModule

const AbilityScript := preload("res://scripts/balls/frost/ability.gd")
const VisualScript := preload("res://scripts/balls/frost/visual.gd")

func _init() -> void:
	super({
		"id": "frost",
		"name": "寒冰球",
		"color": "2f9fd4",
		"accent": "c7f8ff",
		"title_color": "9ceeff",
		"max_hp": 100.0,
		"speed": 196.0,
		"radius": 27.0,
		"cooldown": 4.0,
		"ability": "寒冰球经过的位置会凝结成持续存在的寒冰轨迹。

• 敌方主球或能够受伤的附属单位触碰轨迹后，会立刻受到寒冰减速；持续停留后才会被完全冻结，并在冰封期间持续失去生命。
• 在完全冻结前离开轨迹可以避免冰封，再次进入需要重新停留；解冻后仍会受到寒冰减速。
• 寒冰球本体撞上敌方主球或实体时会立即施加冰封，但碰撞本身不会额外造成伤害。
• 持续留在轨迹内会延长冰封，寒冰减速只保留最强效果而不会不断叠加。",
		"sound_kind": "projectile_hit",
		"sort_order": 105,
		"tuning": {
			"trail_spacing": {"label": "寒冰路径间距", "default": 12.0, "min": 2.0, "max": 120.0, "step": 1.0, "group": "寒冰路径", "order": 110},
			"max_ice_zones": {"label": "寒冰区数量上限", "default": 56, "min": 1, "max": 500, "step": 1, "kind": "int", "group": "寒冰路径", "order": 120},
			"ice_zone_duration": {"label": "寒冰区持续时间", "default": 4.5, "min": 0.1, "max": 30.0, "step": 0.1, "suffix": " 秒", "group": "寒冰路径", "order": 130},
			"ice_zone_radius": {"label": "寒冰区半径", "default": 25.0, "min": 2.0, "max": 200.0, "step": 1.0, "group": "寒冰路径", "order": 140},
			"ice_zone_absorption_radius_cap": {"label": "寒冰区可吞噬半径上限", "default": 12.0, "min": 1.0, "max": 200.0, "step": 1.0, "group": "寒冰路径", "order": 150},
			"ice_zone_absorption_radius_ratio": {"label": "寒冰区可吞噬半径比例", "default": 0.35, "min": 0.01, "max": 2.0, "step": 0.01, "group": "寒冰路径", "order": 160},
			"trail_freeze_delay": {"label": "轨迹连续接触冰冻时间", "default": 1.0, "min": 0.1, "max": 20.0, "step": 0.1, "suffix": " 秒", "group": "冰封效果", "order": 210},
			"freeze_duration": {"label": "完全冰冻时间", "default": 2.0, "min": 0.1, "max": 20.0, "step": 0.1, "suffix": " 秒", "group": "冰封效果", "order": 220},
			"freeze_damage": {"label": "每次冰冻伤害", "default": 2.0, "min": 0.0, "max": 500.0, "step": 0.1, "group": "冰封效果", "order": 230},
			"freeze_damage_interval": {"label": "冰冻伤害间隔", "default": 1.0, "min": 0.05, "max": 5.0, "step": 0.05, "suffix": " 秒", "group": "冰封效果", "order": 240},
			"slow_duration": {"label": "寒冰减速时间", "default": 4.0, "min": 0.1, "max": 30.0, "step": 0.1, "suffix": " 秒", "group": "寒冰减速", "order": 310},
			"slow_multiplier": {"label": "减速后速度倍率", "default": 0.55, "min": 0.05, "max": 1.0, "step": 0.01, "group": "寒冰减速", "order": 320},
		},
	}, AbilityScript, VisualScript)
