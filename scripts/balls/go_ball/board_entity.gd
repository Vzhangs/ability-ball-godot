extends BallEntity

var _arena_size := Vector2.ONE
var _grid_size := 10
var _body_color := Color("151719")
var _accent_color := Color("f2efe2")

func _init(
	spawn_owner_side: int,
	arena_size: Vector2,
	spawn_grid_size: int,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	_arena_size = Vector2(maxf(1.0, arena_size.x), maxf(1.0, arena_size.y))
	_grid_size = maxi(1, spawn_grid_size)
	_body_color = body_color
	_accent_color = accent_color
	pos = _arena_size * 0.5
	radius = 0.0
	remaining = -1.0
	tags = PackedStringArray(["go_board"])
	draw_layer = -140

func grid_size() -> int:
	return _grid_size

func line_spacing() -> Vector2:
	return _arena_size / float(_grid_size)


func intersection_at(world_position: Vector2) -> Vector2i:
	var spacing := line_spacing()
	return Vector2i(
		clampi(int(round(world_position.x / spacing.x - 0.5)), 0, _grid_size - 1),
		clampi(int(round(world_position.y / spacing.y - 0.5)), 0, _grid_size - 1)
	)


func intersection_position(intersection: Vector2i) -> Vector2:
	return (Vector2(intersection) + Vector2(0.5, 0.5)) * line_spacing()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var origin := context.point(Vector2.ZERO)
	var extent := _arena_size * context.scale_factor
	var line_color := Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.24)
	var shadow_color := Color(_body_color.r, _body_color.g, _body_color.b, 0.18)
	var line_width := maxf(1.0, 1.15 * context.scale_factor)
	var spacing := line_spacing() * context.scale_factor
	var first_intersection := origin + spacing * 0.5
	var last_intersection := origin + extent - spacing * 0.5
	for index in range(_grid_size):
		var x := first_intersection.x + spacing.x * float(index)
		var y := first_intersection.y + spacing.y * float(index)
		canvas.draw_line(Vector2(x + 1.0, first_intersection.y), Vector2(x + 1.0, last_intersection.y), shadow_color, line_width, true)
		canvas.draw_line(Vector2(x, first_intersection.y), Vector2(x, last_intersection.y), line_color, line_width, true)
		canvas.draw_line(Vector2(first_intersection.x, y + 1.0), Vector2(last_intersection.x, y + 1.0), shadow_color, line_width, true)
		canvas.draw_line(Vector2(first_intersection.x, y), Vector2(last_intersection.x, y), line_color, line_width, true)
