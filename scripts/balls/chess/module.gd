extends BallModule

const AbilityScript := preload("res://scripts/balls/chess/ability.gd")
const VisualScript := preload("res://scripts/balls/chess/visual.gd")

func _init() -> void:
	super({
		"id": "chess",
		"name": "象棋球",
		"color": "a92120",
		"accent": "f6d89a",
		"title_color": "ffdca0",
		"max_hp": 100.0,
		"speed": 170.0,
		"radius": 30.0,
		"cooldown": 6.0,
		"ability": "象棋球会从車、炮、象、帅、士中随机发动一项棋令。\n\n• 車：短暂蓄力后冲向敌人释放时的位置，沿途碾过附属单位，撞墙时还会爆发重击。\n• 炮：连续发射炮弹，命中后产生范围爆炸。\n• 象：进入无敌并移动到底部中央，随后沿菱形路线高速冲撞。\n• 帅：立即恢复生命，并在接下来的一段时间持续回血。\n• 士：召唤平均环绕的护卫，既能挡住攻击，也能撞击敌方主球和附属单位。",
		"sound_kind": "judgment",
		"sort_order": 190,
		"tuning": {
			"rook_weight": {
				"label": "車技能权重", "group": "棋令权重",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 110,
			},
			"cannon_weight": {
				"label": "炮技能权重", "group": "棋令权重",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 120,
			},
			"elephant_weight": {
				"label": "象技能权重", "group": "棋令权重",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 130,
			},
			"marshal_weight": {
				"label": "帅技能权重", "group": "棋令权重",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 140,
			},
			"guard_weight": {
				"label": "士技能权重", "group": "棋令权重",
				"default": 1.0, "min": 0.0, "max": 100.0, "step": 0.1, "order": 150,
			},
			"cast_icon_duration": {
				"label": "棋令图标持续时间", "group": "棋令表现", "suffix": " 秒",
				"default": 0.85, "min": 0.1, "max": 3.0, "step": 0.05, "order": 190,
			},
			"rook_windup_duration": {
				"label": "車突进前摇", "group": "車", "suffix": " 秒",
				"default": 0.3, "min": 0.0, "max": 3.0, "step": 0.05, "order": 205,
			},
			"rook_dash_speed": {
				"label": "車突进速度", "group": "車", "suffix": " px/s",
				"default": 680.0, "min": 40.0, "max": 2400.0, "step": 10.0, "order": 210,
			},
			"rook_damage": {
				"label": "車主球撞击伤害", "group": "車",
				"default": 18.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 220,
			},
			"rook_entity_damage": {
				"label": "車附属物碾压伤害", "group": "車",
				"default": 7.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 225,
			},
			"rook_max_duration": {
				"label": "車突进最长时间", "group": "車", "suffix": " 秒",
				"default": 1.2, "min": 0.1, "max": 10.0, "step": 0.05, "order": 230,
			},
			"rook_lane_width_multiplier": {
				"label": "車车头宽度倍率", "group": "車", "suffix": " 倍直径",
				"default": 1.25, "min": 1.0, "max": 3.0, "step": 0.05, "order": 240,
			},
			"rook_front_length": {
				"label": "車车头判定长度", "group": "車", "suffix": " px",
				"default": 72.0, "min": 10.0, "max": 300.0, "step": 2.0, "order": 250,
			},
			"rook_carry_duration": {
				"label": "車顶行时间", "group": "車", "suffix": " 秒",
				"default": 0.35, "min": 0.05, "max": 3.0, "step": 0.05, "order": 260,
			},
			"rook_wall_damage": {
				"label": "車撞墙追加伤害", "group": "車",
				"default": 12.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 270,
			},
			"cannon_damage": {
				"label": "炮爆炸伤害", "group": "炮",
				"default": 10.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 310,
			},
			"cannon_explosion_radius": {
				"label": "炮爆炸半径", "group": "炮", "suffix": " px",
				"default": 78.0, "min": 8.0, "max": 400.0, "step": 2.0, "order": 320,
			},
			"cannon_projectile_speed": {
				"label": "炮弹速度", "group": "炮", "suffix": " px/s",
				"default": 420.0, "min": 20.0, "max": 2400.0, "step": 10.0, "order": 330,
			},
			"cannon_projectile_radius": {
				"label": "炮弹半径", "group": "炮", "suffix": " px",
				"default": 8.0, "min": 2.0, "max": 40.0, "step": 1.0, "order": 340,
			},
			"cannon_projectile_lifetime": {
				"label": "炮弹最长存在时间", "group": "炮", "suffix": " 秒",
				"default": 3.0, "min": 0.1, "max": 20.0, "step": 0.1, "order": 350,
			},
			"cannon_shot_count": {
				"label": "炮连续发射数量", "group": "炮", "suffix": " 发",
				"default": 2, "min": 1, "max": 8, "step": 1, "kind": "int", "order": 360,
			},
			"cannon_shot_interval": {
				"label": "炮连发间隔", "group": "炮", "suffix": " 秒",
				"default": 0.28, "min": 0.05, "max": 2.0, "step": 0.01, "order": 370,
			},
			"cannon_muzzle_flash_duration": {
				"label": "炮口焰持续时间", "group": "炮", "suffix": " 秒",
				"default": 0.30, "min": 0.05, "max": 2.0, "step": 0.05, "order": 380,
			},
			"cannon_blast_duration": {
				"label": "炮爆炸特效持续时间", "group": "炮", "suffix": " 秒",
				"default": 0.52, "min": 0.1, "max": 3.0, "step": 0.05, "order": 390,
			},
			"elephant_start_speed": {
				"label": "象归位速度", "group": "象", "suffix": " px/s",
				"default": 520.0, "min": 40.0, "max": 2400.0, "step": 10.0, "order": 410,
			},
			"elephant_path_speed": {
				"label": "象菱形速度", "group": "象", "suffix": " px/s",
				"default": 640.0, "min": 40.0, "max": 2400.0, "step": 10.0, "order": 420,
			},
			"elephant_damage": {
				"label": "象撞击伤害", "group": "象",
				"default": 8.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 430,
			},
			"elephant_laps": {
				"label": "象菱形圈数", "group": "象", "suffix": " 圈",
				"default": 2, "min": 1, "max": 20, "step": 1, "kind": "int", "order": 440,
			},
			"elephant_path_margin": {
				"label": "象轨迹边距", "group": "象", "suffix": " px",
				"default": 48.0, "min": 0.0, "max": 240.0, "step": 2.0, "order": 450,
			},
			"marshal_instant_heal": {
				"label": "帅即时回复", "group": "帅",
				"default": 10.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 510,
			},
			"marshal_regen_duration": {
				"label": "帅持续回复时间", "group": "帅", "suffix": " 秒",
				"default": 5.0, "min": 0.1, "max": 60.0, "step": 0.1, "order": 520,
			},
			"marshal_regen_per_tick": {
				"label": "帅每跳回复", "group": "帅",
				"default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 530,
			},
			"marshal_regen_interval": {
				"label": "帅回复间隔", "group": "帅", "suffix": " 秒",
				"default": 1.0, "min": 0.05, "max": 10.0, "step": 0.05, "order": 540,
			},
			"guard_summon_count": {
				"label": "士每次召唤数量", "group": "士", "suffix": " 枚",
				"default": 2, "min": 1, "max": 30, "step": 1, "kind": "int", "order": 610,
			},
			"guard_max_hp": {
				"label": "士生命值", "group": "士",
				"default": 10.0, "min": 1.0, "max": 1000.0, "step": 1.0, "order": 620,
			},
			"guard_radius": {
				"label": "士半径", "group": "士", "suffix": " px",
				"default": 10.0, "min": 3.0, "max": 40.0, "step": 1.0, "order": 630,
			},
			"guard_contact_damage": {
				"label": "士碰撞伤害", "group": "士",
				"default": 3.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 640,
			},
			"guard_contact_interval": {
				"label": "士重复碰撞间隔", "group": "士", "suffix": " 秒",
				"default": 0.35, "min": 0.05, "max": 5.0, "step": 0.05, "order": 650,
			},
			"guard_orbit_radius": {
				"label": "士环绕半径", "group": "士", "suffix": " px",
				"default": 58.0, "min": 20.0, "max": 240.0, "step": 2.0, "order": 660,
			},
			"guard_orbit_speed": {
				"label": "士环绕角速度", "group": "士", "suffix": " rad/s",
				"default": 2.2, "min": 0.1, "max": 20.0, "step": 0.1, "order": 670,
			},
		},
	}, AbilityScript, VisualScript)
