extends BallAbility

const PrimeTable := preload("res://scripts/balls/prime/prime_number_table.gd")

var _prime_index := 0
var _impact_count := 0
var _last_impact_prime := 0
var _impact_flash_remaining := 0.0

func on_battle_started(_battle, _fighter, _opponent, _side: int) -> void:
	_prime_index = 0
	_impact_count = 0
	_last_impact_prime = 0
	_impact_flash_remaining = 0.0

func automatic_activation_enabled() -> bool:
	return false

func on_step(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_impact_flash_remaining = maxf(0.0, _impact_flash_remaining - delta)

func contact_damage(_battle, _fighter, _opponent) -> float:
	return float(current_prime())

func after_contact(battle, fighter, opponent, damage_dealt: float) -> void:
	var impact_position: Vector2 = fighter.pos
	if opponent != null:
		impact_position = (Vector2(fighter.pos) + Vector2(opponent.pos)) * 0.5
	_complete_impact(battle, fighter, impact_position, damage_dealt)

func after_entity_contact(
	battle,
	fighter,
	entity: BallEntity,
	damage_dealt: float
) -> void:
	var impact_position: Vector2 = fighter.pos if entity == null else entity.pos
	_complete_impact(battle, fighter, impact_position, damage_dealt)

func current_prime() -> int:
	return PrimeTable.value_at(_prime_index)

func next_prime() -> int:
	return PrimeTable.value_at(mini(_prime_index + 1, PrimeTable.COUNT - 1))

func prime_index() -> int:
	return _prime_index

func impact_count() -> int:
	return _impact_count

func last_impact_prime() -> int:
	return _last_impact_prime

func impact_flash_ratio() -> float:
	var duration := settingf("impact_flash_duration")
	return clampf(_impact_flash_remaining / maxf(0.001, duration), 0.0, 1.0)

func _complete_impact(
	battle,
	fighter,
	impact_position: Vector2,
	damage_dealt: float
) -> void:
	var used_prime := current_prime()
	_last_impact_prime = used_prime
	_impact_count += 1
	_prime_index = mini(_prime_index + 1, PrimeTable.COUNT - 1)
	_impact_flash_remaining = settingf("impact_flash_duration")
	var feedback_color: Color = fighter.accent if damage_dealt > 0.0 else fighter.color.lightened(0.25)
	battle.spawn_ring(
		impact_position,
		feedback_color,
		fighter.radius * 0.36,
		fighter.radius * 2.45,
		settingf("impact_flash_duration")
	)
	battle.spawn_particles(impact_position, feedback_color, 9, 142.0)
	battle.emit_combat_event(
		"judgment",
		clampf(0.32 + log(float(used_prime) + 1.0) * 0.055, 0.32, 0.86)
	)
	battle.record_stat("prime_ball_impacts")
	if damage_dealt > 0.0:
		battle.record_stat("prime_ball_damage_contacts")
