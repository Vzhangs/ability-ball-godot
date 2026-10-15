extends BallModule

const AbilityScript := preload("res://scripts/balls/prism/ability.gd")
const VisualScript := preload("res://scripts/balls/prism/visual.gd")
const ChargeSound := preload("res://scripts/balls/prism/audio/prism_charge.ogg")
const FireSound := preload("res://scripts/balls/prism/audio/prism_fire.ogg")
const HitSound := preload("res://scripts/balls/prism/audio/prism_hit.ogg")
const SpawnVoice := preload("res://scripts/balls/prism/audio/prism_spawn.ogg")

func _init() -> void:
	super({
		"id": "prism",
		"name": "光棱球",
		"color": "a9b7b9",
		"accent": "b8eaff",
		"title_color": "d7f3ff",
		"max_hp": 100.0,
		"speed": 175.0,
		"radius": 28.0,
		"cooldown": 3.2,
		"sort_order": 240,
		"ability": "光棱球会锁定射程内的敌人，蓄能后发射光棱攻击。主击命中后，从命中处折射攻击附近的其他敌人，敌人聚集得越密，越容易被波及。\n\n• 优先瞄准敌方主球；没有主球进入射程时，也会主动攻击分身、植物等可受击附属物。挡在攻击路线上的敌方单位会先承受打击。\n• 每轮攻击不会重复伤害同一个目标，折射不会继续引发新的折射，也不会伤害友军。无敌可以抵挡伤害。\n• 蓄能期间目标死亡、被捕获、转为友军或离开射程，攻击就会取消。分散站位、拉开距离可以减少折射造成的损失。",
		"sound_kind": "",
		"audio_samples": {
			"prism_spawn": {"stream": SpawnVoice, "gain_db": -15.0},
			"prism_charge": {"stream": ChargeSound, "gain_db": -17.0},
			"prism_fire": {"stream": FireSound, "gain_db": -15.0},
			"prism_hit": {"stream": HitSound, "gain_db": -21.0},
		},
		"tuning": {
			"opening_delay": {
				"label": "首次蓄能等待", "group": "光棱主炮", "suffix": " 秒",
				"default": 0.8, "min": 0.0, "max": 60.0, "step": 0.05, "order": 100,
			},
			"charge_duration": {
				"label": "蓄能时间", "group": "光棱主炮", "suffix": " 秒",
				"default": 0.38, "min": 0.05, "max": 10.0, "step": 0.01, "order": 110,
			},
			"attack_range": {
				"label": "主炮射程", "group": "光棱主炮", "suffix": " px",
				"default": 400.0, "min": 20.0, "max": 4000.0, "step": 5.0, "order": 120,
			},
			"main_damage": {
				"label": "主击伤害", "group": "光棱主炮",
				"default": 16.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 130,
			},
			"beam_half_width": {
				"label": "光束命中半宽", "group": "光棱主炮", "suffix": " px",
				"default": 2.5, "min": 0.5, "max": 30.0, "step": 0.5, "order": 140,
			},
			"refraction_count": {
				"label": "折射目标上限", "group": "折射攻击", "kind": "int",
				"default": 3, "min": 0, "max": 64, "step": 1, "order": 210,
			},
			"refraction_range": {
				"label": "折射搜索范围", "group": "折射攻击", "suffix": " px",
				"default": 170.0, "min": 0.0, "max": 3000.0, "step": 5.0, "order": 220,
			},
			"refraction_damage": {
				"label": "折射伤害", "group": "折射攻击",
				"default": 7.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 230,
			},
			"beam_duration": {
				"label": "光束消散时间", "group": "技能表现", "suffix": " 秒",
				"default": 0.45, "min": 0.08, "max": 2.0, "step": 0.01, "order": 310,
			},
		},
	}, AbilityScript, VisualScript)
