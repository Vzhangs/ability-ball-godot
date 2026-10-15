class_name NamedCastEntity
extends BallEntity

## Presentation-only label for character balls with named techniques.
## The casting ball owns when it appears and which voice event accompanies it.

const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

var _source
var _title := ""
var _duration := 1.0
var _primary := Color.WHITE
var _accent := Color("70e8ff")

func _init(
	spawn_owner_side: int,
	source,
	title: String,
	duration: float,
	primary: Color,
	accent: Color
) -> void:
	owner_side = spawn_owner_side
	owner_fighter_uid = source.fighter_uid
	_source = source
	_title = title
	_duration = maxf(0.05, duration)
	remaining = _duration
	_primary = primary
	_accent = accent
	pos = source.pos
	radius = source.radius
	tags = PackedStringArray(["named_cast_vfx"])
	draw_layer = 180

func step(_battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	pos = _source.pos

func title_text() -> String:
	return _title

func animation_scale() -> float:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	return 0.76 + sin(progress * PI) * 0.34

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _source == null or _title.is_empty():
		return
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var envelope := sin(progress * PI)
	var center := screen_position(context, _source.pos)
	var draw_radius := radius * context.scale_factor
	var font_size := clampi(int(draw_radius * 0.56 * animation_scale()), 16, 34)
	var text_width := maxf(draw_radius * 3.8, float(_title.length()) * float(font_size) * 1.02)
	var baseline := center + Vector2(-text_width * 0.5, -draw_radius * 1.58)
	var plate := Rect2(
		baseline + Vector2(-8.0, -float(font_size) * 0.86),
		Vector2(text_width + 16.0, float(font_size) * 1.22)
	)
	canvas.draw_rect(plate.grow(3.0), Color(_accent.r, _accent.g, _accent.b, envelope * 0.12), true)
	canvas.draw_rect(plate, Color(0.015, 0.02, 0.06, envelope * 0.78), true)
	canvas.draw_rect(plate, Color(_accent.r, _accent.g, _accent.b, envelope * 0.76), false, 1.5, true)
	for offset in [Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0)]:
		canvas.draw_string(
			CjkFontProviderScript.font(), baseline + offset, _title,
			HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size,
			Color(0.0, 0.0, 0.0, envelope * 0.92)
		)
	canvas.draw_string(
		CjkFontProviderScript.font(), baseline, _title,
		HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size,
		Color(_primary.r, _primary.g, _primary.b, envelope)
	)
