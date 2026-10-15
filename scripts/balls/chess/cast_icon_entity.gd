extends BallEntity

const START_SCALE := 0.62
const PEAK_SCALE := 1.58
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

var _source
var _symbol := ""
var _duration := 1.0
var _body_color := Color("a92120")
var _accent_color := Color("f6d89a")

func _init(
	spawn_owner_side: int,
	source,
	symbol: String,
	duration: float,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	_source = source
	_symbol = symbol
	pos = source.pos
	radius = source.radius
	_duration = maxf(0.001, duration)
	remaining = _duration
	_body_color = body_color
	_accent_color = accent_color
	tags = PackedStringArray(["chess_cast_icon_vfx"])
	draw_layer = 120

func step(_battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	pos = _source.pos

func animation_scale() -> float:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	return lerpf(START_SCALE, PEAK_SCALE, sin(progress * PI))

func icon_text() -> String:
	return _symbol

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _source == null:
		return
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var envelope := sin(progress * PI)
	var center := screen_position(context, _source.pos)
	var draw_radius := radius * context.scale_factor
	var icon_radius := draw_radius * 0.78 * animation_scale()
	canvas.draw_circle(
		center,
		icon_radius * 1.22,
		Color(_accent_color.r, _accent_color.g, _accent_color.b, envelope * 0.18)
	)
	canvas.draw_circle(
		center,
		icon_radius,
		Color(_body_color.r, _body_color.g, _body_color.b, envelope * 0.94)
	)
	canvas.draw_circle(
		center,
		icon_radius * 0.78,
		Color(_accent_color.r, _accent_color.g, _accent_color.b, envelope * 0.96)
	)
	canvas.draw_circle(
		center,
		icon_radius * 0.78,
		Color(0.55, 0.06, 0.06, envelope * 0.96),
		false,
		maxf(1.5, icon_radius * 0.065)
	)
	var font_size := clampi(int(icon_radius * 1.08), 18, 58)
	var text_width := icon_radius * 1.55
	var baseline := center + Vector2(-text_width * 0.5, font_size * 0.34)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline + Vector2(2.0, 2.0),
		_symbol,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(0.08, 0.01, 0.01, envelope * 0.62)
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline,
		_symbol,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		font_size,
		Color(0.55, 0.035, 0.035, envelope)
	)
