extends BallModule

const AbilityScript := preload("res://scripts/balls/iron_curtain/ability.gd")
const VisualScript := preload("res://scripts/balls/iron_curtain/visual.gd")
const IronCurtainActivationSound := preload("res://scripts/balls/iron_curtain/audio/iron_curtain_activation.ogg")
const IronDragonFireSound := preload("res://scripts/balls/iron_curtain/audio/iron_dragon_fire.ogg")
const IronDragonTransformationSound := preload("res://scripts/balls/iron_curtain/audio/iron_dragon_transformation.ogg")

func _init() -> void:
	super({
		"id": "iron_curtain",
		"name": "铁龙球",
		"color": "30343a",
		"accent": "ff3e32",
		"title_color": "ff765e",
		"max_hp": 100.0,
		"speed": 172.0,
		"radius": 30.0,
		"cooldown": 7.0,
		"ability": "铁龙球会周期性向敌人发射大型能量弹。能量弹能够直接伤害主球或附属单位，碰到目标或墙壁后还会留下不分敌我的持续伤害区域。\n\n• 生命降到危险程度时，铁龙球会短暂停止整个战场并永久变身为铁幕球。\n• 铁幕球会周期性展开保护区域，使进入其中的友军主球和附属单位暂时无敌，同时持续伤害敌军。\n• 大型能量弹和两种区域都能被黑洞捕获并吞噬。",
		"sound_kind": "",
		"audio_samples": {
			"iron_curtain_activation": {
				"stream": IronCurtainActivationSound,
				"gain_db": -19.0,
			},
			"iron_dragon_fire": {
				"stream": IronDragonFireSound,
				"gain_db": -14.0,
			},
			"iron_curtain_transform": {
				"stream": IronDragonTransformationSound,
				"gain_db": -9.0,
			},
		},
		"sort_order": 201,
		"tuning": {
			"protection_zone_duration": {
				"label": "圆形铁幕持续时间", "group": "铁幕形态", "suffix": " 秒",
				"default": 3.0, "min": 0.1, "max": 30.0, "step": 0.1, "order": 110,
			},
			"protection_zone_radius": {
				"label": "圆形铁幕半径", "group": "铁幕形态", "suffix": " px",
				"default": 112.0, "min": 20.0, "max": 600.0, "step": 2.0, "order": 120,
			},
			"invulnerability_duration": {
				"label": "友军无敌时间", "group": "铁幕形态", "suffix": " 秒",
				"default": 3.0, "min": 0.1, "max": 30.0, "step": 0.1, "order": 130,
			},
			"hostile_damage_interval": {
				"label": "敌军受伤间隔", "group": "铁幕形态", "suffix": " 秒",
				"default": 0.5, "min": 0.05, "max": 5.0, "step": 0.05, "order": 140,
			},
			"hostile_damage": {
				"label": "敌军每次伤害", "group": "铁幕形态",
				"default": 1.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 150,
			},
			"transform_hp_percent": {
				"label": "变身生命阈值", "group": "铁幕变身", "suffix": "%",
				"default": 40.0, "min": 1.0, "max": 100.0, "step": 1.0, "order": 210,
			},
			"transform_animation_duration": {
				"label": "变身动画时间", "group": "铁幕变身", "suffix": " 秒",
				"default": 0.75, "min": 0.1, "max": 5.0, "step": 0.05, "order": 220,
			},
			"transform_world_stop_duration": {
				"label": "变身世界停止时间", "group": "铁幕变身", "suffix": " 秒",
				"default": 1.0, "min": 0.0, "max": 5.0, "step": 0.05, "order": 230,
			},
			"dragon_fire_interval": {
				"label": "铁龙开炮间隔", "group": "铁龙粒子炮", "suffix": " 秒",
				"default": 3.6, "min": 0.1, "max": 30.0, "step": 0.1, "order": 310,
			},
			"projectile_speed": {
				"label": "大型能量弹速度", "group": "铁龙粒子炮", "suffix": " px/s",
				"default": 390.0, "min": 20.0, "max": 4000.0, "step": 10.0, "order": 320,
			},
			"projectile_radius": {
				"label": "大型能量弹半径", "group": "铁龙粒子炮", "suffix": " px",
				"default": 13.0, "min": 2.0, "max": 80.0, "step": 1.0, "order": 330,
			},
			"projectile_impact_damage": {
				"label": "大型能量弹命中伤害", "group": "铁龙粒子炮",
				"default": 10.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 340,
			},
			"projectile_lifetime": {
				"label": "大型能量弹最长存在时间", "group": "铁龙粒子炮", "suffix": " 秒",
				"default": 5.0, "min": 0.1, "max": 30.0, "step": 0.1, "order": 350,
			},
			"projectile_spawn_gap": {
				"label": "炮口出弹间距", "group": "铁龙粒子炮", "suffix": " px",
				"default": 6.0, "min": 0.0, "max": 120.0, "step": 0.5, "order": 360,
			},
			"maximum_active_projectiles": {
				"label": "大型能量弹上限", "group": "铁龙粒子炮", "kind": "int",
				"default": 6, "min": 1, "max": 100, "step": 1, "order": 370,
			},
			"muzzle_flash_duration": {
				"label": "粒子炮炮口闪光时间", "group": "铁龙粒子炮", "suffix": " 秒",
				"default": 0.32, "min": 0.05, "max": 3.0, "step": 0.05, "order": 380,
			},
			"hazard_zone_duration": {
				"label": "失控铁幕持续时间", "group": "失控铁幕", "suffix": " 秒",
				"default": 4.0, "min": 0.1, "max": 30.0, "step": 0.1, "order": 410,
			},
			"hazard_zone_radius": {
				"label": "失控铁幕半径", "group": "失控铁幕", "suffix": " px",
				"default": 94.0, "min": 20.0, "max": 600.0, "step": 2.0, "order": 420,
			},
			"hazard_damage_interval": {
				"label": "失控铁幕受伤间隔", "group": "失控铁幕", "suffix": " 秒",
				"default": 0.5, "min": 0.05, "max": 5.0, "step": 0.05, "order": 430,
			},
			"hazard_damage": {
				"label": "失控铁幕每次伤害", "group": "失控铁幕",
				"default": 2.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 440,
			},
			"field_absorption_radius": {
				"label": "铁幕吞噬判定半径", "group": "失控铁幕", "suffix": " px",
				"default": 22.0, "min": 1.0, "max": 120.0, "step": 1.0, "order": 450,
			},
			"maximum_active_fields": {
				"label": "场上铁幕区域上限", "group": "失控铁幕", "kind": "int",
				"default": 8, "min": 1, "max": 100, "step": 1, "order": 460,
			},
		},
	}, AbilityScript, VisualScript)
