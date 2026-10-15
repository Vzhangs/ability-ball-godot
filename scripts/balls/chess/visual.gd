extends BallVisual

const FACE_COLOR := Color("f1d59a")
const FACE_SHADOW := Color("c89955")
const INK_COLOR := Color("8d1618")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

func trail_alpha() -> float:
	return 0.28

func trail_width_multiplier() -> float:
	return 1.08

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	if ability == null or String(ability.call("active_movement_skill")).is_empty():
		return
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	if String(ability.call("active_movement_skill")) == "rook":
		_draw_rook_lane(canvas, _fighter, context)
	for ring_index in range(2):
		var ring_radius := radius * (1.25 + float(ring_index) * 0.22)
		var start := elapsed * (2.4 + float(ring_index) * 0.55) + float(ring_index) * PI
		canvas.draw_arc(
			position,
			ring_radius,
			start,
			start + PI * 1.35,
			30,
			Color(1.0, 0.77, 0.32, 0.28 - float(ring_index) * 0.07),
			maxf(1.4, radius * 0.065),
			true
		)

func _draw_rook_lane(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var scale_factor: float = context["scale_factor"]
	var direction: Vector2 = ability.call("rook_direction")
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	var normal := direction.orthogonal()
	var phase := String(ability.call("rook_phase"))
	var half_width: float = radius * float(ability.call("rook_lane_width_multiplier"))
	if phase == "windup":
		var target_snapshot: Vector2 = ability.call("rook_target_snapshot")
		var target_position: Vector2 = position + (target_snapshot - fighter.pos) * scale_factor
		canvas.draw_line(
			position,
			target_position,
			Color(1.0, 0.72, 0.22, 0.18),
			maxf(8.0, radius * 0.22),
			true
		)
		canvas.draw_line(
			position,
			target_position,
			Color(1.0, 0.92, 0.62, 0.82),
			maxf(1.8, radius * 0.06),
			true
		)
		for marker_index in range(1, 4):
			var marker_position := position.lerp(target_position, float(marker_index) / 4.0)
			var marker_size := maxf(4.0, radius * 0.12)
			canvas.draw_polyline(PackedVector2Array([
				marker_position - direction * marker_size - normal * marker_size,
				marker_position,
				marker_position - direction * marker_size + normal * marker_size,
			]), Color(1.0, 0.86, 0.48, 0.78), maxf(1.5, radius * 0.055), true)
		return
	var front_length: float = float(ability.call("rook_front_length")) * scale_factor
	var back_length := radius * 0.42
	var start := position - direction * back_length
	var finish := position + direction * front_length
	var lane := PackedVector2Array([
		start - normal * half_width,
		finish - normal * half_width,
		finish + normal * half_width,
		start + normal * half_width,
	])
	canvas.draw_colored_polygon(lane, Color(1.0, 0.48, 0.08, 0.13))
	var outline := lane.duplicate()
	outline.append(lane[0])
	canvas.draw_polyline(outline, Color(1.0, 0.72, 0.22, 0.22), maxf(7.0, radius * 0.2), true)
	canvas.draw_polyline(outline, Color(1.0, 0.92, 0.58, 0.76), maxf(1.7, radius * 0.055), true)
	canvas.draw_line(
		finish - normal * half_width,
		finish + normal * half_width,
		Color(1.0, 0.97, 0.76, 0.94),
		maxf(3.0, radius * 0.095),
		true
	)
	for streak_index in range(3):
		var offset := (float(streak_index) - 1.0) * half_width * 0.48
		canvas.draw_line(
			position + normal * offset - direction * radius * 1.8,
			position + normal * offset - direction * radius * 0.3,
			Color(1.0, 0.78, 0.3, 0.48 - absf(float(streak_index) - 1.0) * 0.1),
			maxf(1.5, radius * 0.055),
			true
		)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius * 1.12, Color(1.0, 0.52, 0.18, 0.18))
	Surface.draw(canvas, position, radius, fighter.color, fighter.accent, Surface.Style.METAL, context["elapsed"])
	canvas.draw_circle(position, radius * 0.82, FACE_SHADOW)
	Surface.draw(canvas, position, radius * 0.72, FACE_COLOR, FACE_COLOR.lightened(0.2), Surface.Style.SOLID, context["elapsed"])
	canvas.draw_circle(position, radius, fighter.accent, false, maxf(2.2, radius * 0.085))
	canvas.draw_circle(position, radius * 0.72, INK_COLOR, false, maxf(1.4, radius * 0.055))
	var font_size := clampi(int(radius * 1.04), 23, 48)
	var text_bounds := radius * 1.5
	var baseline := position + Vector2(-text_bounds * 0.5, font_size * 0.34)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline + Vector2(1.5, 1.5),
		"棋",
		HORIZONTAL_ALIGNMENT_CENTER,
		text_bounds,
		font_size,
		Color(0.1, 0.015, 0.01, 0.48)
	)
	canvas.draw_string(
		CjkFontProviderScript.font(),
		baseline,
		"棋",
		HORIZONTAL_ALIGNMENT_CENTER,
		text_bounds,
		font_size,
		INK_COLOR
	)
