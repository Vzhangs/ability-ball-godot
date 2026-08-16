extends BallEntity

const MAX_CANNONS := 22
const INNER_RING_CAPACITY := 8
const OUTER_RING_CAPACITY := 14
const INNER_ORBIT_RADIUS := 54.0
const OUTER_ORBIT_RADIUS := 82.0
const CANNON_RADIUS_SCALE := 0.36

var _owner
var _ability
var _formation_slot := 0
var _formation_count := 1

func _init(spawn_owner_side: int, owner, owner_ability) -> void:
	owner_side = spawn_owner_side
	_owner = owner
	_ability = owner_ability
	pos = owner.pos
	radius = owner.radius * CANNON_RADIUS_SCALE
	tags = PackedStringArray(["clone"])
	draw_layer = -5

func step(_battle, _delta: float) -> void:
	_update_position()

func set_formation_slot(slot: int, total_count: int) -> void:
	_formation_slot = clampi(slot, 0, MAX_CANNONS - 1)
	_formation_count = clampi(total_count, 1, MAX_CANNONS)
	_update_position()

func formation_ring() -> int:
	return 0 if _formation_slot < mini(_formation_count, INNER_RING_CAPACITY) else 1

func formation_slot() -> int:
	return _formation_slot if formation_ring() == 0 else _formation_slot - INNER_RING_CAPACITY

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
	var ring_count: int = mini(_formation_count, INNER_RING_CAPACITY)
	var ring_slot := _formation_slot
	var orbit_radius := INNER_ORBIT_RADIUS
	var phase_offset := 0.0
	if ring == 1:
		ring_count = mini(_formation_count - INNER_RING_CAPACITY, OUTER_RING_CAPACITY)
		ring_slot = _formation_slot - INNER_RING_CAPACITY
		orbit_radius = OUTER_ORBIT_RADIUS
		phase_offset = PI / float(maxi(1, ring_count))
	var angle: float = _ability.orbit_angle() + phase_offset + TAU * float(ring_slot) / float(maxi(1, ring_count))
	pos = _owner.pos + Vector2.from_angle(angle) * orbit_radius
