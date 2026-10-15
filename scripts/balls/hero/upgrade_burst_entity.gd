extends BallEntity

const AttributeIcon := preload("res://scripts/balls/hero/attribute_icon.gd")

var _source
var _attribute_kind := ""
var _native_color := Color.WHITE
var _duration := 1.0

func _init(
	spawn_owner_side: int,
	source,
	attribute_kind: String,
	duration: float
) -> void:
	owner_side = spawn_owner_side
	_source = source
	_attribute_kind = attribute_kind
	_native_color = AttributeIcon.color_for(attribute_kind)
	pos = source.pos
	radius = source.radius
	_duration = maxf(0.001, duration)
	remaining = _duration
	tags = PackedStringArray(["hero_upgrade_burst_vfx"])
	draw_layer = 120

func animation_progress() -> float:
	return clampf(1.0 - remaining / _duration, 0.0, 1.0)

func step(_battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	pos = _source.pos

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _source == null:
		return
	var progress := animation_progress()
	var envelope := sin(progress * PI)
	var scale := lerpf(0.58, 1.72, progress) + sin(progress * PI) * 0.18
	var center := screen_position(context, _source.pos)
	var draw_radius := radius * context.scale_factor * 0.72 * scale
	var color := ownership_visual_color(_native_color)
	canvas.draw_circle(center, draw_radius * 1.38, Color(color.r, color.g, color.b, envelope * 0.17))
	canvas.draw_circle(center, draw_radius, Color(color.r * 0.36, color.g * 0.36, color.b * 0.36, envelope * 0.88))
	canvas.draw_circle(
		center,
		draw_radius,
		Color(color.r, color.g, color.b, envelope),
		false,
		maxf(2.0, draw_radius * 0.11)
	)
	AttributeIcon.draw_symbol(canvas, center, draw_radius * 0.68, _attribute_kind, envelope)
