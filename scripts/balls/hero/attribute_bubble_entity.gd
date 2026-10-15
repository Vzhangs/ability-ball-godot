extends BallEntity

const AttributeIcon := preload("res://scripts/balls/hero/attribute_icon.gd")
const SPAWN_ANIMATION_DURATION := 0.34

var _attribute_kind := ""
var _ability_ref: WeakRef
var _native_color := Color.WHITE
var _age := 0.0

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_radius: float,
	spawn_attribute_kind: String,
	owner_ability: BallAbility
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	radius = spawn_radius
	_attribute_kind = spawn_attribute_kind
	_ability_ref = weakref(owner_ability)
	_native_color = AttributeIcon.color_for(spawn_attribute_kind)
	remaining = -1.0
	tags = PackedStringArray(["hero_attribute_bubble", "hero_attribute_%s" % spawn_attribute_kind])
	draw_layer = 5

func attribute_kind() -> String:
	return _attribute_kind

func spawn_progress() -> float:
	return clampf(_age / SPAWN_ANIMATION_DURATION, 0.0, 1.0)

func step(battle, delta: float) -> void:
	_age += delta
	var owner = battle.fighter_for_uid(owner_fighter_uid)
	if owner == null or owner.hp <= 0.0:
		removed = true
		return
	if owner.pos.distance_squared_to(pos) > pow(owner.radius + radius, 2.0):
		return
	var owner_ability = _ability_ref.get_ref() if _ability_ref != null else null
	if owner_ability == null:
		removed = true
		return
	if bool(owner_ability.call("collect_attribute", battle, owner, _attribute_kind, pos)):
		removed = true

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var progress := spawn_progress()
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var overshoot := sin(progress * PI) * (1.0 - progress) * 0.24
	var pulse := 1.0 + sin(context.elapsed * 4.6 + float(get_instance_id() % 17)) * 0.055
	var draw_radius := radius * context.scale_factor * (0.28 + eased * 0.72 + overshoot) * pulse
	var color := ownership_visual_color(_native_color)
	canvas.draw_circle(center, draw_radius * 1.65, Color(color.r, color.g, color.b, 0.16))
	canvas.draw_circle(center, draw_radius * 1.12, Color(color.r, color.g, color.b, 0.38))
	canvas.draw_circle(center, draw_radius, Color(color.r * 0.42, color.g * 0.42, color.b * 0.42, 0.92))
	canvas.draw_circle(center, draw_radius, Color(color.r, color.g, color.b, 0.96), false, maxf(2.0, draw_radius * 0.13))
	canvas.draw_arc(
		center,
		draw_radius * 1.28,
		-context.elapsed * 1.7,
		-context.elapsed * 1.7 + PI * 1.15,
		20,
		Color(color.r, color.g, color.b, 0.72),
		maxf(1.2, draw_radius * 0.075),
		true
	)
	canvas.draw_circle(
		center + Vector2(-draw_radius * 0.43, -draw_radius * 0.43),
		draw_radius * 0.11,
		Color(1.0, 1.0, 1.0, 0.54)
	)
	AttributeIcon.draw_symbol(canvas, center, draw_radius * 1.02, _attribute_kind)

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_visual_color() -> Color:
	return ownership_visual_color(_native_color)
