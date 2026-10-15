extends BallEntity

const GRID_SIZE := 3
const CELL_COUNT := GRID_SIZE * GRID_SIZE
const LOW_COLOR := Color("2f72e8")
const MID_COLOR := Color("ffd45f")
const HIGH_COLOR := Color("ff4e5a")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

var _arena_size := Vector2.ONE
var _values: Array[int] = []
var _duration := 1.0
var _fade_duration := 0.35
var _damage_max := 50
var _body_color := Color.WHITE
var _accent_color := Color.WHITE
var _age := 0.0

func _init(
	spawn_owner_side: int,
	arena_size: Vector2,
	cell_values: Array[int],
	duration: float,
	fade_duration: float,
	damage_max: int,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	_arena_size = Vector2(maxf(1.0, arena_size.x), maxf(1.0, arena_size.y))
	_values = cell_values.duplicate()
	assert(_values.size() == CELL_COUNT, "WDC grid requires exactly nine cell values")
	_duration = maxf(0.001, duration)
	_fade_duration = clampf(fade_duration, 0.001, _duration * 0.5)
	_damage_max = maxi(0, damage_max)
	_body_color = body_color
	_accent_color = accent_color
	pos = _arena_size * 0.5
	radius = 0.0
	remaining = _duration
	tags = PackedStringArray(["wdc_grid"])
	draw_layer = -120

func step(_battle, delta: float) -> void:
	_age += delta

func damage_at(world_position: Vector2) -> int:
	return _values[cell_index_at(world_position)]

func cell_index_at(world_position: Vector2) -> int:
	var column := clampi(int(floor(world_position.x / _arena_size.x * GRID_SIZE)), 0, GRID_SIZE - 1)
	var row := clampi(int(floor(world_position.y / _arena_size.y * GRID_SIZE)), 0, GRID_SIZE - 1)
	return row * GRID_SIZE + column

func values_snapshot() -> Array[int]:
	return _values.duplicate()

func animation_alpha() -> float:
	var fade_in := clampf(_age / _fade_duration, 0.0, 1.0)
	var fade_out := clampf(remaining / _fade_duration, 0.0, 1.0)
	return minf(fade_in, fade_out)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var alpha := animation_alpha()
	if alpha <= 0.001:
		return
	var arena_origin := context.point(Vector2.ZERO)
	var cell_world_size := _arena_size / float(GRID_SIZE)
	var cell_screen_size := cell_world_size * context.scale_factor
	var pulse := 0.88 + 0.12 * sin(_age * 3.2)
	for row in range(GRID_SIZE):
		for column in range(GRID_SIZE):
			var index := row * GRID_SIZE + column
			var value := _values[index]
			var ratio := float(value) / maxf(1.0, float(_damage_max))
			var cell_color := _damage_color(ratio)
			var cell_position := arena_origin + Vector2(column, row) * cell_screen_size
			var cell_rect := Rect2(cell_position, cell_screen_size)
			var fill_alpha := alpha * pulse * (0.075 + ratio * 0.105)
			canvas.draw_rect(
				cell_rect.grow(-1.2 * context.scale_factor),
				Color(cell_color.r, cell_color.g, cell_color.b, fill_alpha)
			)
			canvas.draw_rect(
				cell_rect.grow(-1.2 * context.scale_factor),
				Color(cell_color.r, cell_color.g, cell_color.b, alpha * (0.34 + ratio * 0.28)),
				false,
				maxf(1.0, 1.8 * context.scale_factor)
			)
			_draw_damage_value(canvas, cell_rect, value, cell_color, alpha)
	var outer_rect := Rect2(arena_origin, _arena_size * context.scale_factor)
	canvas.draw_rect(
		outer_rect,
		Color(_accent_color.r, _accent_color.g, _accent_color.b, alpha * 0.48),
		false,
		maxf(1.4, 2.4 * context.scale_factor)
	)

func _draw_damage_value(
	canvas: CanvasItem,
	cell_rect: Rect2,
	value: int,
	cell_color: Color,
	alpha: float
) -> void:
	var font_size := clampi(int(minf(cell_rect.size.x, cell_rect.size.y) * 0.19), 17, 48)
	var baseline := Vector2(cell_rect.position.x, cell_rect.get_center().y + font_size * 0.34)
	var text := str(value)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline + Vector2(2.0, 2.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		cell_rect.size.x,
		font_size,
		Color(0.0, 0.0, 0.0, alpha * 0.92)
	)
	var text_color := cell_color.lerp(Color.WHITE, 0.52)
	text_color.a = alpha * 0.92
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		cell_rect.size.x,
		font_size,
		text_color
	)

func _damage_color(ratio: float) -> Color:
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped <= 0.5:
		return LOW_COLOR.lerp(MID_COLOR, clamped * 2.0)
	return MID_COLOR.lerp(HIGH_COLOR, (clamped - 0.5) * 2.0)
