extends BallModule

const AbilityScript := preload("res://scripts/balls/qing/ability.gd")
const VisualScript := preload("res://scripts/balls/qing/visual.gd")

func _init() -> void:
	super({
		"id": "qing", "name": "晴球", "color": "eee9cf", "accent": "75e5ff",
		"title_color": "75e5ff", "max_hp": 100.0, "speed": 185, "radius": 27.0,
		"cooldown": 5, "sort_order": 250, "sound_kind": "",
		"ability": "晴球会持续补充雅典娜三号，达到部署上限后暂停补充。\n\n• 同一主人控制的雅典娜三号之间会两两连起电弧，对接触的敌方主球与可受伤单位周期造成伤害并短暂瘫痪。\n• 召唤物可以被攻击、吞噬或夺取；摧毁连线端点或离开电弧都能脱离封锁。\n• 被捕获的召唤物不能维持电弧，被夺取后只与新主人的同类召唤物连接。本体与召唤物的普通碰撞不额外造成伤害。",
		"tuning": {
			"max_drones": {"label": "雅典娜部署上限", "default": 3, "min": 1, "max": 12, "step": 1, "group": "雅典娜三号", "order": 110, "kind": "int"},
			"drone_hp": {"label": "雅典娜生命值", "default": 20, "min": 1, "max": 1000, "step": 1, "group": "雅典娜三号", "order": 120},
			"drone_radius": {"label": "雅典娜半径", "default": 17, "min": 5, "max": 60, "step": 1, "group": "雅典娜三号", "order": 130},
			"drone_speed": {"label": "雅典娜移动速度", "default": 145, "min": 10, "max": 600, "step": 5, "group": "雅典娜三号", "order": 140},
			"spawn_gap": {"label": "部署间距", "default": 8, "min": 0, "max": 80, "step": 1, "group": "雅典娜三号", "order": 150},
			"contact_interval": {"label": "单位碰撞间隔", "default": 0.38, "min": 0.05, "max": 3, "step": 0.01, "group": "雅典娜三号", "order": 160},
			"arc_damage": {"label": "电弧接触伤害", "default": 3, "min": 0, "max": 100, "step": 0.5, "group": "电弧", "order": 170},
			"arc_interval": {"label": "电弧伤害间隔", "default": 0.6, "min": 0.1, "max": 5, "step": 0.05, "group": "电弧", "order": 180},
			"arc_half_width": {"label": "电弧判定半宽", "default": 4, "min": 1, "max": 30, "step": 0.5, "group": "电弧", "order": 190},
			"paralysis_duration": {"label": "电弧瘫痪时间", "default": 0.2, "min": 0.01, "max": 3, "step": 0.01, "group": "电弧", "order": 200},
			"arc_charge_time": {"label": "电弧接通时间", "default": 0.18, "min": 0.01, "max": 2, "step": 0.01, "group": "部署表现", "order": 210},
			"deploy_duration": {"label": "部署展开时间", "default": 0.3, "min": 0.05, "max": 2, "step": 0.05, "group": "部署表现", "order": 220},
		},
	}, AbilityScript, VisualScript)
