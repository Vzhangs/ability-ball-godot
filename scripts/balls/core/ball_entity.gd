class_name BallEntity
extends RefCounted

## Stable world-entity contract used by ball modules.
## Concrete entities own their behavior and rendering; the battle core only owns lifecycle.

const ABOVE_BALL_DRAW_LAYER := 1

var owner_side := -1
## Runtime creator identity. `owner_side` remains the stable team allegiance;
## this UID distinguishes multiple main fighters that share that allegiance.
var owner_fighter_uid := -1
var combat_origin_fighter_uid := -1
## Projectiles inherit a value snapshot of the producing unit at launch.
var combat_source: Dictionary = {}
var combat_contact_source: Dictionary = {}
var pos := Vector2.ZERO
var velocity := Vector2.ZERO
var radius := 0.0
var remaining := -1.0
var removed := false
var tags := PackedStringArray()
var draw_layer := 0
var status_effects: Array[BallStatusEffect] = []
var _capture_disabled := false
var _ownership_color_override := Color(0.0, 0.0, 0.0, 0.0)

## Independent units override this with a stable category ID and public name.
## Empty categories are attack carriers and inherit their producer's statistics.
func combat_category() -> Dictionary:
	return {}

func combat_identity() -> Dictionary:
	var category := combat_category()
	if category.is_empty() and not combat_source.is_empty():
		return combat_source.duplicate(true)
	return {
		"fighter_uid": owner_fighter_uid, "team_id": owner_side,
		"category_id": String(category.get("id", "body")),
		"category_name": String(category.get("name", "本体与技能")),
		"origin_fighter_uid": combat_origin_fighter_uid if combat_origin_fighter_uid >= 0 else owner_fighter_uid,
	}

func process_lifetime(delta: float) -> void:
	if _capture_disabled:
		return
	tick_lifetime(delta)

func process_step(battle, delta: float) -> void:
	if _capture_disabled:
		return
	step(battle, delta * status_step_multiplier())

func status_step_multiplier() -> float:
	var slow := 1.0
	var haste := 1.0
	for effect: BallStatusEffect in status_effects:
		if not effect.is_expired():
			var value := maxf(0.0, effect.entity_step_multiplier())
			if value < 1.0:
				slow = minf(slow, value)
			else:
				haste = maxf(haste, value)
	return slow * haste

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

## Independently visible allied units opt in to the generic non-duel team marker.
## Projectiles, areas, trails, pickups, and short-lived VFX keep the default zero height.
func team_marker_world_height() -> float:
	return 0.0

## Separate anchor hook keeps the public view independent of entity-specific visual geometry.
func team_marker_world_position() -> Vector2:
	return pos

## Non-positive layers render below both fighter bodies; positive layers render above them.
func draws_above_balls() -> bool:
	return draw_layer >= ABOVE_BALL_DRAW_LAYER

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func is_hostile_to(side: int) -> bool:
	return owner_side >= 0 and owner_side != side

## Terrain durability is distinct from a combat unit's life. This semantic flag
## does not change collision, attack reception, capture, or ownership capabilities.
func is_terrain() -> bool:
	return false

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

## Optional entity-to-entity contact contract. Moving summons may resolve contacts
## against any entity that opts in, without knowing its concrete type or owning ball.
func participates_in_entity_collision() -> bool:
	return false

## Zero makes an entity static during contact separation; positive values share motion.
func entity_collision_inverse_mass() -> float:
	return 1.0

func entity_contact_damage() -> float:
	return 0.0

func entity_contact_color() -> Color:
	return absorption_visual_color()

func can_resolve_entity_contact(_other: BallEntity) -> bool:
	return false

func begin_entity_contact(_other: BallEntity) -> void:
	pass

## Optional fighter-to-entity contact contract. Entities opt in when hostile
## fighter bodies should be physically separated and allowed to exchange their
## own advertised contact damage through the generic battle pipeline.
func participates_in_fighter_collision() -> bool:
	return false

## Zero keeps the entity fixed while the fighter takes the full separation and
## impulse; positive values let both bodies share the collision response.
func fighter_collision_inverse_mass() -> float:
	return entity_collision_inverse_mass()

func can_resolve_fighter_contact(_fighter_side: int) -> bool:
	return false

func begin_fighter_contact(_fighter_side: int) -> void:
	pass

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
	owner_fighter_uid = int(new_owner_anchor.get("fighter_uid")) \
		if new_owner_anchor != null and new_owner_anchor.get("fighter_uid") != null \
		else -1
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
