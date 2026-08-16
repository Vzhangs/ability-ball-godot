extends BallModule

const AbilityScript := preload("res://scripts/balls/splitter/ability.gd")
const VisualScript := preload("res://scripts/balls/splitter/visual.gd")

func _init() -> void:
	super({
		"id": "splitter",
		"name": "分裂球",
		"color": "4fd0e8",
		"accent": "b9f8ff",
		"max_hp": 100.0,
		"speed": 192.0,
		"radius": 27.0,
		"cooldown": 3.5,
		"ability": "百体分裂 · 独立撞击",
		"sound_kind": "impact",
		"sort_order": 30,
		"tuning": {
			"max_clones": {"label": "分身数量上限", "default": 100, "min": 1, "max": 100, "step": 1, "kind": "int", "order": 110},
			"early_clone_threshold": {"label": "前期分身阈值", "default": 4, "min": 0, "max": 100, "step": 1, "kind": "int", "order": 120},
			"early_spawn_count": {"label": "前期每次分裂数量", "default": 2, "min": 1, "max": 20, "step": 1, "kind": "int", "order": 130},
			"late_spawn_count": {"label": "后期每次分裂数量", "default": 3, "min": 1, "max": 20, "step": 1, "kind": "int", "order": 140},
			"damage_split_chance": {"label": "造成伤害后分裂概率", "default": 0.22, "min": 0.0, "max": 1.0, "step": 0.01, "order": 150},
			"body_impact_damage": {"label": "本体撞击伤害", "default": 5.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 160},
			"clone_max_hp": {"label": "分身生命值", "group": "分身属性", "default": 10.0, "min": 1.0, "max": 1000.0, "step": 1.0, "order": 210},
			"clone_radius": {"label": "分身半径", "group": "分身属性", "default": 13.0, "min": 4.0, "max": 40.0, "step": 1.0, "order": 220},
			"clone_impact_damage": {"label": "分身撞击伤害", "group": "分身属性", "default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 230},
			"clone_impact_wear": {"label": "分身撞击自损", "group": "分身属性", "default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 240},
			"clone_contact_interval": {"label": "分身碰撞间隔", "group": "分身属性", "default": 0.32, "min": 0.05, "max": 5.0, "step": 0.01, "order": 250, "suffix": " 秒"},
			"clone_min_speed": {"label": "分身最低速度", "group": "分身属性", "default": 175.0, "min": 20.0, "max": 1000.0, "step": 1.0, "order": 260},
			"clone_max_speed": {"label": "分身最高速度", "group": "分身属性", "default": 285.0, "min": 20.0, "max": 1500.0, "step": 1.0, "order": 270},
			"clone_spawn_speed_min": {"label": "生成速度下限", "group": "分身属性", "default": 205.0, "min": 0.0, "max": 1500.0, "step": 1.0, "order": 280},
			"clone_spawn_speed_max": {"label": "生成速度上限", "group": "分身属性", "default": 265.0, "min": 0.0, "max": 1500.0, "step": 1.0, "order": 290},
			"clone_spawn_gap": {"label": "生成间距", "group": "分身运动", "default": 4.0, "min": 0.0, "max": 100.0, "step": 0.5, "order": 310},
			"clone_owner_velocity_ratio": {"label": "继承本体速度比例", "group": "分身运动", "default": 0.28, "min": 0.0, "max": 3.0, "step": 0.01, "order": 320},
			"clone_wall_bounce_spread": {"label": "撞墙随机偏转", "group": "分身运动", "default": 0.045, "min": 0.0, "max": 1.0, "step": 0.005, "order": 330},
			"clone_target_velocity_ratio": {"label": "碰撞继承目标速度比例", "group": "分身运动", "default": 0.12, "min": 0.0, "max": 3.0, "step": 0.01, "order": 340},
			"clone_collision_cell_factor": {"label": "分身碰撞网格系数", "group": "分身运动", "default": 2.2, "min": 2.0, "max": 8.0, "step": 0.1, "order": 350},
		},
	}, AbilityScript, VisualScript)
