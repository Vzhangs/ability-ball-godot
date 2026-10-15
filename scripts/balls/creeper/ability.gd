extends BallAbility

const BlastEffect := preload("res://scripts/balls/creeper/blast_entity.gd")
const KnockbackEffect := preload("res://scripts/balls/creeper/knockback_effect.gd")

var _armed := false
var _fuse_remaining := 0.0
var _recovery_remaining := 0.0

func automatic_activation_enabled() -> bool:
	return false

func before_motion(battle, fighter, _opponent, side: int, delta: float) -> void:
	_recovery_remaining = maxf(0.0, _recovery_remaining - delta)
	if not _armed or fighter.hp <= 0.0:
		return
	_fuse_remaining = maxf(0.0, _fuse_remaining - delta)
	if _fuse_remaining <= 0.000001:
		_explode(battle, fighter, side)

func after_contact(battle, fighter, _opponent, _damage_dealt: float) -> void:
	_ignite(battle, fighter)

func after_entity_contact(battle, fighter, _entity: BallEntity, _damage_dealt: float) -> void:
	_ignite(battle, fighter)

func is_armed() -> bool:
	return _armed

func fuse_progress() -> float:
	return 1.0 - _fuse_remaining / settingf("fuse_duration") if _armed else 0.0

func _ignite(battle, fighter) -> void:
	if _armed or _recovery_remaining > 0.0 or fighter.hp <= 0.0:
		return
	_armed = true
	_fuse_remaining = settingf("fuse_duration")
	battle.emit_combat_event("creeper_fuse", 1.0)
	battle.record_stat("creeper_ignitions")

func _explode(battle, fighter, side: int) -> void:
	_armed = false
	_recovery_remaining = fighter.cooldown
	var center: Vector2 = fighter.pos
	var blast_radius := settingf("blast_radius")
	for target in battle.hostile_fighters(side):
		if center.distance_to(target.pos) > blast_radius + target.radius:
			continue
		battle.damage(target, settingf("blast_damage"), fighter.accent, fighter)
		if target.hp > 0.0:
			_knockback(battle, target, center, side)
	for entity: BallEntity in battle.damageable_entities_in_circle(side, center, blast_radius):
		battle.damage_entity(entity, settingf("blast_damage"), fighter.accent, side)
		if not entity.removed:
			_knockback(battle, entity, center, side)

	battle.add_entity(BlastEffect.new(side, center, blast_radius, settingf("blast_effect_duration")))
	battle.emit_combat_event("creeper_explosion", 1.0)
	battle.shake_camera(6.0)
	battle.record_stat("creeper_explosions")

func _knockback(battle, target, center: Vector2, side: int) -> void:
	if settingf("knockback_speed") <= 0.0 or settingf("knockback_duration") <= 0.0:
		return
	var direction: Vector2 = target.pos - center
	if direction.length_squared() <= 0.000001:
		direction = Vector2.RIGHT
	battle.apply_status(target, KnockbackEffect.new(
		side, direction.normalized(), settingf("knockback_speed"), settingf("knockback_duration")
	))
