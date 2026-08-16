class_name BallEntity
extends RefCounted

## Stable world-entity contract used by ball modules.
## Concrete entities own their behavior and rendering; the battle core only owns lifecycle.

var owner_side := -1
var pos := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 0.0
var remaining := -1.0
var removed := false
var tags := PackedStringArray()
var draw_layer := 0
var _capture_disabled := false

func process_lifetime(delta: float) -> void:
	if _capture_disabled:
		return
	tick_lifetime(delta)

func process_step(battle, delta: float) -> void:
	if _capture_disabled:
		return
	step(battle, delta)

func tick_lifetime(delta: float) -> void:
	if remaining < 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		removed = true

func step(_battle, delta: float) -> void:
	pos += velocity * delta

func draw(_canvas: CanvasItem, _context: BallRenderContext) -> void:
	pass

func draw_hud(_canvas: CanvasItem, _health_bar_bounds: Rect2) -> void:
	pass

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func is_hostile_to(side: int) -> bool:
	return owner_side >= 0 and owner_side != side

## Opt-in combat contract for summons and other world entities.
## Attacks query this capability by geometry; they never need the concrete entity type.
func can_receive_attack(_source_side: int) -> bool:
	return false

func receive_attack(
	_battle,
	_amount: float,
	_source_side: int,
	_hit_color: Color
) -> float:
	return 0.0

func is_absorbable() -> bool:
	return false

func can_be_captured() -> bool:
	return is_absorbable() and not _capture_disabled and not removed

func disable_for_capture() -> bool:
	if not can_be_captured():
		return false
	_capture_disabled = true
	velocity = Vector2.ZERO
	return true

func is_captured() -> bool:
	return _capture_disabled

func attraction_position() -> Vector2:
	return pos

func absorption_radius() -> float:
	return radius

func absorption_visual_color() -> Color:
	return Color.WHITE

func absorb(_battle, _absorber_side: int, _center: Vector2) -> bool:
	if not is_absorbable() or removed:
		return false
	removed = true
	return true

func screen_position(context: BallRenderContext, world_position: Vector2 = pos) -> Vector2:
	return context.point(world_position)
