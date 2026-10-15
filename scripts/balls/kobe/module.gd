extends BallModule

const AbilityScript := preload("res://scripts/balls/kobe/ability.gd")
const VisualScript := preload("res://scripts/balls/kobe/visual.gd")
const CycloneVoice := preload("res://scripts/balls/kobe/audio/kobe_cyclone.ogg")
const ElbowVoice := preload("res://scripts/balls/kobe/audio/kobe_elbow.ogg")

func _init() -> void:
	super({
		"id": "kobe",
		"name": "科比球",
		"color": "2a163c",
		"accent": "f4c542",
		"title_color": "fff0a0",
		"max_hp": 100.0,
		"speed": 205.0,
		"radius": 28.0,
		"cooldown": 3.8,
		"ability": "科比球在闪电旋风劈与肘击之间轮流出手。\n\n• 闪电旋风劈会高速旋转突进并横扫周围，每个敌方主球或附属单位在同一次横扫中只会受击一次，并被向外掀开。\n• 肘击会朝当前目标快速贴近，随后攻击面前的主球和挡路附属单位，造成更高伤害与更强击退。\n• 普通球体碰撞仍然只反弹，不会额外掉血。",
		"sound_kind": "",
		"audio_samples": {
			"kobe_cyclone_voice": {"stream": CycloneVoice, "gain_db": -7.0},
			"kobe_elbow_voice": {"stream": ElbowVoice, "gain_db": -6.0},
		},
		"sort_order": 204,
		"tuning": {
			"opening_delay": {"label": "开局首次出招延迟", "group": "出招节奏", "suffix": " 秒", "default": 0.7, "min": 0.0, "max": 30.0, "step": 0.05, "order": 110},
			"cast_name_duration": {"label": "招式名显示时间", "group": "出招节奏", "suffix": " 秒", "default": 1.0, "min": 0.2, "max": 5.0, "step": 0.05, "order": 120},
			"cyclone_duration": {"label": "旋风劈持续时间", "group": "闪电旋风劈", "suffix": " 秒", "default": 0.9, "min": 0.1, "max": 8.0, "step": 0.05, "order": 210},
			"cyclone_speed": {"label": "旋风劈突进速度", "group": "闪电旋风劈", "suffix": " px/s", "default": 620.0, "min": 20.0, "max": 5000.0, "step": 10.0, "order": 220},
			"cyclone_damage": {"label": "旋风劈伤害", "group": "闪电旋风劈", "default": 9.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 230},
			"cyclone_reach": {"label": "旋风劈外扩范围", "group": "闪电旋风劈", "suffix": " px", "default": 30.0, "min": 0.0, "max": 300.0, "step": 1.0, "order": 240},
			"cyclone_knockback": {"label": "旋风劈击退冲量", "group": "闪电旋风劈", "suffix": " px/s", "default": 260.0, "min": 0.0, "max": 3000.0, "step": 10.0, "order": 250},
			"cyclone_turn_rate_degrees": {"label": "旋风劈转向速度", "group": "闪电旋风劈", "suffix": "°/s", "default": 300.0, "min": 0.0, "max": 2160.0, "step": 10.0, "order": 260},
			"elbow_windup_duration": {"label": "肘击起手时间", "group": "肘击", "suffix": " 秒", "default": 0.18, "min": 0.0, "max": 3.0, "step": 0.01, "order": 310},
			"elbow_active_duration": {"label": "肘击出手时间", "group": "肘击", "suffix": " 秒", "default": 0.24, "min": 0.05, "max": 3.0, "step": 0.01, "order": 320},
			"elbow_lunge_speed": {"label": "肘击贴近速度", "group": "肘击", "suffix": " px/s", "default": 440.0, "min": 20.0, "max": 5000.0, "step": 10.0, "order": 330},
			"elbow_reach": {"label": "肘击前伸距离", "group": "肘击", "suffix": " px", "default": 62.0, "min": 1.0, "max": 500.0, "step": 1.0, "order": 340},
			"elbow_half_width": {"label": "肘击判定半宽", "group": "肘击", "suffix": " px", "default": 18.0, "min": 1.0, "max": 200.0, "step": 1.0, "order": 350},
			"elbow_damage": {"label": "肘击伤害", "group": "肘击", "default": 13.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 360},
			"elbow_knockback": {"label": "肘击击退冲量", "group": "肘击", "suffix": " px/s", "default": 420.0, "min": 0.0, "max": 4000.0, "step": 10.0, "order": 370},
		},
	}, AbilityScript, VisualScript)
