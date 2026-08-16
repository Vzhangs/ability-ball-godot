extends BallModule

const AbilityScript := preload("res://scripts/balls/six_king/ability.gd")
const VisualScript := preload("res://scripts/balls/six_king/visual.gd")

func _init() -> void:
	super({
		"id": "six_king",
		"name": "六王球",
		"color": "f0cf32",
		"accent": "75dfff",
		"max_hp": 100.0,
		"speed": 190.0,
		"radius": 28.0,
		"cooldown": 3.8,
		"ability": "六向锚点 · 轨道审判",
		"sound_kind": "judgment",
		"sort_order": 20,
		"tuning": {
			"anchor_count": {"label": "锚点数量", "default": 6, "min": 1, "max": 6, "step": 1, "kind": "int", "order": 110},
			"anchor_duration": {"label": "锚点持续时间", "default": 1.15, "min": 0.1, "max": 10.0, "step": 0.05, "order": 120, "suffix": " 秒"},
			"anchor_hit_width": {"label": "连线命中宽度", "default": 1.25, "min": 0.0, "max": 30.0, "step": 0.25, "order": 130},
			"judgment_damage": {"label": "审判伤害", "default": 11.4, "min": 0.0, "max": 500.0, "step": 0.2, "order": 140},
			"anchor_edge_margin": {"label": "锚点离墙距离", "default": 6.0, "min": 0.0, "max": 200.0, "step": 1.0, "order": 150},
			"anchor_edge_inset": {"label": "顶部锚点角落间距", "default": 70.0, "min": 0.0, "max": 320.0, "step": 1.0, "order": 160},
			"anchor_side_inset_ratio": {"label": "侧边锚点纵向比例", "default": 0.25, "min": 0.0, "max": 0.5, "step": 0.01, "order": 170},
		},
	}, AbilityScript, VisualScript)
