extends BallEntity

var _owner
var _inward := Vector2.ZERO
var _index := 0
var _pulse := 1.0

func _init(spawn_owner_side: int, owner, spawn_position: Vector2, inward: Vector2, index: int) -> void:
	owner_side = spawn_owner_side
	_owner = owner
	pos = spawn_position
	_inward = inward
	_index = index
	tags = PackedStringArray(["showcase_anchor"])
	draw_layer = -20

func step(_battle, delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta * 2.4)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var start := screen_position(context, _owner.pos)
	var finish := screen_position(context)
	var points := _curved_line(start, finish)
	canvas.draw_polyline(points, Color(0.68, 0.87, 1.0, 0.78), 2.25, true)
	canvas.draw_polyline(points, Color(0.90, 0.97, 1.0, 0.35), 0.8, true)
	var scale_factor := context.scale_factor
	var inward := _inward
	var tangent := Vector2(-inward.y, inward.x)
	var tip := finish + inward * 25.0 * scale_factor
	var base_center := finish - inward * 7.0 * scale_factor
	var polygon := PackedVector2Array([
		tip,
		base_center + tangent * 11.0 * scale_factor,
		base_center - tangent * 11.0 * scale_factor,
	])
	canvas.draw_colored_polygon(polygon, Color("16ef44"))
	canvas.draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[0]]), Color("d8ffe1"), 1.3, true)
	if _pulse > 0.0:
		canvas.draw_circle(finish, (13.0 + _pulse * 17.0) * scale_factor, Color(0.14, 1.0, 0.33, _pulse * 0.25), false, 2.0)

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return Color("16ef44")

func _curved_line(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var delta := finish - start
	var normal := Vector2(-delta.y, delta.x).normalized()
	var bend := sin(float(_index) * 1.73) * minf(32.0, delta.length() * 0.08)
	for step_index in range(13):
		var t := float(step_index) / 12.0
		points.append(start.lerp(finish, t) + normal * sin(t * PI) * bend)
	return points
