extends BallModule

const AbilityScript := preload("res://scripts/balls/go_ball/ability.gd")
const VisualScript := preload("res://scripts/balls/go_ball/visual.gd")

func _init() -> void:
	super({
		"id": "go_ball",
		"name": "围棋球",
		"color": "151719",
		"accent": "f2efe2",
		"title_color": "fff7d1",
		"max_hp": 100.0,
		"speed": 195.0,
		"radius": 28.0,
		"cooldown": 2.0,
		"ability": "围棋球会把竞技场化为棋盘，并在自己经过的棋线交叉点交替落下黑白棋子。棋子会阻挡敌方单位，也会在反复撞击和攻击中被清除。\n\n• 黑子占优时，本体碰撞会按黑子的阵势造成伤害。\n• 白子占优时，本体碰撞会按白子的阵势恢复生命。\n• 黑白势均力敌时，两种能力会同时生效；破坏或夺取棋子能够改变局势。",
		"sound_kind": "track",
		"sort_order": 245,
		"tuning": {
			"grid_size": {
				"label": "棋盘交叉点数", "group": "棋盘", "suffix": " 个",
				"default": 10, "min": 4, "max": 30, "step": 1,
				"kind": "int", "order": 110,
			},
			"stone_max_hp": {
				"label": "棋子生命值", "group": "棋子",
				"default": 10.0, "min": 1.0, "max": 1000.0, "step": 1.0,
				"order": 210,
			},
			"stone_collision_wear": {
				"label": "棋子每次受撞损耗", "group": "棋子",
				"default": 3.0, "min": 0.0, "max": 100.0, "step": 0.5,
				"order": 220,
			},
			"stone_radius_ratio": {
				"label": "棋子相对线距比例", "group": "棋子",
				"default": 0.28, "min": 0.12, "max": 0.45, "step": 0.01,
				"order": 230,
			},
			"stone_contact_interval": {
				"label": "棋子重复碰撞间隔", "group": "棋子", "suffix": " 秒",
				"default": 0.45, "min": 0.05, "max": 5.0, "step": 0.05,
				"order": 240,
			},
			"black_damage_per_stone": {
				"label": "每枚黑子碰撞伤害", "group": "本体能力",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.5,
				"order": 310,
			},
			"white_heal_per_stone": {
				"label": "每枚白子碰撞回复", "group": "本体能力",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.5,
				"order": 320,
			},
			"placement_animation_duration": {
				"label": "落子动画持续时间", "group": "视觉表现", "suffix": " 秒",
				"default": 0.48, "min": 0.08, "max": 3.0, "step": 0.04,
				"order": 410,
			},
		},
	}, AbilityScript, VisualScript)
