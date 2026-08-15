class_name BallBattleContext
extends RefCounted

var _battle_ref: WeakRef

var phase: int:
	get:
		return int(_battle().phase)

var elapsed: float:
	get:
		return float(_battle().elapsed)

func _init(battle) -> void:
	_battle_ref = weakref(battle)

func _battle():
	var battle = _battle_ref.get_ref()
	assert(battle != null, "Battle context used after its simulation was released")
	return battle

func random_float() -> float:
	return _battle().rng.randf()

func random_range(minimum: float, maximum: float) -> float:
	return _battle().rng.randf_range(minimum, maximum)

func damage(target, amount: float, color: Color, source, show_text: bool = true) -> float:
	return _battle().damage(target, amount, color, source, show_text)

func heal(fighter, amount: float) -> float:
	return _battle().heal(fighter, amount)

func spawn_ring(position: Vector2, color: Color, start_radius: float, end_radius: float, duration: float) -> void:
	_battle().spawn_ring(position, color, start_radius, end_radius, duration)

func spawn_particles(position: Vector2, color: Color, count: int, speed: float) -> void:
	_battle().spawn_particles(position, color, count, speed)

func spawn_text(text: String, position: Vector2, color: Color, duration: float) -> void:
	_battle().spawn_text(text, position, color, duration)

func add_anchor(owner_side: int, position: Vector2, duration: float) -> void:
	_battle().add_anchor(owner_side, position, duration)

func add_beam(from: Vector2, to: Vector2, color: Color, duration: float, width: float) -> void:
	_battle().add_beam(from, to, color, duration, width)

func add_gravity_well(position: Vector2, duration: float, radius: float, color: Color) -> void:
	_battle().add_gravity_well(position, duration, radius, color)

func add_projectile(owner_side: int, position: Vector2, velocity: Vector2, radius: float, projectile_damage: float, color: Color, duration: float, type: String) -> void:
	_battle().add_projectile(owner_side, position, velocity, radius, projectile_damage, color, duration, type)

func add_fire_zone(owner_side: int, position: Vector2, duration: float, radius: float) -> void:
	_battle().add_fire_zone(owner_side, position, duration, radius)

func fire_zone_hits(owner_side: int, opponent) -> bool:
	for zone in _battle().fire_zones:
		if int(zone["owner"]) == owner_side and Vector2(zone["pos"]).distance_to(opponent.pos) < float(zone["radius"]) + opponent.radius:
			return true
	return false

func record_stat(key: String, amount: int = 1) -> void:
	_battle().record_stat(key, amount)

func record_clone_spawn(amount: int) -> void:
	_battle().record_clone_spawn(amount)

func ray_to_arena_edge(origin: Vector2, direction: Vector2) -> Vector2:
	return _battle().ray_to_arena_edge(origin, direction)

func shake_camera(strength: float) -> void:
	var battle = _battle()
	battle.camera_shake = maxf(battle.camera_shake, strength)
