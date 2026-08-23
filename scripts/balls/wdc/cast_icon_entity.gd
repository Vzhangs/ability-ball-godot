extends BallEntity

const START_SCALE := 0.66
const PEAK_SCALE := 1.52

var _source
var _duration := 1.0
var _body_color := Color.WHITE
var _accent_color := Color.WHITE

func _init(
	spawn_owner_side: int,
	source,
	duration: float,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	_source = source
	pos = source.pos
	radius = source.radius
	_duration = maxf(0.001, duration)
	remaining = _duration
	_body_color = body_color
	_accent_color = accent_color
	tags = PackedStringArray(["wdc_cast_icon_vfx"])
	draw_layer = 120

func step(_battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	pos = _source.pos

func animation_scale() -> float:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	return lerpf(START_SCALE, PEAK_SCALE, sin(progress * PI))

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if _source == null:
		return
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var envelope := sin(progress * PI)
	var center := screen_position(context, _source.pos)
	var draw_radius := radius * context.scale_factor
	var icon_extent := draw_radius * 0.72 * animation_scale()
	canvas.draw_circle(
		center,
		icon_extent * 1.35,
		Color(_accent_color.r, _accent_color.g, _accent_color.b, envelope * 0.16)
	)
	canvas.draw_circle(
		center,
		icon_extent * 1.02,
		Color(_body_color.r, _body_color.g, _body_color.b, envelope * 0.86)
	)
	var cell_size := icon_extent * 0.42
	var gap := icon_extent * 0.09
	var total_size := cell_size * 3.0 + gap * 2.0
	var start := center - Vector2.ONE * total_size * 0.5
	for row in range(3):
		for column in range(3):
			var cell_position := start + Vector2(column, row) * (cell_size + gap)
			var cell_rect := Rect2(cell_position, Vector2.ONE * cell_size)
			var index := row * 3 + column
			var brightness := 0.46 + 0.54 * sin(progress * PI + float(index) * 0.42)
			var color := _accent_color.lerp(Color.WHITE, brightness * 0.34)
			color.a = envelope * (0.72 + brightness * 0.28)
			canvas.draw_rect(cell_rect, color)
			canvas.draw_rect(cell_rect, Color(1.0, 1.0, 1.0, envelope * 0.66), false, maxf(1.0, icon_extent * 0.055))
