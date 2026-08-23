class_name BallBattleContext
extends RefCounted

var _battle_ref: WeakRef

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

func random_int(minimum: int, maximum: int) -> int:
	return _battle().rng.randi_range(minimum, maximum)

func arena_size() -> Vector2:
	return _battle().arena_size()

func fighter_for_side(side: int):
	return _battle().fighter_for_side(side)

func fighter_for_uid(fighter_uid: int):
	return _battle().fighter_for_uid(fighter_uid)

func active_fighters() -> Array:
	return _battle().active_fighters()

func hostile_fighters(side: int) -> Array:
	return _battle().hostile_fighters(side)

func opponent_for_side(side: int):
	return _battle().opponent_for_side(side)

func side_for_fighter(fighter) -> int:
	return _battle().side_for_fighter(fighter)

func damage(target, amount: float, color: Color, source, show_text: bool = true) -> float:
	return _battle().damage(target, amount, color, source, show_text)

func damage_entity(
	target: BallEntity,
	amount: float,
	color: Color,
	source_side: int,
	show_text: bool = true
) -> float:
	return _battle().damage_entity(target, amount, color, source_side, show_text)

func damageable_entities(source_side: int) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for entity: BallEntity in _battle().entity_list():
		if entity.can_receive_attack(source_side):
			result.append(entity)
	return result

func damageable_entities_in_circle(
	source_side: int,
	center: Vector2,
	attack_radius: float
) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for entity: BallEntity in damageable_entities(source_side):
		if entity.pos.distance_squared_to(center) <= pow(attack_radius + entity.radius, 2.0):
			result.append(entity)
	return result

func damageable_entities_on_segment(
	source_side: int,
	start: Vector2,
	finish: Vector2,
	half_width: float = 0.0
) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for entity: BallEntity in damageable_entities(source_side):
		if _distance_to_segment(entity.pos, start, finish) <= entity.radius + half_width:
			result.append(entity)
	return result

func contact_damage_for_side(source_side: int, target) -> float:
	return _battle().contact_damage_for_side(source_side, target)

func movement_control_priority(fighter) -> int:
	return _battle().movement_control_priority(fighter)

func heal(fighter, amount: float, allow_overheal: bool = false) -> float:
	return _battle().heal(fighter, amount, allow_overheal)

func spawn_ring(position: Vector2, color: Color, start_radius: float, end_radius: float, duration: float) -> void:
	_battle().spawn_ring(position, color, start_radius, end_radius, duration)

func spawn_particles(position: Vector2, color: Color, count: int, speed: float) -> void:
	_battle().spawn_particles(position, color, count, speed)

func spawn_text(text: String, position: Vector2, color: Color, duration: float) -> void:
	_battle().spawn_text(text, position, color, duration)

func add_beam(from: Vector2, to: Vector2, color: Color, duration: float, width: float) -> void:
	_battle().add_beam(from, to, color, duration, width)

func add_projectile(owner_side: int, position: Vector2, velocity: Vector2, radius: float, projectile_damage: float, color: Color, duration: float, type: String) -> void:
	_battle().add_projectile(owner_side, position, velocity, radius, projectile_damage, color, duration, type)


func record_stat(key: String, amount: int = 1) -> void:
	_battle().record_stat(key, amount)

func add_entity(entity: BallEntity) -> BallEntity:
	return _battle().add_entity(entity)

func entities(owner_side: int = -1, tag: String = "") -> Array[BallEntity]:
	return _battle().entity_list(owner_side, tag)

func count_entities(owner_side: int, tag: String) -> int:
	return _battle().count_entities(owner_side, tag)

func apply_status(target, effect: BallStatusEffect) -> BallStatusEffect:
	return _battle().apply_status(target, effect)

func has_status(target, key_prefix: String) -> bool:
	return _battle().has_status(target, key_prefix)

func remove_status(target, exact_key: String) -> bool:
	return _battle().remove_status(target, exact_key)

func ray_to_arena_edge(origin: Vector2, direction: Vector2) -> Vector2:
	return _battle().ray_to_arena_edge(origin, direction)

func shake_camera(strength: float) -> void:
	var battle = _battle()
	battle.camera_shake = maxf(battle.camera_shake, strength)

func emit_combat_event(kind: String, strength: float) -> void:
	_battle().emit_combat_event(kind, strength)

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var offset := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * offset)
