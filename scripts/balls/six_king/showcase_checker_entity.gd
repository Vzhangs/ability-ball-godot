extends BallEntity

var cells: Array[Dictionary] = []
var _duration := 1.0

func _init(spawn_owner_side: int, checker_cells: Array[Dictionary], duration: float) -> void:
	owner_side = spawn_owner_side
	cells = checker_cells
	_duration = duration
	remaining = _duration
	tags = PackedStringArray(["showcase_checker"])
	draw_layer = -50

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var origin := context.origin
	var alpha := clampf(remaining / 0.45, 0.0, 1.0)
	var font: Font = ThemeDB.fallback_font
	for cell in cells:
		var rect: Rect2 = cell["rect"]
		var screen_rect := Rect2(origin + rect.position * scale_factor, rect.size * scale_factor)
		var active: bool = cell["active"]
		var color := Color(0.72, 0.72, 0.72, 0.52 * alpha) if active else Color(0.22, 0.23, 0.24, 0.28 * alpha)
		canvas.draw_rect(screen_rect, color)
		canvas.draw_rect(screen_rect, Color(0.86, 0.76, 0.12, 0.38 * alpha), false, 1.4)
		canvas.draw_string(font, screen_rect.position + Vector2(0.0, screen_rect.size.y * 0.63), str(cell["value"]), HORIZONTAL_ALIGNMENT_CENTER, screen_rect.size.x, 26, Color(0.91, 0.94, 0.46, 0.9 * alpha))
