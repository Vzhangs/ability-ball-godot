extends BallEntity

const Arc := preload("res://scripts/balls/qing/arc_entity.gd")
const Surface := preload("res://scripts/balls/core/ball_surface.gd")
var hp := 20.0
var max_hp := 20.0
var _config: Dictionary
var _age := 0.0
var _contact_timer := 0.0

func _init(side: int, position: Vector2, motion: Vector2, config: Dictionary) -> void:
	owner_side = side
	pos = position
	velocity = motion
	_config = config.duplicate()
	radius = float(config["drone_radius"])
	max_hp = float(config["drone_hp"])
	hp = max_hp
	tags = PackedStringArray(["qing_athena"])
	draw_layer = -3

func combat_category() -> Dictionary:
	return {"id": "qing_athena", "name": "雅典娜3号"}

func step(battle, delta: float) -> void:
	_age += delta
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if velocity.length_squared() > 0.001:
		velocity = velocity.normalized() * float(_config["drone_speed"])
	pos += velocity * delta
	var size: Vector2 = battle.arena_size()
	if pos.x < radius or pos.x > size.x - radius: velocity.x *= -1.0
	if pos.y < radius or pos.y > size.y - radius: velocity.y *= -1.0
	pos = pos.clamp(Vector2.ONE * radius, size - Vector2.ONE * radius)
	_resolve_contacts(battle)
	var nodes: Array[BallEntity] = battle.entities(-1, "qing_athena")
	var own_index := nodes.find(self)
	for index in range(own_index + 1, nodes.size()):
		var other := nodes[index]
		if other.owner_side != owner_side or other.owner_fighter_uid != owner_fighter_uid: continue
		var connected := false
		for link: BallEntity in battle.entities(owner_side, "qing_arc"):
			if link.owner_fighter_uid == owner_fighter_uid and link.call("connects", self, other):
				connected = true
				break
		if not connected:
			var arc := Arc.new(self, other, _config)
			battle.add_entity(arc)

func _resolve_contacts(battle) -> void:
	for other: BallEntity in battle.entities():
		if other == self or not other.participates_in_entity_collision(): continue
		var offset := other.pos - pos
		var gap := radius + other.radius
		if offset.length_squared() >= gap * gap: continue
		var n := offset.normalized() if offset.length_squared() > 0.0001 else Vector2.RIGHT
		var own_mass := entity_collision_inverse_mass()
		var other_mass := maxf(0.0, other.entity_collision_inverse_mass())
		var total := own_mass + other_mass
		var overlap := gap - offset.length()
		pos -= n * overlap * own_mass / total
		other.pos += n * overlap * other_mass / total
		var approach := (other.velocity - velocity).dot(n)
		if approach < 0.0:
			var impulse := -2.0 * approach / total
			velocity -= n * impulse * own_mass
			other.velocity += n * impulse * other_mass
		if not can_resolve_entity_contact(other) or not other.can_resolve_entity_contact(self): continue
		begin_entity_contact(other)
		other.begin_entity_contact(self)
		battle.damage_entity(self, other.entity_contact_damage(), other.entity_contact_color(), other.owner_side, true, other)

func can_receive_attack(side: int) -> bool:
	return not removed and not is_captured() and is_hostile_to(side)

func receive_attack(battle, amount: float, side: int, color: Color) -> float:
	if not can_receive_attack(side): return 0.0
	var applied := minf(hp, maxf(0.0, amount))
	hp -= applied
	if hp <= 0.0:
		removed = true
		battle.spawn_particles(pos, color, 8, 100.0)
		battle.emit_combat_event("impact", 0.35)
	return applied

func participates_in_entity_collision() -> bool:
	return not removed and not is_captured()

func participates_in_fighter_collision() -> bool:
	return participates_in_entity_collision()

func can_resolve_entity_contact(other: BallEntity) -> bool:
	return _contact_timer <= 0.0 and is_hostile_to(other.owner_side)

func begin_entity_contact(_other: BallEntity) -> void:
	_contact_timer = float(_config["contact_interval"])

func can_resolve_fighter_contact(side: int) -> bool:
	return _contact_timer <= 0.0 and is_hostile_to(side)

func begin_fighter_contact(_side: int) -> void:
	_contact_timer = float(_config["contact_interval"])

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return ownership_visual_color(Color("75e5ff"))

func team_marker_world_height() -> float:
	return radius * 1.3

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var p := context.point(pos)
	var appear := clampf(_age / float(_config["deploy_duration"]), 0.0, 1.0)
	var r := radius * context.scale_factor * (0.3 + 0.7 * appear)
	var accent := absorption_visual_color()
	Surface.draw(canvas, p, r, ownership_visual_color(Color("e9f3ed")), accent, Surface.Style.METAL, context.elapsed)
	for index in range(3):
		var d := Vector2.from_angle(index * TAU / 3.0 - PI / 2.0)
		canvas.draw_line(p + d * r * 0.3, p + d * r * 0.8, accent, maxf(1.0, r * 0.15), true)
	canvas.draw_circle(p, r * 0.25, Color("f8dc85"))
	var bar := Rect2(p + Vector2(-r, -r - 7.0 * context.scale_factor), Vector2(r * 2.0, 2.5 * context.scale_factor))
	canvas.draw_rect(bar, Color(0.02, 0.05, 0.08, 0.9))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / max_hp, bar.size.y)), accent)
