extends BallModule

const AbilityScript := preload("res://scripts/balls/blade_dancer/ability.gd")
const VisualScript := preload("res://scripts/balls/blade_dancer/visual.gd")
const BladeSliceSound := preload("res://scripts/balls/blade_dancer/audio/blade_slice.ogg")

func _init() -> void:
	super({
		"id": "blade_dancer",
		"name": "女刀球",
		"color": "6750b8",
		"accent": "8fd8ff",
		"title_color": "c9edff",
		"max_hp": 100.0,
		"speed": 190.0,
		"radius": 28.0,
		"cooldown": 3.0,
		"ability": "女刀球出生时带着一组细长无柄刀，刀阵贴身环绕她移动。每把刀第一次接触敌方主球或附属单位都会造成伤害；持续贴住不会重复结算，分开后再次接触才会重新受伤。\n\n• 女刀球会周期性锁定释放瞬间盯上的敌人，高速追到对方面前并完成突进撞击。\n• 突进后稍作延迟，仍受自己掌控的刀阵会快速旋转横扫，每把刀都能独立命中目标。\n• 尤里球可以逐把永久控制这些刀；被夺走的刀会改为环绕尤里球，并转过来攻击女刀球原本的阵营。",
		"sound_kind": "wind_cast",
		"audio_samples": {
			"blade_dancer_blade_slice": {
				"stream": BladeSliceSound,
				"gain_db": -14.0,
			},
		},
		"sort_order": 196,
		"tuning": {
			"blade_count": {
				"label": "出生刀刃数量", "group": "扇形刀阵", "kind": "int",
				"default": 6, "min": 1, "max": 32, "step": 1, "order": 110,
			},
			"blade_length": {
				"label": "刀刃长度", "group": "扇形刀阵", "suffix": " px",
				"default": 38.0, "min": 10.0, "max": 160.0, "step": 1.0, "order": 120,
			},
			"blade_width": {
				"label": "刀刃宽度", "group": "扇形刀阵", "suffix": " px",
				"default": 6.0, "min": 2.0, "max": 40.0, "step": 0.5, "order": 130,
			},
			"blade_orbit_radius": {
				"label": "刀阵环绕半径", "group": "扇形刀阵", "suffix": " px",
				"default": 48.0, "min": 12.0, "max": 220.0, "step": 1.0, "order": 140,
			},
			"fan_arc_degrees": {
				"label": "扇形展开角度", "group": "扇形刀阵", "suffix": "°",
				"default": 105.0, "min": 0.0, "max": 300.0, "step": 1.0, "order": 150,
			},
			"blade_tilt_degrees": {
				"label": "刀刃切入倾角", "group": "扇形刀阵", "suffix": "°",
				"default": 45.0, "min": -180.0, "max": 180.0, "step": 1.0, "order": 155,
			},
			"blade_orbit_speed_degrees": {
				"label": "刀阵环绕速度", "group": "扇形刀阵", "suffix": "°/秒",
				"default": 40.0, "min": -720.0, "max": 720.0, "step": 1.0, "order": 160,
			},
			"blade_damage": {
				"label": "每把刀接触伤害", "group": "扇形刀阵",
				"default": 3.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 170,
			},
			"dash_speed": {
				"label": "突进速度", "group": "利刃突进", "suffix": " px/秒",
				"default": 720.0, "min": 50.0, "max": 5000.0, "step": 10.0, "order": 210,
			},
			"dash_damage": {
				"label": "突进撞击伤害", "group": "利刃突进",
				"default": 6.0, "min": 0.0, "max": 500.0, "step": 0.5, "order": 220,
			},
			"dash_max_duration": {
				"label": "单次突进最长时间", "group": "利刃突进", "suffix": " 秒",
				"default": 0.55, "min": 0.05, "max": 5.0, "step": 0.05, "order": 230,
			},
			"blade_spin_delay": {
				"label": "突进后刀阵旋转延迟", "group": "利刃突进", "suffix": " 秒",
				"default": 0.25, "min": 0.0, "max": 3.0, "step": 0.05, "order": 235,
			},
			"blade_spin_duration": {
				"label": "刀阵快旋持续时间", "group": "利刃突进", "suffix": " 秒",
				"default": 1.0, "min": 0.05, "max": 5.0, "step": 0.05, "order": 240,
			},
			"blade_spin_turns": {
				"label": "刀阵快旋圈数", "group": "利刃突进", "suffix": " 圈",
				"default": 1.0, "min": 0.0, "max": 12.0, "step": 0.1, "order": 250,
			},
			"dash_afterimage_interval": {
				"label": "突进残影间隔", "group": "利刃突进", "suffix": " 秒",
				"default": 0.035, "min": 0.005, "max": 0.5, "step": 0.005, "order": 260,
			},
			"dash_afterimage_duration": {
				"label": "突进残影持续时间", "group": "利刃突进", "suffix": " 秒",
				"default": 0.5, "min": 0.05, "max": 2.0, "step": 0.01, "order": 270,
			},
		},
	}, AbilityScript, VisualScript)
