extends RefCounted

static func draw_eye(
	canvas: CanvasItem,
	position: Vector2,
	radius: float,
	elapsed: float,
	scale: float = 1.0,
	alpha: float = 1.0
) -> void:
	var scaled_radius := radius * scale
	var eye_width := scaled_radius * 0.63
	var eye_height := scaled_radius * 0.31
	var eye_points := PackedVector2Array()
	for index in range(13):
		var ratio := float(index) / 12.0
		var x := lerpf(-eye_width, eye_width, ratio)
		var y := -sin(ratio * PI) * eye_height
		eye_points.append(position + Vector2(x, y))
	for index in range(12, -1, -1):
		var ratio := float(index) / 12.0
		var x := lerpf(-eye_width, eye_width, ratio)
		var y := sin(ratio * PI) * eye_height
		eye_points.append(position + Vector2(x, y))
	var eye_color := Color("f4c7ff")
	eye_color.a = alpha
	var iris_color := Color("b742d0")
	iris_color.a = alpha
	var pupil_color := Color("16051d")
	pupil_color.a = alpha
	canvas.draw_colored_polygon(eye_points, eye_color)
	canvas.draw_circle(position, scaled_radius * 0.25, iris_color)
	canvas.draw_circle(position, scaled_radius * 0.115, pupil_color)
	var glint := position + Vector2.from_angle(-elapsed * 1.8) * scaled_radius * 0.14
	canvas.draw_circle(glint, scaled_radius * 0.055, Color(1.0, 1.0, 1.0, alpha))
