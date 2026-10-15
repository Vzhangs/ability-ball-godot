extends BallEntity

func combat_category() -> Dictionary:
	return {"id": "replicator_cannon", "name": "浮游炮"}

var _owner
var _ability
var _formation_slot := 0
var _formation_count := 1
var _transferred_orbit_phase := 0.0
var _transferred_orbit_radius := -1.0

func _init(spawn_owner_side: int, owner, owner_ability) -> void:
	owner_side = spawn_owner_side
	_owner = owner
	_ability = owner_ability
	pos = owner.pos
	radius = owner.radius * _ability.cannon_radius_scale()
	tags = PackedStringArray(["clone"])
	draw_layer = -5

func step(_battle, _delta: float) -> void:
	_update_position()

func set_formation_slot(slot: int, total_count: int) -> void:
	_formation_slot = clampi(slot, 0, _ability.max_cannons() - 1)
	_formation_count = clampi(total_count, 1, _ability.max_cannons())
	_update_position()

func on_ownership_transferred(
	_previous_owner_side: int,
	_new_owner_side: int,
	new_owner_anchor
) -> void:
	if new_owner_anchor == null:
		return
	var direction_from_new_owner: Vector2 = pos - new_owner_anchor.pos
	_transferred_orbit_radius = _native_orbit_radius()
	_transferred_orbit_phase = (
		direction_from_new_owner.angle() - _ability.orbit_angle()
		if direction_from_new_owner.length_squared() > 0.001
		else 0.0
	)
	_owner = new_owner_anchor
	_update_position()

func formation_ring() -> int:
	return 0 if _formation_slot < mini(_formation_count, _ability.inner_ring_capacity()) else 1

func formation_slot() -> int:
	return _formation_slot if formation_ring() == 0 else _formation_slot - _ability.inner_ring_capacity()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var position := screen_position(context)
	var clone_radius: float = radius * scale_factor
	var clone_color: Color = ownership_visual_color(_owner.color)
	var accent_color: Color = ownership_visual_color(_owner.accent)
	clone_color.a = 0.62
	canvas.draw_circle(position, clone_radius * 1.25, Color(accent_color.r, accent_color.g, accent_color.b, 0.18))
	canvas.draw_circle(position, clone_radius, clone_color)
	canvas.draw_circle(position, clone_radius, accent_color, false, 1.2)
	canvas.draw_rect(Rect2(position - Vector2.ONE * clone_radius * 0.42, Vector2.ONE * clone_radius * 0.84), Color(0.88, 1.0, 0.96, 0.72), false, 1.0)

func team_marker_world_height() -> float:
	return radius * 1.3

func is_absorbable() -> bool:
	return true

func attraction_position() -> Vector2:
	return pos

func absorption_radius() -> float:
	return radius

func absorption_visual_color() -> Color:
	return ownership_visual_color(_owner.color)

func _update_position() -> void:
	if _transferred_orbit_radius >= 0.0:
		var transferred_angle: float = _ability.orbit_angle() + _transferred_orbit_phase
		pos = _owner.pos + Vector2.from_angle(transferred_angle) * _transferred_orbit_radius
		return
	var orbit_radius := _native_orbit_radius()
	var angle: float = _ability.orbit_angle() + _formation_phase_offset()
	pos = _owner.pos + Vector2.from_angle(angle) * orbit_radius

func _native_orbit_radius() -> float:
	return _ability.inner_orbit_radius() if formation_ring() == 0 else _ability.outer_orbit_radius()

func _formation_phase_offset() -> float:
	var ring := formation_ring()
	var inner_capacity: int = _ability.inner_ring_capacity()
	var ring_count: int = mini(_formation_count, inner_capacity)
	var ring_slot := _formation_slot
	var phase_offset := 0.0
	if ring == 1:
		ring_count = _formation_count - inner_capacity
		ring_slot = _formation_slot - inner_capacity
		phase_offset = PI / float(maxi(1, ring_count))
	return phase_offset + TAU * float(ring_slot) / float(maxi(1, ring_count))
