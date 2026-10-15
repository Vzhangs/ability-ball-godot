extends BallModule

const AbilityScript := preload("res://scripts/balls/train_conductor/ability.gd")
const VisualScript := preload("res://scripts/balls/train_conductor/visual.gd")
const TrainWhistle := preload("res://scripts/balls/train_conductor/audio/train_whistle.wav")

func _init() -> void:
	super({
		"id": "train_conductor",
		"name": "列车长",
		"color": "173b56",
		"accent": "f0b84a",
		"title_color": "9ee8ff",
		"max_hp": 100.0,
		"speed": 188.0,
		"radius": 29.0,
		"cooldown": 4.0,
		"ability": "列车长第一次撞墙后会开始沿真实运动路线铺设铁轨，后续撞墙会继续延长同一条线路。轨道积累到足够长度后，列车会从最早的铺轨起点驶入并跑完整条路线。\n\n• 列车撞到敌方主球或具备实体碰撞的附属单位时会造成伤害并把目标推开；持续压住同一目标不会无间隔重复伤害。\n• 必须等整列火车通过并清除旧铁轨，下一次撞墙才能开启新一轮铺轨。铁轨和列车都能被黑洞捕获吞噬。",
		"sound_kind": "track",
		"audio_samples": {
			"train_conductor_whistle": {
				"stream": TrainWhistle,
				"gain_db": -12.0,
			},
		},
		"sort_order": 197,
		"tuning": {
			"track_sample_spacing": {
				"label": "轨迹采样间距", "group": "铺轨", "suffix": " px",
				"default": 9.0, "min": 3.0, "max": 80.0, "step": 1.0, "order": 110,
			},
			"track_settlement_interval": {
				"label": "轨道分段结算间隔", "group": "铺轨", "suffix": " 秒",
				"default": 0.8, "min": 0.1, "max": 20.0, "step": 0.1, "order": 120,
			},
			"track_minimum_length": {
				"label": "最短发车线路", "group": "铺轨", "suffix": " px",
				"default": 80.0, "min": 10.0, "max": 1600.0, "step": 5.0, "order": 130,
			},
			"track_absorption_radius": {
				"label": "轨道吞噬判定半径", "group": "铺轨", "suffix": " px",
				"default": 18.0, "min": 1.0, "max": 100.0, "step": 1.0, "order": 140,
			},
			"wall_contacts_per_departure": {
				"label": "每轮发车撞墙次数", "group": "铺轨", "kind": "int",
				"default": 4, "min": 2, "max": 30, "step": 1, "order": 150,
			},
			"finalized_track_linger": {
				"label": "列车通过后轨道停留", "group": "铺轨", "suffix": " 秒",
				"default": 0.15, "min": 0.0, "max": 30.0, "step": 0.05, "order": 160,
			},
			"train_speed": {
				"label": "列车速度", "group": "列车", "suffix": " px/s",
				"default": 420.0, "min": 20.0, "max": 2400.0, "step": 10.0, "order": 210,
			},
			"train_entry_delay": {
				"label": "鸣笛后发车等待", "group": "列车", "suffix": " 秒",
				"default": 0.1, "min": 0.0, "max": 3.0, "step": 0.02, "order": 215,
			},
			"train_contact_damage": {
				"label": "列车碰撞伤害", "group": "列车",
				"default": 12.0, "min": 0.0, "max": 1000.0, "step": 0.5, "order": 220,
			},
			"train_contact_interval": {
				"label": "列车重复碰撞间隔", "group": "列车", "suffix": " 秒",
				"default": 0.45, "min": 0.05, "max": 5.0, "step": 0.05, "order": 230,
			},
			"train_carriage_count": {
				"label": "列车车厢数量", "group": "列车", "kind": "int",
				"default": 9, "min": 0, "max": 16, "step": 1, "order": 240,
			},
			"train_car_radius": {
				"label": "列车碰撞半径", "group": "列车", "suffix": " px",
				"default": 19.0, "min": 5.0, "max": 50.0, "step": 1.0, "order": 250,
			},
			"train_car_spacing": {
				"label": "车头与车厢间距", "group": "列车", "suffix": " px",
				"default": 48.0, "min": 10.0, "max": 120.0, "step": 1.0, "order": 260,
			},
			"train_absorption_radius": {
				"label": "列车吞噬判定半径", "group": "列车", "suffix": " px",
				"default": 20.0, "min": 1.0, "max": 100.0, "step": 1.0, "order": 270,
			},
			"max_active_train_units": {
				"label": "场上列车单元上限", "group": "列车", "kind": "int",
				"default": 60, "min": 1, "max": 120, "step": 1, "order": 280,
			},
		},
	}, AbilityScript, VisualScript)
