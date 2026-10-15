extends BallProjectileEntity

var _launch_speed := 0.0
var _base_damage := 0.0
var _damage_scale := 0.0

func _init(side: int, position: Vector2, direction: Vector2, launch_speed: float, config: Dictionary) -> void:
	super(side, position, direction * float(config["blade_speed"]), float(config["blade_radius"]), float(config["blade_damage_cap"]), Color("b6ffe4"), float(config["blade_duration"]), "wind_blade")
	_launch_speed = launch_speed
	_base_damage = float(config["blade_base_damage"])
	_damage_scale = float(config["speed_difference_damage"])
	tags.append("gale_blade")
	draw_layer = 3

func damage_for_speed(target_speed: float) -> float:
	return minf(damage_amount, _base_damage + absf(_launch_speed - target_speed) * _damage_scale)

func step(battle, delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	var start := pos
	var finish := start + velocity * delta
	var selected = null
	var fraction := INF
	var candidates: Array = []
	candidates.append_array(battle.hostile_fighters(owner_side))
	candidates.append_array(battle.damageable_entities(owner_side))
	for target in candidates:
		var hit := _segment_circle_hit_fraction(start, finish, target.pos, target.radius + radius)
		if hit >= 0.0 and hit < fraction:
			fraction = hit
			selected = target
	var end := start.lerp(finish, fraction) if selected != null else finish
	pos = end
	if selected != null:
		var damage := damage_for_speed(selected.velocity.length())
		if selected is BallEntity:
			battle.damage_entity(selected, damage, color, owner_side, true, self)
		else:
			battle.damage(selected, damage, color, battle.owner_for_entity(self), true, self)
		battle.spawn_particles(pos, color, 7, 105.0)
		battle.emit_combat_event("projectile_hit", 0.45)
		battle.record_stat("gale_blade_hits")
		removed = true
	var size: Vector2 = battle.arena_size()
	if remaining <= 0.0 or pos.x < -radius or pos.y < -radius or pos.x > size.x + radius or pos.y > size.y + radius:
		removed = true

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var p := context.point(pos)
	var r := radius * context.scale_factor * 2.0
	var a := velocity.angle()
	var n := velocity.normalized()
	canvas.draw_line(p - n * r * 2.2, p, Color(color, 0.15), r * 0.7, true)
	canvas.draw_arc(p, r, a - PI * 0.58, a + PI * 0.58, 20, Color(color, 0.2), r * 0.5, true)
	canvas.draw_arc(p, r, a - PI * 0.58, a + PI * 0.58, 20, color, maxf(1.0, r * 0.12), true)
	canvas.draw_arc(p - n * r * 0.24, r * 0.84, a - PI * 0.43, a + PI * 0.43, 16, Color.WHITE, maxf(0.8, r * 0.065), true)
