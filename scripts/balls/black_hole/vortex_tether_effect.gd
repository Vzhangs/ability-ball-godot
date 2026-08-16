extends BallStatusEffect

var _color := Color("bc63ff")
var _wall_damage_cooldown := 0.0

func _init(duration: float, effect_source_side: int, color: Color) -> void:
	key = "vortex_tether:%d" % effect_source_side
	remaining = duration
	source_side = effect_source_side
	_color = color

func tick(battle, target, delta: float) -> void:
	super(battle, target, delta)
	_wall_damage_cooldown = maxf(0.0, _wall_damage_cooldown - delta)

func preserves_external_velocity() -> bool:
	return true

func on_wall_hit(battle, target) -> void:
	if _wall_damage_cooldown > 0.0:
		return
	var source = battle.fighter_for_side(source_side)
	if source == null or source.hp <= 0.0:
		return
	_wall_damage_cooldown = 0.24
	var applied: float = battle.damage(target, 15.0, _color, source, true)
	if applied <= 0.0:
		return
	battle.record_stat("gravity_wall_hits")
	battle.spawn_ring(target.pos, _color, 10.0, 92.0, 0.32)
	battle.spawn_particles(target.pos, _color, 12, 175.0)
	battle.shake_camera(7.0)
