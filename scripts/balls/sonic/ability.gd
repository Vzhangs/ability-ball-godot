extends BallAbility

const WAVE_LAYER_COUNT := 4
const WAVE_LAYER_DELAY := 0.09
const WAVE_DURATION := 0.48
const WAVE_START_RADIUS_SCALE := 0.9
const WAVE_END_RADIUS_SCALE := 3.2

var _speed_multiplier := 1.0
var _pending_waves: Array[Dictionary] = []

func on_battle_started(_battle, fighter, _opponent, _side: int) -> void:
	_speed_multiplier = 1.0
	_pending_waves.clear()
	# 第一次增长等待完整冷却，避免复用通用开局错峰后提前到 0.6 秒触发。
	fighter.ability_timer = fighter.cooldown

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return _speed_multiplier

func contact_damage(_battle, _fighter, _opponent) -> float:
	return settingf("body_impact_damage") * _speed_multiplier

func on_step(battle, _fighter, _opponent, _side: int, delta: float) -> void:
	for index in range(_pending_waves.size() - 1, -1, -1):
		var wave: Dictionary = _pending_waves[index]
		wave["delay"] = float(wave["delay"]) - delta
		if float(wave["delay"]) > 0.0:
			_pending_waves[index] = wave
			continue
		_spawn_wave_layer(battle, wave)
		_pending_waves.remove_at(index)

func activate(battle, fighter, _opponent, _side: int) -> void:
	_speed_multiplier *= 1.0 + settingf("speed_growth_ratio")
	var first_wave := _wave_data(fighter, 0.0)
	_spawn_wave_layer(battle, first_wave)
	for layer_index in range(1, WAVE_LAYER_COUNT):
		_pending_waves.append(_wave_data(fighter, float(layer_index) * WAVE_LAYER_DELAY))

func _wave_data(fighter, delay: float) -> Dictionary:
	return {
		"delay": delay,
		"position": fighter.pos,
		"color": fighter.accent,
		"start_radius": fighter.radius * WAVE_START_RADIUS_SCALE,
		"end_radius": fighter.radius * WAVE_END_RADIUS_SCALE,
	}

func _spawn_wave_layer(battle, wave: Dictionary) -> void:
	battle.spawn_ring(
		wave["position"],
		wave["color"],
		float(wave["start_radius"]),
		float(wave["end_radius"]),
		WAVE_DURATION
	)
