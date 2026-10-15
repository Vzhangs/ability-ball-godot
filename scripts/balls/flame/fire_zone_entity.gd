extends BallEntity

var _duration := 0.0
var _absorption_radius_cap := 1.0
var _absorption_radius_ratio := 1.0
var _travel_direction := Vector2.RIGHT

func _init(spawn_owner_side: int, spawn_position: Vector2, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	remaining = float(config["duration"])
	_duration = remaining
	radius = float(config["radius"])
	_absorption_radius_cap = float(config["absorption_radius_cap"])
	_absorption_radius_ratio = float(config["absorption_radius_ratio"])
	_travel_direction = Vector2(config["travel_direction"]).normalized()
	if _travel_direction.length_squared() <= 0.001:
		_travel_direction = Vector2.RIGHT
	tags = PackedStringArray(["flame_zone"])
	draw_layer = -40

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var age := maxf(0.0, _duration - remaining)
	var life_alpha := clampf(remaining / maxf(_duration, 0.001), 0.0, 1.0)
	var appear_scale := clampf(age / 0.16, 0.0, 1.0)
	var alpha := life_alpha * appear_scale
	var position := screen_position(context)
	var draw_radius := radius * scale_factor * (0.82 + appear_scale * 0.18)
	# A filled, ragged ground smear joins adjacent samples into one fire road.
	# There is deliberately no circular plate, outline, or ring around each sample.
	var phase := context.elapsed * 9.2 + pos.x * 0.137 + pos.y * 0.091
	var forward := _travel_direction
	var sideways := forward.rotated(PI * 0.5)
	canvas.draw_colored_polygon(
		_ground_patch(position, forward, sideways, draw_radius, 1.0),
		ownership_visual_color(Color(0.22, 0.025, 0.005, alpha * 0.4))
	)
	canvas.draw_colored_polygon(
		_ground_patch(position, forward, sideways, draw_radius, 0.72),
		ownership_visual_color(Color(0.94, 0.12, 0.015, alpha * 0.36))
	)
	canvas.draw_colored_polygon(
		_ground_patch(
			position + forward * draw_radius * 0.06,
			forward,
			sideways,
			draw_radius,
			0.42
		),
		ownership_visual_color(Color(1.0, 0.62, 0.045, alpha * 0.42))
	)
	for flame_index in range(3):
		var horizontal_ratio := -0.55 + float(flame_index) * 0.55
		var base := position \
			+ forward * horizontal_ratio * draw_radius * 0.7 \
			+ sideways * sin(phase * 0.31 + float(flame_index)) * draw_radius * 0.2
		var flicker := 0.78 + 0.24 * sin(phase + float(flame_index) * 1.73)
		var tip := base + Vector2(
			sin(phase * 0.77 + float(flame_index) * 2.11) * draw_radius * 0.12,
			-draw_radius * (0.5 + float(flame_index % 2) * 0.1) * flicker
		)
		_draw_flame_tongue(
			canvas,
			base,
			tip,
			draw_radius * (0.2 + float(flame_index % 2) * 0.025),
			alpha
		)
	for ember_index in range(1):
		var travel := fposmod(
			context.elapsed * (0.7 + float(ember_index) * 0.08) + float(ember_index) * 0.31,
			1.0
		)
		var ember_position := position + Vector2(
			(float(ember_index) - 1.0) * draw_radius * 0.42
				+ sin(phase * 0.43 + float(ember_index)) * draw_radius * 0.12,
			draw_radius * 0.18 - travel * draw_radius * 1.22
		)
		var ember_size := maxf(1.0, draw_radius * 0.045)
		canvas.draw_colored_polygon(PackedVector2Array([
			ember_position + Vector2(0.0, -ember_size * 1.7),
			ember_position + Vector2(ember_size * 0.55, 0.0),
			ember_position + Vector2(0.0, ember_size * 1.7),
			ember_position + Vector2(-ember_size * 0.55, 0.0),
		]), ownership_visual_color(Color(1.0, 0.76, 0.12, sin(travel * PI) * alpha)))

func _ground_patch(
	center: Vector2,
	forward: Vector2,
	sideways: Vector2,
	draw_radius: float,
	scale: float
) -> PackedVector2Array:
	var length := draw_radius * 1.12 * scale
	var width := draw_radius * 0.72 * scale
	return PackedVector2Array([
		center - forward * length - sideways * width * 0.18,
		center - forward * length * 0.62 - sideways * width * 0.86,
		center - forward * length * 0.08 - sideways * width * 0.68,
		center + forward * length * 0.46 - sideways * width,
		center + forward * length - sideways * width * 0.24,
		center + forward * length * 0.72 + sideways * width * 0.68,
		center + forward * length * 0.12 + sideways * width * 0.76,
		center - forward * length * 0.5 + sideways * width,
	])

func _draw_flame_tongue(
	canvas: CanvasItem,
	base: Vector2,
	tip: Vector2,
	half_width: float,
	alpha: float
) -> void:
	var height := base.distance_to(tip)
	if height <= 0.001:
		return
	var upward := (tip - base) / height
	var sideways := upward.rotated(PI * 0.5)
	var shoulder := base + upward * height * 0.38
	canvas.draw_colored_polygon(PackedVector2Array([
		base - sideways * half_width,
		shoulder - sideways * half_width * 0.72,
		tip,
		shoulder + sideways * half_width * 0.5,
		base + sideways * half_width,
	]), ownership_visual_color(Color(1.0, 0.22, 0.025, alpha * 0.68)))
	var inner_base := base + upward * height * 0.08
	var inner_tip := base + upward * height * 0.64 + sideways * half_width * 0.1
	var inner_shoulder := inner_base.lerp(inner_tip, 0.42)
	canvas.draw_colored_polygon(PackedVector2Array([
		inner_base - sideways * half_width * 0.44,
		inner_shoulder - sideways * half_width * 0.3,
		inner_tip,
		inner_shoulder + sideways * half_width * 0.24,
		inner_base + sideways * half_width * 0.44,
	]), ownership_visual_color(Color(1.0, 0.78, 0.12, alpha)))

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_radius() -> float:
	return minf(_absorption_radius_cap, radius * _absorption_radius_ratio)

func absorption_visual_color() -> Color:
	return ownership_visual_color(Color("ff7a24"))
