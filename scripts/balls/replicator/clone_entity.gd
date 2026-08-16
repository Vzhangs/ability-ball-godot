extends BallEntity

var _owner
var _ability
var _formation_slot := 0
var _formation_count := 1

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

func formation_ring() -> int:
	return 0 if _formation_slot < mini(_formation_count, _ability.inner_ring_capacity()) else 1

func formation_slot() -> int:
	return _formation_slot if formation_ring() == 0 else _formation_slot - _ability.inner_ring_capacity()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var position := screen_position(context)
	var clone_radius: float = radius * scale_factor
	var clone_color: Color = _owner.color
	clone_color.a = 0.62
	canvas.draw_circle(position, clone_radius * 1.25, Color(_owner.accent.r, _owner.accent.g, _owner.accent.b, 0.18))
	canvas.draw_circle(position, clone_radius, clone_color)
	canvas.draw_circle(position, clone_radius, _owner.accent, false, 1.2)
	canvas.draw_rect(Rect2(position - Vector2.ONE * clone_radius * 0.42, Vector2.ONE * clone_radius * 0.84), Color(0.88, 1.0, 0.96, 0.72), false, 1.0)

func is_absorbable() -> bool:
	return true

func attraction_position() -> Vector2:
	return pos

func absorption_radius() -> float:
	return radius

func absorption_visual_color() -> Color:
	return _owner.color

func _update_position() -> void:
	var ring := formation_ring()
	var inner_capacity: int = _ability.inner_ring_capacity()
	var ring_count: int = mini(_formation_count, inner_capacity)
	var ring_slot := _formation_slot
	var orbit_radius: float = _ability.inner_orbit_radius()
	var phase_offset := 0.0
	if ring == 1:
		ring_count = _formation_count - inner_capacity
		ring_slot = _formation_slot - inner_capacity
		orbit_radius = _ability.outer_orbit_radius()
		phase_offset = PI / float(maxi(1, ring_count))
	var angle: float = _ability.orbit_angle() + phase_offset + TAU * float(ring_slot) / float(maxi(1, ring_count))
	pos = _owner.pos + Vector2.from_angle(angle) * orbit_radius
