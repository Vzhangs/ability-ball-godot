extends BallEntity

const EPSILON := 0.0001

var hp := 10.0
var max_hp := 10.0

var _owner
var _config: Dictionary = {}
var _body_color := Color("a92120")
var _accent_color := Color("f6d89a")
var _slot := 0
var _slot_count := 1
var _phase := 0.0
var _formation_managed := false
var _fighter_contact_timer := 0.0
var _entity_contact_timers: Dictionary = {}
var _hit_flash := 0.0

func _init(
	spawn_owner_side: int,
	owner,
	body_color: Color,
	accent_color: Color,
	config: Dictionary
) -> void:
	owner_side = spawn_owner_side
	_owner = owner
	_config = config.duplicate(true)
	_body_color = body_color
	_accent_color = accent_color
	radius = float(_config["radius"])
	max_hp = float(_config["max_hp"])
	hp = max_hp
	pos = owner.pos if owner != null else Vector2.ZERO
	tags = PackedStringArray(["chess_guard"])
	draw_layer = 6

func set_orbit_slot(slot: int, slot_count: int, formation_angle: float) -> void:
	_slot = maxi(0, slot)
	_slot_count = maxi(1, slot_count)
	_phase = formation_angle + TAU * float(_slot) / float(_slot_count)
	_formation_managed = true

func snap_to_orbit() -> void:
	pos = _orbit_position()

func step(battle, delta: float) -> void:
	if _owner == null or _owner.hp <= 0.0:
		removed = true
		return
	if not _formation_managed:
		var direction_sign := 1.0 if owner_side == 0 else -1.0
		_phase = fmod(
			_phase + delta * float(_config["orbit_speed"]) * direction_sign,
			TAU
		)
	_hit_flash = maxf(0.0, _hit_flash - delta * 5.2)
	_fighter_contact_timer = maxf(0.0, _fighter_contact_timer - delta)
	_tick_entity_contact_timers(delta)
	var previous_position := pos
	pos = _orbit_position()
	velocity = (pos - previous_position) / maxf(delta, EPSILON)
	for entity: BallEntity in battle.entities():
		resolve_entity_collision(battle, entity)
	# Contacts can push only the hostile body. The guard's orbit is an exact ball-local path.
	pos = _orbit_position()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var draw_radius := radius * context.scale_factor
	var body := ownership_visual_color(_body_color)
	var accent := ownership_visual_color(_accent_color)
	var alpha := 0.6 if is_captured() else 1.0
	canvas.draw_circle(center, draw_radius * 1.36, Color(accent.r, accent.g, accent.b, 0.18 * alpha))
	canvas.draw_circle(center, draw_radius, Color(body.r, body.g, body.b, alpha))
	canvas.draw_circle(center, draw_radius * 0.76, Color(accent.r, accent.g, accent.b, 0.98 * alpha))
	canvas.draw_arc(center, draw_radius * 0.76, 0.0, TAU, 22, Color(0.52, 0.035, 0.035, alpha), maxf(1.0, draw_radius * 0.12), true)
	var font_size := clampi(int(draw_radius * 1.15), 10, 24)
	var width := draw_radius * 1.5
	canvas.draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-width * 0.5, font_size * 0.34),
		"士",
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		font_size,
		Color(0.55, 0.035, 0.035, alpha)
	)
	if _hit_flash > 0.0:
		canvas.draw_circle(center, draw_radius, Color(1.0, 1.0, 1.0, _hit_flash * 0.7))
	if not is_captured():
		_draw_health_bar(canvas, center, draw_radius, accent)

func participates_in_fighter_collision() -> bool:
	return not removed and not is_captured()

func fighter_collision_inverse_mass() -> float:
	# Use ordinary body mass for the opponent's response, then restore this exact orbit afterward.
	return 1.0

func can_resolve_fighter_contact(fighter_side: int) -> bool:
	return (
		participates_in_fighter_collision()
		and fighter_side >= 0
		and fighter_side != owner_side
		and _fighter_contact_timer <= 0.0
	)

func begin_fighter_contact(_fighter_side: int) -> void:
	_fighter_contact_timer = float(_config["contact_interval"])

func participates_in_entity_collision() -> bool:
	return not removed and not is_captured()

func entity_collision_inverse_mass() -> float:
	return 1.0

func entity_contact_damage() -> float:
	return float(_config["contact_damage"])

func entity_contact_color() -> Color:
	return ownership_visual_color(_accent_color)

func can_resolve_entity_contact(other: BallEntity) -> bool:
	return (
		participates_in_entity_collision()
		and other != null
		and other.owner_side >= 0
		and other.owner_side != owner_side
		and float(_entity_contact_timers.get(other.get_instance_id(), 0.0)) <= 0.0
	)

func begin_entity_contact(other: BallEntity) -> void:
	if other != null:
		_entity_contact_timers[other.get_instance_id()] = float(_config["contact_interval"])

func resolve_entity_collision(battle, other: BallEntity) -> void:
	if (
		other == null
		or other == self
		or other.owner_side == owner_side
		or not participates_in_entity_collision()
		or not other.participates_in_entity_collision()
	):
		return
	var offset: Vector2 = other.pos - pos
	var minimum_distance := radius + other.radius
	var distance := offset.length()
	if distance >= minimum_distance:
		return
	var normal := offset / distance if distance > EPSILON else Vector2.RIGHT
	var overlap := minimum_distance - maxf(distance, EPSILON)
	var own_inverse_mass := entity_collision_inverse_mass()
	var other_inverse_mass := maxf(0.0, other.entity_collision_inverse_mass())
	var total_inverse_mass := own_inverse_mass + other_inverse_mass
	if total_inverse_mass > 0.0:
		pos -= normal * overlap * own_inverse_mass / total_inverse_mass
		other.pos += normal * overlap * other_inverse_mass / total_inverse_mass
		var relative_speed: float = (other.velocity - velocity).dot(normal)
		if relative_speed < 0.0:
			var impulse := -2.0 * relative_speed / total_inverse_mass
			velocity -= normal * impulse * own_inverse_mass
			other.velocity += normal * impulse * other_inverse_mass
	if not can_resolve_entity_contact(other) or not other.can_resolve_entity_contact(self):
		return
	begin_entity_contact(other)
	other.begin_entity_contact(self)
	var applied_to_other: float = battle.damage_entity(
		other,
		entity_contact_damage(),
		entity_contact_color(),
		owner_side
	)
	var applied_to_self: float = battle.damage_entity(
		self,
		other.entity_contact_damage(),
		other.entity_contact_color(),
		other.owner_side
	)
	if applied_to_other > 0.0 or applied_to_self > 0.0:
		_emit_contact_effect(battle, pos + normal * radius)
	pos = _orbit_position()

func can_receive_attack(source_side: int) -> bool:
	return not removed and not is_captured() and is_hostile_to(source_side)

func receive_attack(
	battle,
	amount: float,
	source_side: int,
	hit_color: Color
) -> float:
	if not can_receive_attack(source_side) or amount <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp = maxf(0.0, hp - applied)
	_hit_flash = 1.0
	battle.record_stat("chess_guard_damage_taken", int(ceil(applied)))
	if hp > 0.0:
		battle.spawn_particles(pos, hit_color, 3, 68.0)
		return applied
	removed = true
	battle.record_stat("chess_guards_destroyed")
	battle.spawn_ring(pos, absorption_visual_color(), radius, radius * 3.8, 0.28)
	battle.spawn_particles(pos, absorption_visual_color(), 10, 124.0)
	battle.emit_combat_event("impact", 0.46)
	return applied

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return ownership_visual_color(_body_color)

func on_ownership_transferred(
	_previous_owner_side: int,
	_new_owner_side: int,
	new_owner_anchor
) -> void:
	_owner = new_owner_anchor
	_formation_managed = false
	if _owner != null:
		_phase = (pos - _owner.pos).angle()
	_fighter_contact_timer = 0.0
	_entity_contact_timers.clear()

func orbit_owner():
	return _owner

func orbit_slot() -> int:
	return _slot

func orbit_slot_count() -> int:
	return _slot_count

func orbit_phase() -> float:
	return _phase

func formation_managed() -> bool:
	return _formation_managed

func _orbit_position() -> Vector2:
	if _owner == null:
		return pos
	return _owner.pos + Vector2.from_angle(_phase) * float(_config["orbit_radius"])

func _tick_entity_contact_timers(delta: float) -> void:
	for key in _entity_contact_timers.keys():
		var timer := maxf(0.0, float(_entity_contact_timers[key]) - delta)
		if timer <= 0.0:
			_entity_contact_timers.erase(key)
		else:
			_entity_contact_timers[key] = timer

func _emit_contact_effect(battle, contact_position: Vector2) -> void:
	battle.record_stat("chess_guard_contact_hits")
	battle.spawn_ring(contact_position, entity_contact_color(), 3.0, 28.0, 0.18)
	battle.spawn_particles(contact_position, entity_contact_color(), 4, 88.0)
	battle.emit_combat_event("clone_impact", 0.38)

func _draw_health_bar(canvas: CanvasItem, center: Vector2, draw_radius: float, color: Color) -> void:
	var width := maxf(12.0, draw_radius * 1.8)
	var height := maxf(2.0, draw_radius * 0.18)
	var bounds := Rect2(center + Vector2(-width * 0.5, draw_radius + 3.0), Vector2(width, height))
	canvas.draw_rect(bounds.grow(1.0), Color(0.02, 0.015, 0.01, 0.84))
	canvas.draw_rect(Rect2(bounds.position, Vector2(bounds.size.x * hp / maxf(1.0, max_hp), bounds.size.y)), color)
