extends BallModule

const AbilityScript := preload("res://scripts/balls/gojo/ability_v2.gd")
const VisualScript := preload("res://scripts/balls/gojo/visual.gd")
const BlueVoice := preload("res://scripts/balls/gojo/audio/gojo_blue.ogg")
const RedVoice := preload("res://scripts/balls/gojo/audio/gojo_red.ogg")
const PurpleVoice := preload("res://scripts/balls/gojo/audio/gojo_purple.ogg")
const DomainVoice := preload("res://scripts/balls/gojo/audio/gojo_domain.ogg")

func _init() -> void:
	super({
		"id": "gojo",
		"name": "五条悟球",
		"color": "e8d7ad",
		"accent": "70e8ff",
		"title_color": "f4dc8b",
		"max_hp": 100.0,
		"speed": 188.0,
		"radius": 28.0,
		"cooldown": 2.3,
		"ability": "五条悟球操纵苍与赫作战，让自己释放的两种术式在碰撞后融合成茈。\n\n• 他会随机选择术式顺转「苍」或术式反转「赫」，朝敌人所在位置发射，同一种术式可以连续释放。苍持续吸引附近的敌人、附属单位和弹丸；赫持续向外排斥，并在命中时击退目标。自己释放的苍与赫也受这些范围力场影响，力场越靠近边缘越弱，离开范围后不再受力。苍与赫撞到目标后反弹，脱离接触并经过命中间隔后，可以再次伤害同一个目标；持续接触不会连续扣血。\n• 自己释放的苍与赫在运动中真正相撞后才会融合成虚式「茈」；队友的术式不参与自己的力场作用或融合。茈抹除沿途靠近的敌方投射物，首次命中敌方主球或可受击附属物时爆炸并消失，伤害命中目标及附近敌人；同一次爆炸对每个目标只结算一次伤害。\n• 战局进入中段且敌人靠近后，他会展开无量空处，让领域内的敌人和附属物陷入停滞并持续受伤。",
		"sound_kind": "",
		"audio_samples": {
			"gojo_blue_voice": {"stream": BlueVoice, "gain_db": -9.0},
			"gojo_red_voice": {"stream": RedVoice, "gain_db": -9.0},
			"gojo_purple_voice": {"stream": PurpleVoice, "gain_db": -8.0},
			"gojo_domain_voice": {"stream": DomainVoice, "gain_db": -7.0},
		},
		"sort_order": 202,
		"tuning": {
			"opening_delay": {
				"label": "开局首次释放延迟", "group": "术式节奏", "suffix": " 秒",
				"default": 0.45, "min": 0.0, "max": 30.0, "step": 0.05, "order": 100,
			},
			"spawn_gap": {
				"label": "术式出生间距", "group": "术式节奏", "suffix": " px",
				"default": 7.0, "min": 0.0, "max": 160.0, "step": 0.5, "order": 110,
			},
			"blue_cast_probability": {
				"label": "苍释放概率", "group": "术式节奏", "suffix": "%",
				"default": 0.5, "min": 0.0, "max": 1.0, "step": 0.01, "order": 120,
			},
			"cast_flash_duration": {
				"label": "释放闪光时间", "group": "术式节奏", "suffix": " 秒",
				"default": 0.34, "min": 0.05, "max": 3.0, "step": 0.01, "order": 140,
			},
			"cast_name_duration": {
				"label": "苍赫招式名时间", "group": "术式节奏", "suffix": " 秒",
				"default": 1.05, "min": 0.2, "max": 5.0, "step": 0.05, "order": 150,
			},
			"orb_hit_interval": {
				"label": "苍赫同目标命中间隔", "group": "术式节奏", "suffix": " 秒",
				"default": 0.35, "min": 0.05, "max": 5.0, "step": 0.05, "order": 160,
			},
			"blue_damage": {
				"label": "苍命中伤害", "group": "苍",
				"default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 210,
			},
			"blue_speed": {
				"label": "苍飞行速度", "group": "苍", "suffix": " px/s",
				"default": 245.0, "min": 20.0, "max": 4000.0, "step": 5.0, "order": 220,
			},
			"blue_radius": {
				"label": "苍半径", "group": "苍", "suffix": " px",
				"default": 7.0, "min": 2.0, "max": 80.0, "step": 0.5, "order": 230,
			},
			"blue_lifetime": {
				"label": "苍存在时间", "group": "苍", "suffix": " 秒",
				"default": 13.0, "min": 0.2, "max": 120.0, "step": 0.1, "order": 240,
			},
			"maximum_blue_orbs": {
				"label": "苍数量上限", "group": "苍", "kind": "int",
				"default": 6, "min": 1, "max": 100, "step": 1, "order": 250,
			},
			"blue_force_radius": {
				"label": "苍引力范围", "group": "苍", "suffix": " px",
				"default": 150.0, "min": 0.0, "max": 1000.0, "step": 5.0, "order": 260,
			},
			"blue_force_acceleration": {
				"label": "苍引力加速度", "group": "苍", "suffix": " px/s²",
				"default": 180.0, "min": 0.0, "max": 5000.0, "step": 10.0, "order": 270,
			},
			"blue_force_maximum_speed": {
				"label": "苍牵引速度上限", "group": "苍", "suffix": " px/s",
				"default": 360.0, "min": 1.0, "max": 5000.0, "step": 10.0, "order": 280,
			},
			"red_damage": {
				"label": "赫命中伤害", "group": "赫",
				"default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 310,
			},
			"red_speed": {
				"label": "赫飞行速度", "group": "赫", "suffix": " px/s",
				"default": 285.0, "min": 20.0, "max": 4000.0, "step": 5.0, "order": 320,
			},
			"red_radius": {
				"label": "赫半径", "group": "赫", "suffix": " px",
				"default": 8.0, "min": 2.0, "max": 80.0, "step": 0.5, "order": 330,
			},
			"red_lifetime": {
				"label": "赫存在时间", "group": "赫", "suffix": " 秒",
				"default": 13.0, "min": 0.2, "max": 120.0, "step": 0.1, "order": 340,
			},
			"maximum_red_orbs": {
				"label": "赫数量上限", "group": "赫", "kind": "int",
				"default": 5, "min": 1, "max": 100, "step": 1, "order": 350,
			},
			"red_force_radius": {
				"label": "赫斥力范围", "group": "赫", "suffix": " px",
				"default": 135.0, "min": 0.0, "max": 1000.0, "step": 5.0, "order": 360,
			},
			"red_force_acceleration": {
				"label": "赫斥力加速度", "group": "赫", "suffix": " px/s²",
				"default": 240.0, "min": 0.0, "max": 8000.0, "step": 10.0, "order": 370,
			},
			"red_force_maximum_speed": {
				"label": "赫排斥速度上限", "group": "赫", "suffix": " px/s",
				"default": 420.0, "min": 1.0, "max": 5000.0, "step": 10.0, "order": 380,
			},
			"red_impact_impulse": {
				"label": "赫命中击退冲量", "group": "赫", "suffix": " px/s",
				"default": 120.0, "min": 0.0, "max": 3000.0, "step": 10.0, "order": 390,
			},
			"purple_damage": {
				"label": "茈爆炸伤害", "group": "茈",
				"default": 18.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 510,
			},
			"purple_explosion_radius": {
				"label": "茈爆炸半径", "group": "茈", "suffix": " px",
				"default": 200.0, "min": 0.0, "max": 1000.0, "step": 5.0, "order": 512,
			},
			"purple_explosion_duration": {
				"label": "茈爆炸演出时间", "group": "茈", "suffix": " 秒",
				"default": 1.4, "min": 0.05, "max": 3.0, "step": 0.05, "order": 514,
			},
			"purple_speed": {
				"label": "茈飞行速度", "group": "茈", "suffix": " px/s",
				"default": 365.0, "min": 20.0, "max": 5000.0, "step": 5.0, "order": 520,
			},
			"purple_radius": {
				"label": "茈碰撞核心半径", "group": "茈", "suffix": " px",
				"default": 11.5, "min": 2.0, "max": 100.0, "step": 0.5, "order": 530,
			},
			"purple_lifetime": {
				"label": "茈存在时间", "group": "茈", "suffix": " 秒",
				"default": 9.0, "min": 0.2, "max": 120.0, "step": 0.1, "order": 540,
			},
			"maximum_purple_orbs": {
				"label": "茈数量上限", "group": "茈", "kind": "int",
				"default": 3, "min": 1, "max": 100, "step": 1, "order": 550,
			},
			"purple_direction_jitter_degrees": {
				"label": "茈融合方向偏移", "group": "茈", "suffix": "°",
				"default": 9.0, "min": 0.0, "max": 180.0, "step": 1.0, "order": 560,
			},
			"purple_erase_radius": {
				"label": "茈弹丸抹除半径", "group": "茈", "suffix": " px",
				"default": 24.0, "min": 0.0, "max": 300.0, "step": 1.0, "order": 570,
			},
			"purple_name_duration": {
				"label": "茈招式名时间", "group": "茈", "suffix": " 秒",
				"default": 1.25, "min": 0.2, "max": 5.0, "step": 0.05, "order": 580,
			},
			"domain_minimum_elapsed": {
				"label": "无量空处最早触发时间", "group": "无量空处", "suffix": " 秒",
				"default": 14.0, "min": 0.0, "max": 120.0, "step": 0.5, "order": 810,
			},
			"domain_trigger_range": {
				"label": "无量空处触发距离", "group": "无量空处", "suffix": " px",
				"default": 230.0, "min": 20.0, "max": 1200.0, "step": 5.0, "order": 820,
			},
			"domain_radius": {
				"label": "无量空处领域半径", "group": "无量空处", "suffix": " px",
				"default": 280.0, "min": 40.0, "max": 1400.0, "step": 5.0, "order": 830,
			},
			"domain_duration": {
				"label": "无量空处持续时间", "group": "无量空处", "suffix": " 秒",
				"default": 3.0, "min": 0.2, "max": 20.0, "step": 0.1, "order": 840,
			},
			"domain_damage_per_tick": {
				"label": "无量空处每次伤害", "group": "无量空处",
				"default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 850,
			},
			"domain_tick_interval": {
				"label": "无量空处伤害间隔", "group": "无量空处", "suffix": " 秒",
				"default": 0.5, "min": 0.05, "max": 5.0, "step": 0.05, "order": 860,
			},
			"domain_name_duration": {
				"label": "无量空处招式名时间", "group": "无量空处", "suffix": " 秒",
				"default": 1.65, "min": 0.2, "max": 6.0, "step": 0.05, "order": 870,
			},
		},
	}, AbilityScript, VisualScript)
