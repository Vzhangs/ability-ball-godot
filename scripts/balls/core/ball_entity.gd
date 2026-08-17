class_name BallEntity
extends RefCounted

## Stable world-entity contract used by ball modules.
## Concrete entities own their behavior and rendering; the battle core only owns lifecycle.

const ABOVE_BALL_DRAW_LAYER := 1

var owner_side := -1
var pos := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 0.0
var remaining := -1.0
var removed := false
var tags := PackedStringArray()
var draw_layer := 0
var _capture_disabled := false
var _ownership_color_override := Color(0.0, 0.0, 0.0, 0.0)

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

## Non-positive layers render below both fighter bodies; positive layers render above them.
func draws_above_balls() -> bool:
	return draw_layer >= ABOVE_BALL_DRAW_LAYER

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

## Generic allegiance-transfer capability used by mind control, hacking, or reflection.
## The optional anchor lets an entity preserve its native owner-relative behavior after transfer.
func can_transfer_ownership() -> bool:
	return owner_side >= 0 and not removed and not is_captured() and is_absorbable()

func transfer_ownership(new_owner_side: int, new_owner_anchor = null) -> bool:
	if new_owner_side < 0 or new_owner_side == owner_side or not can_transfer_ownership():
		return false
	var previous_owner_side := owner_side
	owner_side = new_owner_side
	on_ownership_transferred(previous_owner_side, new_owner_side, new_owner_anchor)
	return true

## Entities that follow or orbit their owner override this hook and update their own anchor.
## The base contract never inspects a concrete entity type.
func on_ownership_transferred(
	_previous_owner_side: int,
	_new_owner_side: int,
	_new_owner_anchor
) -> void:
	pass

## Optional presentation response for transferred entities. Concrete entity draw methods
## resolve their native colors through ownership_visual_color(), without knowing the controller.
func set_ownership_visual_color(color: Color) -> void:
	_ownership_color_override = color

func ownership_visual_color(native_color: Color) -> Color:
	if _ownership_color_override.a <= 0.0:
		return native_color
	return Color(
		_ownership_color_override.r,
		_ownership_color_override.g,
		_ownership_color_override.b,
		native_color.a
	)

func attraction_position() -> Vector2:
	return pos

func absorption_radius() -> float:
	return radius

func absorption_visual_color() -> Color:
	return ownership_visual_color(Color.WHITE)

func absorb(_battle, _absorber_side: int, _center: Vector2) -> bool:
	if not is_absorbable() or removed:
		return false
	removed = true
	return true

func screen_position(context: BallRenderContext, world_position: Vector2 = pos) -> Vector2:
	return context.point(world_position)
