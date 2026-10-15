extends RefCounted

const Glow := preload("res://scripts/balls/core/combat_glow.gd")
const CYAN := Color("59cce5")
const BLUE := Color("507cb5")

var _motes := MultiMesh.new()

func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_motes.transform_format = MultiMesh.TRANSFORM_2D
	_motes.use_colors = true
	_motes.mesh = quad
	_motes.instance_count = 32

func draw_floor(canvas: CanvasItem, bounds: Rect2, elapsed: float) -> void:
	canvas.draw_rect(bounds, Color("09121f"))
	var center := bounds.get_center()
	var extent := minf(bounds.size.x, bounds.size.y)
	Glow.halo(canvas, center, extent * 0.68, Color(0.10, 0.27, 0.37, 0.40))
	Glow.halo(canvas, bounds.position + bounds.size * Vector2(0.28, 0.30), extent * 0.36, Color(0.06, 0.30, 0.42, 0.16))
	Glow.halo(canvas, bounds.position + bounds.size * Vector2(0.72, 0.72), extent * 0.32, Color(0.26, 0.12, 0.42, 0.17))
	# Screen-space density stays bounded even for the largest configured arena.
	var pitch := bounds.size.x / 16.0
	var rows := mini(48, int(bounds.size.y / pitch))
	var minor_lines := PackedVector2Array()
	var major_lines := PackedVector2Array()
	var intersections := PackedVector2Array()
	for column in range(1, 16):
		var x := bounds.position.x + float(column) * pitch
		var line := PackedVector2Array([Vector2(x, bounds.position.y), Vector2(x, bounds.end.y)])
		if column % 4:
			minor_lines.append_array(line)
		else:
			major_lines.append_array(line)
	for row in range(1, rows + 1):
		var y := bounds.position.y + float(row) * pitch
		var line := PackedVector2Array([Vector2(bounds.position.x, y), Vector2(bounds.end.x, y)])
		if row % 4:
			minor_lines.append_array(line)
		else:
			major_lines.append_array(line)
	canvas.draw_multiline(minor_lines, Color(CYAN, 0.038), 1.0, true)
	canvas.draw_multiline(major_lines, Color(CYAN, 0.078), 1.0, true)
	for column in range(2, 16, 2):
		for row in range(2, rows, 2):
			var point := bounds.position + Vector2(column, row) * pitch
			intersections.append_array(PackedVector2Array([point - Vector2(0.5, 0), point + Vector2(0.5, 0)]))
	if not intersections.is_empty():
		canvas.draw_multiline(intersections, Color(CYAN, 0.16), 1.5, true)
	for ring in [0.17, 0.34]:
		canvas.draw_arc(center, extent * ring, 0, TAU, 96, Color(CYAN, 0.08), 1.0, true)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var direction := Vector2.from_angle(angle)
		canvas.draw_line(center + direction * extent * 0.326, center + direction * extent * 0.34, Color(CYAN, 0.18), 1.2, true)
	for side in [0.0, 1.0]:
		canvas.draw_arc(center, extent * 0.35, elapsed * 0.025 + side * PI, elapsed * 0.025 + side * PI + 0.40, 18, Color(CYAN, 0.16), 1.4, true)
	canvas.draw_line(center - Vector2(5, 0), center + Vector2(5, 0), Color(CYAN, 0.18), 1.0, true)
	canvas.draw_line(center - Vector2(0, 5), center + Vector2(0, 5), Color(CYAN, 0.18), 1.0, true)
	# Ambient motes use analytic time, so pause and deterministic replay agree.
	for index in range(32):
		var drift_offset := float(index) * 2.399963
		var uv := Vector2(fposmod(float(index) * 0.618034, 1.0), fposmod(float(index) * 0.381966 - elapsed * (0.007 + float(index % 3) * 0.003), 1.0))
		uv.x += sin(elapsed * 0.3 + drift_offset) * 0.012
		var point := bounds.position + bounds.size * (Vector2(0.04, 0.04) + uv * 0.92)
		var alpha := (0.12 + 0.12 * sin(elapsed * 0.7 + drift_offset)) * sin(uv.y * PI)
		var radius := 2.0 + float(index % 3) * 0.6
		_motes.set_instance_transform_2d(index, Transform2D(Vector2(radius, 0), Vector2(0, radius), point))
		_motes.set_instance_color(index, Color(CYAN, alpha * 1.5))
	canvas.draw_multimesh(_motes, Glow.texture())

func draw_frame(canvas: CanvasItem, bounds: Rect2, elapsed: float) -> void:
	canvas.draw_rect(bounds.grow(7.0), Color("03070e"), false, 12.0)
	canvas.draw_rect(bounds.grow(6.0), Color(BLUE, 0.40), false, 1.0)
	canvas.draw_rect(bounds.grow(2.0), Color(CYAN, 0.07), false, 8.0)
	canvas.draw_rect(bounds, Color("c7eef7"), false, 2.0)
	canvas.draw_rect(bounds.grow(-3.0), Color(CYAN, 0.13), false, 1.0)
	var length := minf(28.0, bounds.size.y * 0.12)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			var corner := bounds.position + bounds.size * Vector2(x, y)
			var direction := Vector2(1.0 - x * 2.0, 1.0 - y * 2.0)
			Glow.halo(canvas, corner, 25.0, Color(CYAN, 0.16))
			Glow.streak(canvas, corner, corner + Vector2(direction.x * length, 0), Color(CYAN, 0.90), 2.3)
			Glow.streak(canvas, corner, corner + Vector2(0, direction.y * length), Color(CYAN, 0.90), 2.3)
	for index in range(1, 16):
		var x := bounds.position.x + bounds.size.x * float(index) / 16.0
		var height := 5.0 if index % 4 == 0 else 2.0
		canvas.draw_line(Vector2(x, bounds.end.y + 7), Vector2(x, bounds.end.y + 7 + height), Color(CYAN, 0.35), 1.0, true)
	var pulse := 0.45 + sin(elapsed * 1.5) * 0.15
	for side in [0.0, 1.0]:
		var point := Vector2(bounds.position.x + bounds.size.x * side, bounds.get_center().y)
		Glow.streak(canvas, point - Vector2(0, 13), point + Vector2(0, 13), Color(CYAN, pulse), 2.0)
