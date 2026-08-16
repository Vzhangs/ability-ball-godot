class_name BallAbility
extends RefCounted

var module: BallModule

func configure(owner_module: BallModule) -> void:
	module = owner_module

func setting(key: String):
	return module.setting(key)

func settingf(key: String) -> float:
	return module.settingf(key)

func settingi(key: String) -> int:
	return module.settingi(key)

func before_motion(_battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	pass

func on_battle_started(_battle, _fighter, _opponent, _side: int) -> void:
	pass

func automatic_activation_enabled() -> bool:
	return true

func after_entities_step(_battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	pass

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return 1.0

func on_step(_battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	pass

func activate(_battle, _fighter, _opponent, _side: int) -> void:
	pass

func cooldown_duration(_battle, fighter) -> float:
	return fighter.cooldown

func contact_damage(_battle, _fighter, _opponent) -> float:
	return 0.0

func after_contact(_battle, _fighter, _opponent, _damage_dealt: float) -> void:
	pass

func after_damage_dealt(_battle, _fighter, _opponent, _amount: float) -> void:
	pass
