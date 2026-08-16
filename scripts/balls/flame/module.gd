extends BallModule

const AbilityScript := preload("res://scripts/balls/flame/ability.gd")
const VisualScript := preload("res://scripts/balls/flame/visual.gd")

func _init() -> void:
	super({
		"id": "flame",
		"name": "火焰球",
		"color": "e04416",
		"accent": "ffd052",
		"max_hp": 100.0,
		"speed": 208.0,
		"radius": 27.0,
		"cooldown": 3.8,
		"ability": "灼烧轨迹 · 烈焰爆发",
		"sound_kind": "blood",
		"sort_order": 100,
		"tuning": {
			"trail_spawn_rate": {"label": "每秒生成火区", "default": 8.0, "min": 0.5, "max": 60.0, "step": 0.5, "order": 110},
			"max_fire_zones": {"label": "火区数量上限", "default": 42, "min": 1, "max": 200, "step": 1, "kind": "int", "order": 120},
			"fire_zone_duration": {"label": "火区持续时间", "default": 2.5, "min": 0.1, "max": 30.0, "step": 0.1, "order": 130, "suffix": " 秒"},
			"fire_zone_radius": {"label": "火区半径", "default": 28.0, "min": 2.0, "max": 200.0, "step": 1.0, "order": 140},
			"fire_zone_absorption_radius_cap": {"label": "火区可吞噬半径上限", "default": 12.0, "min": 1.0, "max": 200.0, "step": 1.0, "order": 142},
			"fire_zone_absorption_radius_ratio": {"label": "火区可吞噬半径比例", "default": 0.35, "min": 0.01, "max": 2.0, "step": 0.01, "order": 144},
			"burn_tick_interval": {"label": "灼烧伤害间隔", "default": 0.34, "min": 0.05, "max": 5.0, "step": 0.01, "order": 150, "suffix": " 秒"},
			"burn_damage": {"label": "每次灼烧伤害", "default": 3.4, "min": 0.0, "max": 500.0, "step": 0.1, "order": 160},
			"burst_radius": {"label": "烈焰爆发半径", "default": 195.0, "min": 0.0, "max": 900.0, "step": 5.0, "order": 170},
			"burst_damage": {"label": "烈焰爆发伤害", "default": 13.4, "min": 0.0, "max": 500.0, "step": 0.1, "order": 180},
		},
	}, AbilityScript, VisualScript)
