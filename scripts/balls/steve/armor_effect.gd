extends BallStatusEffect

var reduction := 0.0

func _init(owner_side: int) -> void:
	key = "steve_armor"
	source_side = owner_side
	remaining = -1.0

func is_expired() -> bool:
	return false

func tick(_battle, _target, _delta: float) -> void:
	pass

func modify_incoming_damage(_battle, _target, amount: float, _source) -> float:
	return amount * (1.0 - clampf(reduction, 0.0, 0.95))
