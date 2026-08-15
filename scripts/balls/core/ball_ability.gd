class_name BallAbility
extends RefCounted

var module: BallModule

func configure(owner_module: BallModule) -> void:
	module = owner_module

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return 1.0

func on_step(_battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	pass

func activate(_battle, _fighter, _opponent, _side: int) -> void:
	pass

func cooldown_duration(battle, fighter) -> float:
	return maxf(1.0, fighter.cooldown - float(battle.phase - 1) * 0.24)

func contact_damage(_battle, fighter, _opponent, base_damage: float) -> float:
	return base_damage

func after_contact(_battle, _fighter, _opponent, _damage_dealt: float) -> void:
	pass

func after_damage_dealt(_battle, _fighter, _opponent, _amount: float) -> void:
	pass
