extends BallModule

const AbilityScript := preload("res://scripts/balls/replicator/ability.gd")
const VisualScript := preload("res://scripts/balls/replicator/visual.gd")

func _init() -> void:
	super({
		"id": "replicator",
		"name": "浮游炮",
		"color": "26a883",
		"accent": "83ffd9",
		"max_hp": 100.0,
		"speed": 185.0,
		"radius": 27.0,
		"cooldown": 3.0,
		"ability": "浮游炮会周期性制造环绕自身的小炮，数量增加后会自动扩展为多层炮群。\n\n• 每次新炮出现时，本体和全部浮游炮会一起朝最近的敌方主球齐射。\n• 子弹可以被其他单位挡住，也会被风墙或黑洞拦截；浮游炮若被尤里球永久控制，会改为跟随新主人并攻击原阵营。",
		"sound_kind": "track",
		"sort_order": 70,
		"tuning": {
			"max_cannons": {"label": "浮游炮数量上限", "default": 22, "min": 1, "max": 50, "step": 1, "kind": "int", "order": 110},
			"inner_ring_capacity": {"label": "第一层容量", "default": 8, "min": 1, "max": 25, "step": 1, "kind": "int", "order": 120},
			"inner_orbit_radius": {"label": "第一层轨道半径", "default": 54.0, "min": 20.0, "max": 250.0, "step": 1.0, "order": 130},
			"outer_orbit_radius": {"label": "第二层轨道半径", "default": 82.0, "min": 20.0, "max": 350.0, "step": 1.0, "order": 140},
			"cannon_radius_scale": {"label": "浮游炮尺寸倍率", "default": 0.36, "min": 0.1, "max": 1.5, "step": 0.01, "order": 150},
			"orbit_speed": {"label": "浮游炮旋转速度", "default": 2.55, "min": 0.0, "max": 20.0, "step": 0.05, "order": 160},
			"projectile_damage": {"label": "子弹伤害", "group": "子弹参数", "default": 3.0, "min": 0.0, "max": 500.0, "step": 0.1, "order": 210},
			"projectile_speed": {"label": "子弹速度", "group": "子弹参数", "default": 305.0, "min": 10.0, "max": 2000.0, "step": 5.0, "order": 220},
			"projectile_radius": {"label": "子弹半径", "group": "子弹参数", "default": 5.0, "min": 1.0, "max": 50.0, "step": 1.0, "order": 230},
			"projectile_lifetime": {"label": "子弹寿命", "group": "子弹参数", "default": 3.0, "min": 0.1, "max": 20.0, "step": 0.1, "order": 240, "suffix": " 秒"},
			"projectile_spread": {"label": "子弹散布角", "group": "子弹参数", "default": 0.1, "min": 0.0, "max": 1.5, "step": 0.01, "order": 250},
		},
	}, AbilityScript, VisualScript)
