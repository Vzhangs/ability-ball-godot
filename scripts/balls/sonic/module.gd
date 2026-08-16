extends BallModule

const AbilityScript := preload("res://scripts/balls/sonic/ability.gd")
const VisualScript := preload("res://scripts/balls/sonic/visual.gd")

func _init() -> void:
	super({
		"id": "sonic",
		"name": "音速球",
		"color": "1677dc",
		"accent": "73e7ff",
		"max_hp": 100.0,
		"speed": 260.0,
		"radius": 25.0,
		"cooldown": 3.0,
		"ability": "持续加速 · 音爆冲撞",
		"sound_kind": "impact",
		"sort_order": 60,
		"tuning": {
			"speed_bonus_cap": {"label": "持续加速倍率上限", "default": 0.72, "min": 0.0, "max": 5.0, "step": 0.01, "order": 110},
			"speed_bonus_per_second": {"label": "每秒加速倍率", "default": 0.012, "min": 0.0, "max": 1.0, "step": 0.001, "order": 120},
			"body_impact_damage": {"label": "本体基础撞击伤害", "default": 12.25, "min": 0.0, "max": 500.0, "step": 0.25, "order": 130},
			"impact_speed_threshold": {"label": "速度增伤阈值", "default": 220.0, "min": 0.0, "max": 1500.0, "step": 5.0, "order": 140},
			"impact_damage_per_speed": {"label": "每点超速增伤", "default": 0.035, "min": 0.0, "max": 5.0, "step": 0.005, "order": 150},
			"impact_bonus_damage_cap": {"label": "速度增伤上限", "default": 10.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 160},
			"dash_speed": {"label": "音爆冲刺速度", "default": 630.0, "min": 20.0, "max": 2000.0, "step": 5.0, "order": 170},
			"dash_spread": {"label": "冲刺方向随机角", "default": 0.08, "min": 0.0, "max": 1.0, "step": 0.01, "order": 180},
			"sonic_blast_radius": {"label": "音爆伤害半径", "default": 300.0, "min": 0.0, "max": 900.0, "step": 5.0, "order": 190},
			"sonic_blast_damage": {"label": "音爆伤害", "default": 9.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 200},
		},
	}, AbilityScript, VisualScript)
