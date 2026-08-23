extends BallModule

const AbilityScript := preload("res://scripts/balls/wind_swordsman/ability.gd")
const VisualScript := preload("res://scripts/balls/wind_swordsman/visual.gd")
const HasagiVoice := preload("res://scripts/balls/wind_swordsman/audio/q_hasagi_variant.ogg")

func _init() -> void:
	super({
		"id": "wind_swordsman",
		"name": "风剑球",
		"color": "176c84",
		"accent": "8ff5ff",
		"title_color": "b8fbff",
		"max_hp": 100.0,
		"speed": 196.0,
		"radius": 27.0,
		"cooldown": 5.0,
		"ability": "贴身指向斩击 · 曲面风障 · 施法立定",
		"sound_kind": "wind_cast",
		"audio_samples": {
			"blade_slash": {
				"stream": HasagiVoice,
				"gain_db": -10.0,
			},
		},
		"sort_order": 110,
		"tuning": {
			"slash_damage": {"label": "斩击伤害", "group": "贴身斩击", "default": 12.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 110},
			"slash_trigger_range": {"label": "斩击触发距离", "group": "贴身斩击", "default": 120.0, "min": 20.0, "max": 900.0, "step": 5.0, "order": 120},
			"slash_reach": {"label": "斩击长度", "group": "贴身斩击", "default": 128.0, "min": 20.0, "max": 900.0, "step": 5.0, "order": 130},
			"slash_half_width": {"label": "斩击半宽", "group": "贴身斩击", "default": 25.0, "min": 1.0, "max": 200.0, "step": 1.0, "order": 140},
			"slash_cooldown": {"label": "斩击冷却", "group": "贴身斩击", "default": 1.1, "min": 0.05, "max": 30.0, "step": 0.05, "order": 150, "suffix": " 秒"},
			"slash_effect_duration": {"label": "刀痕持续时间", "group": "贴身斩击", "default": 0.6, "min": 0.1, "max": 5.0, "step": 0.05, "order": 160, "suffix": " 秒"},
			"crack_duration": {"label": "地面裂痕持续时间", "group": "贴身斩击", "default": 2.8, "min": 0.1, "max": 15.0, "step": 0.1, "order": 170, "suffix": " 秒"},
			"wall_duration": {"label": "风障持续时间", "group": "曲面风障", "default": 3.5, "min": 0.1, "max": 30.0, "step": 0.1, "order": 210, "suffix": " 秒"},
			"max_walls": {"label": "风障数量上限", "group": "曲面风障", "default": 1, "min": 1, "max": 12, "step": 1, "kind": "int", "order": 220},
			"wall_distance": {"label": "风障生成距离", "group": "曲面风障", "default": 82.0, "min": 10.0, "max": 500.0, "step": 2.0, "order": 230},
			"wall_curve_radius": {"label": "风障曲率半径", "group": "曲面风障", "default": 74.0, "min": 10.0, "max": 500.0, "step": 2.0, "order": 240},
			"wall_arc_degrees": {"label": "风障展开角度", "group": "曲面风障", "default": 120.0, "min": 20.0, "max": 300.0, "step": 5.0, "order": 250, "suffix": "°"},
			"wall_thickness": {"label": "风障拦截厚度", "group": "曲面风障", "default": 12.0, "min": 1.0, "max": 100.0, "step": 1.0, "order": 260},
			"wall_activation_lookahead": {"label": "风障起手预判", "group": "曲面风障", "default": 0.05, "min": 0.0, "max": 0.5, "step": 0.01, "order": 270, "suffix": " 秒"},
			"skill_standstill_duration": {"label": "施法立定时间", "group": "施法动作", "default": 1.0, "min": 0.0, "max": 10.0, "step": 0.05, "order": 310, "suffix": " 秒"},
		},
	}, AbilityScript, VisualScript)
