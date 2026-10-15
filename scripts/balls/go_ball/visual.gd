extends BallVisual

const FORM_BLACK := "black"
const FORM_WHITE := "white"
const FORM_BALANCED := "balanced"
const INK_BLACK := Color("101214")
const STONE_WHITE := Color("f5f0df")
const GOLD := Color("e4bd67")

func trail_alpha() -> float:
	return 0.22

func trail_width_multiplier() -> float:
	return 0.95

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	var pulse := 1.0 + sin(elapsed * 2.4) * 0.035
	canvas.draw_circle(center, radius * 1.2 * pulse, Color(GOLD.r, GOLD.g, GOLD.b, 0.09))

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var form := _form_kind()
	if form == FORM_BALANCED:
		_draw_balanced(canvas, center, radius)
	elif form == FORM_BLACK:
		_draw_dominant(canvas, center, radius, INK_BLACK, STONE_WHITE)
	else:
		_draw_dominant(canvas, center, radius, STONE_WHITE, INK_BLACK)
	canvas.draw_circle(center, radius, GOLD, false, maxf(1.5, radius * 0.055))
	_draw_count_marks(canvas, center, radius, fighter)

func _draw_dominant(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	body: Color,
	edge: Color
) -> void:
	Surface.draw(canvas, center, radius, body, edge, Surface.Style.SOLID, 0.0)

func _draw_balanced(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	Surface.draw(canvas, center, radius, STONE_WHITE, GOLD, Surface.Style.SOLID, 0.0)
	var sample_count := 48
	var line_width := radius * 2.0 / float(sample_count) + 0.75
	for sample in range(sample_count + 1):
		var y := lerpf(-radius, radius, float(sample) / float(sample_count))
		var outer_x := sqrt(maxf(0.0, radius * radius - y * y))
		var local_y := y + radius * 0.5 if y < 0.0 else y - radius * 0.5
		var curve_x := sqrt(maxf(0.0, radius * radius * 0.25 - local_y * local_y))
		var boundary_x := curve_x if y < 0.0 else -curve_x
		canvas.draw_line(
			center + Vector2(boundary_x, y),
			center + Vector2(outer_x, y),
			INK_BLACK,
			line_width,
			true
		)
	canvas.draw_circle(center, radius, INK_BLACK, false, maxf(2.2, radius * 0.085))
	canvas.draw_circle(
		center + Vector2(-radius * 0.24, -radius * 0.3),
		radius * 0.24,
		Color(1.0, 1.0, 1.0, 0.28)
	)

func _draw_count_marks(canvas: CanvasItem, center: Vector2, radius: float, fighter) -> void:
	var black_count := _black_count()
	var white_count := _white_count()
	var total := black_count + white_count
	if total <= 0:
		return
	var mark_count := mini(16, total)
	for index in range(mark_count):
		var angle := -PI * 0.75 + float(index) * PI * 1.5 / maxf(1.0, float(mark_count - 1))
		var position := center + Vector2.from_angle(angle) * radius * 0.74
		var represents_black := index < int(round(float(mark_count) * float(black_count) / float(total)))
		var color := STONE_WHITE if represents_black else INK_BLACK
		canvas.draw_circle(position, radius * 0.045, color)
	canvas.draw_circle(center, radius * 0.06, fighter.accent)

func _form_kind() -> String:
	return String(ability.call("form_kind")) if ability != null else FORM_BALANCED

func _black_count() -> int:
	return int(ability.call("black_count")) if ability != null else 0

func _white_count() -> int:
	return int(ability.call("white_count")) if ability != null else 0
