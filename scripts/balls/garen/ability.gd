extends BallAbility

const MAX_ANGLE_PER_HIT_SAMPLE := PI / 36.0
const SPIN_SOUND_EVENT := "garen_spin_whoosh"

var _sword_angle := 0.0
var _spin_remaining := 0.0
var _spin_duration := 0.0
var _spin_direction_sign := 1.0
var _sword_touching_opponent := false
var _sword_touching_entity_ids: Dictionary = {}

func on_battle_started(_battle, fighter, opponent, side: int) -> void:
	_sword_angle = _aim_angle(fighter, opponent)
	_spin_duration = settingf("spin_duration")
	_spin_remaining = 0.0
	_spin_direction_sign = 1.0 if side == 0 else -1.0
	_sword_touching_opponent = false
	_sword_touching_entity_ids.clear()
	fighter.ability_timer = fighter.cooldown

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	var new_hits := 0
	if _spin_remaining <= 0.0:
		_sword_angle = _aim_angle(fighter, opponent)
		new_hits = _resolve_sword_contacts(battle, fighter, opponent, side, false)
		_emit_hit_sound(battle, new_hits, false)
		return

	var active_delta := minf(maxf(0.0, delta), _spin_remaining)
	var angular_delta := TAU * settingf("spin_turns_per_second") * _spin_direction_sign * active_delta
	var sample_count := maxi(1, int(ceil(absf(angular_delta) / MAX_ANGLE_PER_HIT_SAMPLE)))
	var angle_step := angular_delta / float(sample_count)
	for _sample in range(sample_count):
		_sword_angle = fposmod(_sword_angle + angle_step, TAU)
		new_hits += _resolve_sword_contacts(battle, fighter, opponent, side, true)
	_spin_remaining = maxf(0.0, _spin_remaining - active_delta)

	if _spin_remaining <= 0.0:
		_sword_angle = _aim_angle(fighter, opponent)
		new_hits += _resolve_sword_contacts(battle, fighter, opponent, side, false)
		battle.emit_combat_event(SPIN_SOUND_EVENT, 0.0)
	_emit_hit_sound(battle, new_hits, true)

func activate(battle, fighter, _opponent, _side: int) -> void:
	_spin_duration = settingf("spin_duration")
	_spin_remaining = _spin_duration
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.8, fighter.radius * 2.4, 0.38)
	battle.spawn_particles(fighter.pos, fighter.accent, 10, 145.0)
	battle.record_stat("garen_spins")

func sword_angle() -> float:
	return _sword_angle

func sword_direction() -> Vector2:
	return Vector2.from_angle(_sword_angle)

func spin_active() -> bool:
	return _spin_remaining > 0.0

func spin_progress() -> float:
	if _spin_duration <= 0.0 or not spin_active():
		return 0.0
	return clampf(1.0 - _spin_remaining / _spin_duration, 0.0, 1.0)

func spin_direction_sign() -> float:
	return _spin_direction_sign

func sword_contacting_opponent() -> bool:
	return _sword_touching_opponent

func sword_contacting_entity_count() -> int:
	return _sword_touching_entity_ids.size()

func _resolve_sword_contacts(
	battle,
	fighter,
	opponent,
	side: int,
	spinning: bool
) -> int:
	var direction := sword_direction()
	var start: Vector2 = fighter.pos + direction * fighter.radius
	var finish: Vector2 = start + direction * settingf("sword_length")
	var half_width := settingf("sword_width") * 0.5
	var damage := settingf("spin_sword_damage") if spinning else settingf("sword_damage")
	var new_hits := 0
	var opponent_touching := _circle_intersects_segment(
		opponent.pos,
		opponent.radius,
		start,
		finish,
		half_width
	)
	if not opponent_touching:
		_sword_touching_opponent = false
	elif not _sword_touching_opponent:
		_sword_touching_opponent = true
		var opponent_applied: float = battle.damage(opponent, damage, fighter.accent, fighter)
		if opponent_applied > 0.0:
			new_hits += 1
			_spawn_hit_feedback(battle, opponent.pos, start, finish, fighter.accent)
			battle.record_stat("garen_spin_sword_hits" if spinning else "garen_sword_hits")

	var touching_entity_ids: Dictionary = {}
	for entity: BallEntity in battle.damageable_entities_on_segment(
		side,
		start,
		finish,
		half_width
	):
		var entity_id := entity.get_instance_id()
		touching_entity_ids[entity_id] = true
		if _sword_touching_entity_ids.has(entity_id):
			continue
		var entity_applied: float = battle.damage_entity(
			entity,
			damage,
			fighter.accent,
			side
		)
		if entity_applied <= 0.0:
			continue
		new_hits += 1
		_spawn_hit_feedback(battle, entity.pos, start, finish, fighter.accent)
		battle.record_stat(
			"garen_spin_sword_entity_hits" if spinning else "garen_sword_entity_hits"
		)
	_sword_touching_entity_ids = touching_entity_ids
	return new_hits

func _spawn_hit_feedback(
	battle,
	target_position: Vector2,
	start: Vector2,
	finish: Vector2,
	color: Color
) -> void:
	var hit_position := _closest_point_on_segment(target_position, start, finish)
	battle.spawn_ring(hit_position, color, 4.0, 32.0, 0.2)
	battle.spawn_particles(hit_position, color, 6, 105.0)

func _emit_hit_sound(battle, new_hits: int, spinning: bool) -> void:
	if new_hits <= 0:
		return
	var strength := clampf(0.46 + float(new_hits - 1) * 0.06, 0.46, 0.78)
	if spinning:
		strength = minf(0.84, strength + 0.08)
	battle.emit_combat_event("garen_sword_hit", strength)

func _aim_angle(fighter, opponent) -> float:
	var offset: Vector2 = opponent.pos - fighter.pos
	if offset.length_squared() > 0.0001:
		return offset.angle()
	if fighter.velocity.length_squared() > 0.0001:
		return fighter.velocity.angle()
	return _sword_angle

func _circle_intersects_segment(
	center: Vector2,
	radius: float,
	start: Vector2,
	finish: Vector2,
	half_width: float
) -> bool:
	return center.distance_to(_closest_point_on_segment(center, start, finish)) <= radius + half_width

func _closest_point_on_segment(point: Vector2, start: Vector2, finish: Vector2) -> Vector2:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start
	var offset := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return start + segment * offset
