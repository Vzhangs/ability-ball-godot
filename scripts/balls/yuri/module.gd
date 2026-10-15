extends BallModule

const AbilityScript := preload("res://scripts/balls/yuri/ability.gd")
const VisualScript := preload("res://scripts/balls/yuri/visual.gd")

func _init() -> void:
	super({
		"id": "yuri",
		"name": "尤里球",
		"color": "4c205f",
		"accent": "f07cff",
		"title_color": "f7b6ff",
		"max_hp": 100.0,
		"speed": 150.0,
		"radius": 27.0,
		"cooldown": 3.5,
		"ability": "尤里球会周期性永久夺取附近的敌方附属单位，并让原主人受到反噬。\n\n• 被控制的单位会改为跟随尤里球；原本能够攻击的附属单位也会替新主人继续作战。\n• 控制数量超过承受能力后，尤里球会因心灵过载持续失血；超额越多，反噬越重，达到控制上限后无法再夺取新目标。\n• 子弹和炮弹无法被心灵控制；附近没有可控制目标时，技能不会发动。",
		"sound_kind": "psychic_pulse",
		"sort_order": 120,
		"tuning": {
			"control_range": {"label": "心灵控制范围", "group": "心灵控制", "default": 360.0, "min": 20.0, "max": 1000.0, "step": 5.0, "order": 110},
			"max_control_per_cast": {"label": "单次控制数量", "group": "心灵控制", "default": 1, "min": 1, "max": 100, "step": 1, "kind": "int", "order": 120},
			"max_controlled_total": {"label": "控制总数硬上限", "group": "心灵控制", "default": 8, "min": 1, "max": 300, "step": 1, "kind": "int", "order": 130},
			"controlled_velocity_multiplier": {"label": "倒戈速度倍率", "group": "心灵控制", "default": 1.05, "min": 0.1, "max": 5.0, "step": 0.05, "order": 140},
			"control_backlash_damage": {"label": "夺取反噬伤害", "group": "心灵控制", "default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 150},
			"soft_controlled_total": {"label": "软控制上限", "group": "心灵过载", "default": 3, "min": 0, "max": 300, "step": 1, "kind": "int", "order": 210, "tooltip": "超过后开始心灵过载；实际软上限不会高于控制总数硬上限。"},
			"control_overload_damage_per_excess_per_second": {"label": "每个超额单位每秒过载伤害", "group": "心灵过载", "default": 1.5, "min": 0.0, "max": 500.0, "step": 0.25, "order": 220},
			"control_overload_tick_interval": {"label": "心灵过载掉血间隔", "group": "心灵过载", "default": 1.0, "min": 0.1, "max": 10.0, "step": 0.1, "order": 230, "suffix": " 秒"},
			"pulse_duration": {"label": "精神波持续时间", "group": "视觉表现", "default": 0.72, "min": 0.1, "max": 5.0, "step": 0.05, "order": 310, "suffix": " 秒"},
			"link_duration": {"label": "控制链持续时间", "group": "视觉表现", "default": 0.55, "min": 0.1, "max": 5.0, "step": 0.05, "order": 320, "suffix": " 秒"},
			"control_overload_effect_duration": {"label": "过载反馈持续时间", "group": "视觉表现", "default": 0.42, "min": 0.1, "max": 2.0, "step": 0.02, "order": 330, "suffix": " 秒"},
		},
	}, AbilityScript, VisualScript)
