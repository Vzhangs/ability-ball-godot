extends BallAbility

const BeamEffect := preload("res://scripts/balls/prism/beam_effect_entity.gd")
const ChargeEffect := preload("res://scripts/balls/prism/charge_effect_entity.gd")
const EPSILON := 0.00001

var _target
var _charging := false
var _charge_elapsed := 0.0
var _aim := Vector2.RIGHT
var _flash_remaining := 0.0
var _shots_fired := 0
var _charge_effect: BallEntity
var _entry_announced := false

func on_battle_started(battle, fighter, opponent, _side: int) -> void:
	fighter.ability_timer = settingf("opening_delay")
	if opponent != null:
		_update_aim(fighter, opponent.pos)
	if not _entry_announced:
		battle.emit_combat_event("prism_spawn", 1.0)
		_entry_announced = true

func activate(battle, fighter, _opponent, side: int) -> void:
	if _charging or fighter.hp <= 0.0:
		return
	var candidates := _ordered_targets(battle, side, fighter.pos, settingf("attack_range"), [], true)
	if candidates.is_empty():
		return
	_target = candidates[0]
	_update_aim(fighter, _target.pos)
	_charging = true
	_charge_elapsed = 0.0
	_charge_effect = ChargeEffect.new(side, fighter, self)
	battle.add_entity(_charge_effect)
	battle.emit_combat_event("prism_charge", 0.8)
	battle.record_stat("prism_charges")

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	if not _charging:
		if opponent != null:
			_update_aim(fighter, opponent.pos)
		return
	if fighter.hp <= 0.0 or not _valid_target(_target, side) or not _in_range(fighter.pos, _target, settingf("attack_range")):
		_cancel_charge()
		return
	_update_aim(fighter, _target.pos)
	_charge_elapsed += delta
	if _charge_elapsed + EPSILON < settingf("charge_duration"):
		return
	var locked_target = _target
	_cancel_charge()
	_fire(battle, fighter, side, locked_target)

func cooldown_duration(_battle, fighter) -> float:
	return maxf(fighter.cooldown, settingf("charge_duration") + EPSILON)

func is_charging() -> bool:
	return _charging

func charge_progress() -> float:
	return clampf(_charge_elapsed / settingf("charge_duration"), 0.0, 1.0) if _charging else 0.0

func aim_direction() -> Vector2:
	return _aim

func flash_ratio() -> float:
	return _flash_remaining / settingf("beam_duration")

func shots_fired() -> int:
	return _shots_fired

func _cancel_charge() -> void:
	_charging = false
	_target = null
	if _charge_effect != null:
		_charge_effect.removed = true
		_charge_effect = null

func _fire(battle, fighter, side: int, locked_target) -> void:
	var primary = _first_contact(battle, side, fighter.pos, locked_target.pos, [])
	if primary == null:
		return
	var impact: Vector2 = primary.pos
	var excluded: Array = [primary]
	var candidates := _ordered_targets(battle, side, impact, settingf("refraction_range"), excluded, false)
	var branches := PackedVector2Array()
	_hit(battle, fighter, side, primary, settingf("main_damage"))
	for candidate in candidates:
		if branches.size() >= settingi("refraction_count"):
			break
		if excluded.has(candidate) or not _valid_target(candidate, side):
			continue
		var hit = _first_contact(battle, side, impact, candidate.pos, excluded)
		if hit == null:
			continue
		excluded.append(hit)
		branches.append(hit.pos)
		_hit(battle, fighter, side, hit, settingf("refraction_damage"))
		battle.record_stat("prism_refraction_hits")
	_update_aim(fighter, impact)
	var muzzle: Vector2 = fighter.pos + _aim * minf(fighter.radius * 1.28, fighter.pos.distance_to(impact) * 0.65)
	var effect: BallEntity = BeamEffect.new(side, muzzle, impact, branches, settingf("beam_duration"), settingf("beam_half_width") * 2.0)
	effect.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(effect)
	battle.spawn_particles(impact, fighter.accent, 9, 140.0)
	battle.emit_combat_event("prism_fire", 1.0)
	battle.emit_combat_event("prism_hit", 0.5)
	battle.record_stat("prism_shots")
	_shots_fired += 1
	_flash_remaining = settingf("beam_duration")

func _hit(battle, fighter, side: int, target, amount: float) -> void:
	if target is BallEntity:
		battle.damage_entity(target, amount, fighter.accent, side, true, fighter)
	else:
		battle.damage(target, amount, fighter.accent, fighter)

func _valid_target(target, side: int) -> bool:
	if target == null:
		return false
	if target is BallEntity:
		return not target.removed and not target.is_captured() and target.can_receive_attack(side)
	return target.hp > 0.0 and target.team_id != side

func _in_range(origin: Vector2, target, reach: float) -> bool:
	return origin.distance_squared_to(target.pos) <= pow(reach + float(target.radius), 2.0)

func _all_targets(battle, side: int) -> Array:
	var result: Array = []
	result.append_array(battle.hostile_fighters(side))
	result.append_array(battle.damageable_entities(side))
	return result

func _ordered_targets(battle, side: int, origin: Vector2, reach: float, excluded: Array, main_priority: bool) -> Array:
	var candidates: Array[Dictionary] = []
	var order := 0
	for target in _all_targets(battle, side):
		if not excluded.has(target) and _valid_target(target, side) and _in_range(origin, target, reach):
			candidates.append({"target": target, "distance": origin.distance_squared_to(target.pos), "order": order, "main": not target is BallEntity})
		order += 1
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if main_priority and bool(a.main) != bool(b.main):
			return bool(a.main)
		if not is_equal_approx(float(a.distance), float(b.distance)):
			return float(a.distance) < float(b.distance)
		return int(a.order) < int(b.order)
	)
	var result: Array = []
	for candidate in candidates:
		result.append(candidate.target)
	return result

func _first_contact(battle, side: int, start: Vector2, finish: Vector2, excluded: Array):
	var nearest = null
	var nearest_fraction := INF
	for target in _all_targets(battle, side):
		if excluded.has(target) or not _valid_target(target, side):
			continue
		var fraction := _hit_fraction(start, finish, target.pos, float(target.radius) + settingf("beam_half_width"))
		if fraction >= 0.0 and fraction < nearest_fraction:
			nearest = target
			nearest_fraction = fraction
	return nearest

func _hit_fraction(start: Vector2, finish: Vector2, center: Vector2, hit_radius: float) -> float:
	var offset := start - center
	if offset.length_squared() <= hit_radius * hit_radius:
		return 0.0
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= EPSILON:
		return -1.0
	var projection := offset.dot(segment)
	var discriminant := projection * projection - length_squared * (offset.length_squared() - hit_radius * hit_radius)
	if discriminant < 0.0:
		return -1.0
	var fraction := (-projection - sqrt(discriminant)) / length_squared
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0

func _update_aim(fighter, position: Vector2) -> void:
	var direction: Vector2 = position - fighter.pos
	if direction.length_squared() > EPSILON:
		_aim = direction.normalized()
