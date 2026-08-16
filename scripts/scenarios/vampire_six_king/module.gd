extends "res://scripts/scenarios/core/battle_scenario.gd"

func _init() -> void:
	id = "vampire_six_king_showcase"
	left_ball_id = "vampire"
	right_ball_id = "six_king"
	left_profile = "showcase"
	right_profile = "showcase"
	contact_cooldown = 0.42
	collision_impulse = 0.91
	trail_interval = 0.045
	left_spawn_position = Vector2(168.0, 310.0)
	right_spawn_position = Vector2(466.0, 326.0)
	left_spawn_velocity = Vector2(188.0, 126.0)
	right_spawn_velocity = Vector2(-151.0, -174.0)
	randomize_spawn_angle = false
	left_timer_offset = 1.0
	right_timer_offset = 1.0

func initial_stats() -> Dictionary:
	return {
		"anchors_spawned": 0,
		"tracks_spawned": 0,
		"checker_hits": 0,
		"tether_hits": 0,
		"track_hits": 0,
		"blood_bursts": 0,
	}
