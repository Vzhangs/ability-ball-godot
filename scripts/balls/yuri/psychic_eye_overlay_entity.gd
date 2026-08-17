extends BallEntity

const EyeRenderer := preload("res://scripts/balls/yuri/eye_renderer.gd")
const PEAK_SCALE := 1.42

var _source
var _duration := 1.0
var _color := Color("f07cff")

func _init(spawn_owner_side: int, source, duration: float, color: Color) -> void:
	owner_side = spawn_owner_side
	_source = source
	pos = source.pos
	radius = source.radius
	_duration = maxf(0.001, duration)
	remaining = _duration
	_color = color
	tags = PackedStringArray(["psychic_eye_overlay_vfx"])
	draw_layer = 100

func step(_battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	pos = _source.pos

func animation_scale() -> float:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	return lerpf(1.0, PEAK_SCALE, sin(progress * PI))

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _source == null:
		return
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var envelope := sin(progress * PI)
	var center := screen_position(context, _source.pos)
	var draw_radius := radius * context.scale_factor
	var scale := animation_scale()
	canvas.draw_circle(
		center,
		draw_radius * scale * 0.86,
		Color(_color.r, _color.g, _color.b, envelope * 0.16)
	)
	EyeRenderer.draw_eye(canvas, center, draw_radius, context.elapsed, scale, envelope)
