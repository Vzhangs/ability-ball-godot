extends BallStatusEffect

var _color := Color("bc63ff")
var _wall_damage_cooldown := 0.0
var _wall_damage := 0.0
var _wall_damage_interval := 0.1

func _init(
	duration: float,
	effect_source_side: int,
	color: Color,
	wall_damage: float,
	wall_damage_interval: float
) -> void:
	key = "vortex_tether:%d" % effect_source_side
	remaining = duration
	source_side = effect_source_side
	_color = color
	_wall_damage = wall_damage
	_wall_damage_interval = wall_damage_interval

func tick(battle, target, delta: float) -> void:
	super(battle, target, delta)
	_wall_damage_cooldown = maxf(0.0, _wall_damage_cooldown - delta)

func preserves_external_velocity() -> bool:
	return true

func on_wall_hit(battle, target) -> void:
	if _wall_damage_cooldown > 0.0:
		return
	var source = battle.fighter_for_uid(source_fighter_uid)
	if source == null:
		source = battle.fighter_for_side(source_side)
	if source == null or source.hp <= 0.0:
		return
	_wall_damage_cooldown = _wall_damage_interval
	var applied: float = battle.damage(target, _wall_damage, _color, source, true)
	if applied <= 0.0:
		return
	battle.record_stat("gravity_wall_hits")
	battle.spawn_ring(target.pos, _color, 10.0, 92.0, 0.32)
	battle.spawn_particles(target.pos, _color, 12, 175.0)
	battle.shake_camera(7.0)
