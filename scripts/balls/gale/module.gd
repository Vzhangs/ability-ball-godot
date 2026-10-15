extends BallModule

const AbilityScript := preload("res://scripts/balls/gale/ability.gd")
const VisualScript := preload("res://scripts/balls/gale/visual.gd")

func _init() -> void:
	super({
		"id": "gale", "name": "疾风球", "color": "27b994", "accent": "d1fff1",
		"title_color": "d1fff1", "max_hp": 100.0, "speed": 205, "radius": 27.0,
		"cooldown": 1, "sort_order": 260, "sound_kind": "",
		"ability": "疾风球在移动中留下风道，让接触的友方主球与独立作战单位加速，让敌方减速，离开后效果消退。\n\n• 碰撞主球、实体障碍或墙壁会积累速度提升，持续接触同一物体不会反复叠加，提升存在上限。\n• 撞墙时沿反弹方向发射风刃，命中双方的速度差越大，伤害越高；风刃会被最先接触的敌方单位挡下。\n• 本体普通碰撞没有额外伤害。风道不会伤害目标，失效或被吞噬后不再施加加减速。",
		"tuning": {
			"collision_growth": {"label": "每次碰撞增速比例", "default": 0.08, "min": 0, "max": 1, "step": 0.01, "group": "碰撞增速", "order": 110},
			"maximum_growth": {"label": "积累增速倍率上限", "default": 3, "min": 1, "max": 8, "step": 0.1, "group": "碰撞增速", "order": 120},
			"separation_margin": {"label": "碰撞重新触发分离距离", "default": 4, "min": 0.1, "max": 30, "step": 0.5, "group": "碰撞增速", "order": 130},
			"trail_spacing": {"label": "风道分段间距", "default": 18, "min": 4, "max": 80, "step": 1, "group": "风道", "order": 140},
			"lane_half_width": {"label": "风道半宽", "default": 23, "min": 3, "max": 100, "step": 1, "group": "风道", "order": 150},
			"lane_duration": {"label": "风道持续时间", "default": 3.2, "min": 0.1, "max": 20, "step": 0.1, "group": "风道", "order": 160},
			"max_lanes": {"label": "风道分段上限", "default": 96, "min": 1, "max": 300, "step": 1, "group": "风道", "order": 170, "kind": "int"},
			"friendly_multiplier": {"label": "顺风加速倍率", "default": 1.3, "min": 1, "max": 2.4, "step": 0.05, "group": "风道", "order": 180},
			"hostile_multiplier": {"label": "逆风减速倍率", "default": 0.65, "min": 0.1, "max": 1, "step": 0.05, "group": "风道", "order": 190},
			"effect_linger": {"label": "离开风道后余效时间", "default": 0.12, "min": 0.02, "max": 2, "step": 0.01, "group": "风道", "order": 200},
			"blade_speed": {"label": "风刃飞行速度", "default": 620, "min": 50, "max": 2000, "step": 10, "group": "风刃", "order": 210},
			"blade_radius": {"label": "风刃命中半径", "default": 9, "min": 2, "max": 40, "step": 1, "group": "风刃", "order": 220},
			"blade_duration": {"label": "风刃存留时间", "default": 2, "min": 0.1, "max": 6, "step": 0.1, "group": "风刃", "order": 230},
			"blade_base_damage": {"label": "风刃基础伤害", "default": 2, "min": 0, "max": 100, "step": 0.5, "group": "风刃", "order": 240},
			"speed_difference_damage": {"label": "每单位速度差附加伤害", "default": 0.04, "min": 0, "max": 1, "step": 0.01, "group": "风刃", "order": 250},
			"blade_damage_cap": {"label": "风刃伤害上限", "default": 32, "min": 0, "max": 500, "step": 1, "group": "风刃", "order": 260},
		},
	}, AbilityScript, VisualScript)
