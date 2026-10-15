extends BallModule

const AbilityScript := preload("res://scripts/balls/heavy_industry/ability.gd")
const VisualScript := preload("res://scripts/balls/heavy_industry/visual.gd")
const UnitReadyVoice := preload("res://scripts/balls/heavy_industry/audio/unit_ready.ogg")

func _init() -> void:
	super({
		"id": "heavy_industry",
		"name": "重工球",
		"color": "7b292d",
		"accent": "f5bd45",
		"title_color": "ffd66b",
		"max_hp": 100.0,
		"speed": 168.0,
		"radius": 31.0,
		"cooldown": 6.0,
		"ability": "重工球会沿当前朝向周期性生产坦克，场上的坦克能够持续集结。坦克沿出仓时的直线往返，撞墙后整车掉头并沿原路继续巡逻。\n\n• 坦克可以被敌人摧毁，车身碰撞会伤害敌方主球和附属单位。\n• 炮塔会主动追踪敌人并持续发射炮弹。",
		"sound_kind": "heavy_industry_unit_ready",
		"audio_samples": {
			"heavy_industry_unit_ready": {
				"stream": UnitReadyVoice,
				"gain_db": -10.0,
			},
		},
		"sort_order": 170,
		"tuning": {
			"port_rotation_speed": {
				"label": "出仓口旋转速度", "group": "生产线", "suffix": " rad/s",
				"default": 1.35, "min": 0.0, "max": 20.0, "step": 0.05, "order": 110,
			},
			"max_tanks": {
				"label": "坦克数量上限", "group": "生产线", "kind": "int",
				"default": 12, "min": 1, "max": 100, "step": 1, "order": 120,
			},
			"tank_spawn_gap": {
				"label": "坦克出仓间距", "group": "生产线", "suffix": " px",
				"default": 5.0, "min": 0.0, "max": 120.0, "step": 0.5, "order": 130,
			},
			"deployment_animation_duration": {
				"label": "坦克出仓动画时间", "group": "生产线", "suffix": " 秒",
				"default": 0.42, "min": 0.05, "max": 5.0, "step": 0.05, "order": 140,
			},
			"tank_max_hp": {
				"label": "坦克生命值", "group": "坦克属性",
				"default": 15.0, "min": 1.0, "max": 1000.0, "step": 1.0, "order": 210,
			},
			"tank_radius": {
				"label": "坦克碰撞半径", "group": "坦克属性", "suffix": " px",
				"default": 18.0, "min": 6.0, "max": 60.0, "step": 1.0, "order": 220,
			},
			"tank_speed": {
				"label": "坦克巡弋速度", "group": "坦克属性", "suffix": " px/s",
				"default": 105.0, "min": 10.0, "max": 1000.0, "step": 5.0, "order": 230,
			},
			"tank_contact_damage": {
				"label": "坦克碰撞伤害", "group": "坦克属性",
				"default": 3.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 240,
			},
			"tank_contact_interval": {
				"label": "坦克碰撞间隔", "group": "坦克属性", "suffix": " 秒",
				"default": 0.38, "min": 0.05, "max": 5.0, "step": 0.01, "order": 250,
			},
			"turret_rotation_speed": {
				"label": "炮塔旋转速度", "group": "坦克火炮", "suffix": " rad/s",
				"default": 6.0, "min": 0.0, "max": 30.0, "step": 0.1, "order": 310,
			},
			"tank_fire_interval": {
				"label": "坦克开炮间隔", "group": "坦克火炮", "suffix": " 秒",
				"default": 2.4, "min": 0.1, "max": 30.0, "step": 0.1, "order": 320,
			},
			"shell_damage": {
				"label": "炮弹伤害", "group": "坦克火炮",
				"default": 4.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 330,
			},
			"shell_speed": {
				"label": "炮弹速度", "group": "坦克火炮", "suffix": " px/s",
				"default": 430.0, "min": 20.0, "max": 4000.0, "step": 10.0, "order": 340,
			},
			"shell_radius": {
				"label": "炮弹判定半径", "group": "坦克火炮", "suffix": " px",
				"default": 4.5, "min": 0.5, "max": 30.0, "step": 0.5, "order": 350,
			},
			"shell_lifetime": {
				"label": "炮弹存在时间", "group": "坦克火炮", "suffix": " 秒",
				"default": 3.5, "min": 0.1, "max": 20.0, "step": 0.1, "order": 360,
			},
			"shell_spawn_gap": {
				"label": "炮口出弹间距", "group": "坦克火炮", "suffix": " px",
				"default": 2.0, "min": 0.0, "max": 60.0, "step": 0.5, "order": 370,
			},
		},
	}, AbilityScript, VisualScript)
