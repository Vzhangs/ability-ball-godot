class_name BattleScenario
extends RefCounted

## Optional matchup composition. Scenarios may select ball-owned profiles and global pacing,
## but never implement a ball's private ability behavior.

var id := ""
var left_ball_id := ""
var right_ball_id := ""
var left_profile := "default"
var right_profile := "default"
var max_battle_time := 120.0
var damage_scale := 0.5
var recovery_scale := 0.5
var contact_cooldown := 0.38
var collision_impulse := 0.92
var trail_interval := 0.055
var left_spawn_position := Vector2(152.0, 318.0)
var right_spawn_position := Vector2(488.0, 322.0)
var left_spawn_velocity := Vector2(186.0, -121.0)
var right_spawn_velocity := Vector2(-178.0, 132.0)
var randomize_spawn_angle := true
var left_timer_offset := 0.48
var right_timer_offset := 0.67

func matches(left_id: String, right_id: String) -> bool:
	return left_id == left_ball_id and right_id == right_ball_id

func initial_stats() -> Dictionary:
	return {}
