extends BallModule

const AbilityScript := preload("res://scripts/balls/black_hole/ability.gd")
const VisualScript := preload("res://scripts/balls/black_hole/visual.gd")

func _init() -> void:
	super({
		"id": "black_hole",
		"name": "黑洞球",
		"color": "24123f",
		"accent": "bc63ff",
		"title_color": "9f55e8",
		"max_hp": 100.0,
		"speed": 172.0,
		"radius": 30.0,
		"cooldown": 6.3,
		"ability": "黑洞球会周期性展开黑洞。靠近的敌方主球会被拉入不断收紧的旋转轨道，并在受牵引撞墙时受到伤害。\n\n• 子弹、分身、植物、蛛丝和列车等敌方附属物进入捕获范围后会立刻失去行动，随后被黑洞吞噬。\n• 黑洞只捕获和吞噬，不会夺取这些附属物的所有权。",
		"sound_kind": "judgment",
		"sort_order": 40,
		"tuning": {
			"active_duration": {"label": "技能持续时间", "default": 2.35, "min": 0.1, "max": 20.0, "step": 0.05, "order": 110, "suffix": " 秒"},
			"active_speed_multiplier": {"label": "发动时自身速度倍率", "default": 0.62, "min": 0.1, "max": 2.0, "step": 0.01, "order": 120},
			"vortex_radius": {"label": "漩涡可视半径", "default": 190.0, "min": 20.0, "max": 600.0, "step": 5.0, "order": 130},
			"max_orbit_entry_radius": {"label": "本体最大入轨半径", "default": 285.0, "min": 50.0, "max": 700.0, "step": 5.0, "order": 140},
			"capture_radius": {"label": "附属物捕获半径", "default": 410.0, "min": 20.0, "max": 900.0, "step": 5.0, "order": 150},
			"consume_radius": {"label": "事件视界吞噬半径", "default": 72.0, "min": 5.0, "max": 300.0, "step": 1.0, "order": 160},
			"capture_min_age": {"label": "最短吞噬等待", "default": 0.22, "min": 0.0, "max": 5.0, "step": 0.01, "order": 170, "suffix": " 秒"},
			"capture_shrink_speed_min": {"label": "捕获收缩最低速度", "default": 82.0, "min": 1.0, "max": 1000.0, "step": 1.0, "order": 180},
			"capture_shrink_speed_max": {"label": "捕获收缩最高速度", "default": 138.0, "min": 1.0, "max": 1500.0, "step": 1.0, "order": 190},
			"capture_angular_speed_min": {"label": "捕获最低角速度", "default": 1.35, "min": 0.0, "max": 20.0, "step": 0.05, "order": 200},
			"capture_angular_speed_max": {"label": "捕获最高角速度", "default": 4.8, "min": 0.0, "max": 30.0, "step": 0.1, "order": 210},
			"absorption_duration": {"label": "吞噬消失时长", "default": 0.2, "min": 0.05, "max": 5.0, "step": 0.05, "order": 220, "suffix": " 秒"},
			"orbit_gap": {"label": "最终轨道间距", "group": "本体牵引", "default": 42.0, "min": 0.0, "max": 200.0, "step": 1.0, "order": 310},
			"orbit_tangent_speed": {"label": "轨道切向速度", "group": "本体牵引", "default": 256.0, "min": 0.0, "max": 1000.0, "step": 1.0, "order": 320},
			"orbit_radial_response": {"label": "轨道径向响应", "group": "本体牵引", "default": 2.9, "min": 0.0, "max": 20.0, "step": 0.1, "order": 330},
			"orbit_inward_speed_min": {"label": "径向吸入速度下限", "group": "本体牵引", "default": 0.0, "min": 0.0, "max": 500.0, "step": 1.0, "order": 340},
			"orbit_inward_speed_max": {"label": "径向吸入速度上限", "group": "本体牵引", "default": 205.0, "min": 0.0, "max": 1000.0, "step": 1.0, "order": 350},
			"orbit_tangent_error_scale": {"label": "半径误差切向修正", "group": "本体牵引", "default": 0.12, "min": 0.0, "max": 5.0, "step": 0.01, "order": 360},
			"orbit_tangent_adjust_min": {"label": "切向修正下限", "group": "本体牵引", "default": -18.0, "min": -500.0, "max": 500.0, "step": 1.0, "order": 370},
			"orbit_tangent_adjust_max": {"label": "切向修正上限", "group": "本体牵引", "default": 28.0, "min": -500.0, "max": 500.0, "step": 1.0, "order": 380},
			"orbit_steering_start": {"label": "初始转向响应", "group": "本体牵引", "default": 1.55, "min": 0.0, "max": 20.0, "step": 0.05, "order": 390},
			"orbit_steering_end": {"label": "最终转向响应", "group": "本体牵引", "default": 4.4, "min": 0.0, "max": 30.0, "step": 0.1, "order": 400},
			"orbit_centripetal_scale": {"label": "向心加速度倍率", "group": "本体牵引", "default": 0.18, "min": 0.0, "max": 5.0, "step": 0.01, "order": 410},
			"max_tether_speed": {"label": "牵引最高速度", "group": "本体牵引", "default": 465.0, "min": 20.0, "max": 1500.0, "step": 5.0, "order": 420},
			"tether_speed_buffer": {"label": "牵引速度缓冲", "group": "本体牵引", "default": 56.0, "min": 0.0, "max": 500.0, "step": 1.0, "order": 430},
			"wall_damage": {"label": "牵引撞墙伤害", "group": "本体牵引", "default": 8.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 440},
			"wall_damage_interval": {"label": "撞墙伤害间隔", "group": "本体牵引", "default": 0.5, "min": 0.05, "max": 5.0, "step": 0.01, "order": 450, "suffix": " 秒"},
		},
	}, AbilityScript, VisualScript)
