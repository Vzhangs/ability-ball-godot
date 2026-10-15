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
	tags = PackedStringArray(["frost_ice_trail"])
	draw_layer = -42

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var scale_factor := context.scale_factor
	var age := maxf(0.0, _duration - remaining)
	var life_alpha := clampf(remaining / maxf(_duration, 0.001), 0.0, 1.0)
	var appear := clampf(age / 0.16, 0.0, 1.0)
	var alpha := life_alpha * appear
	var center := screen_position(context)
	var draw_radius := radius * scale_factor * (0.84 + appear * 0.16)
	var forward := _travel_direction
	var sideways := forward.rotated(PI * 0.5)
	var phase := pos.x * 0.071 + pos.y * 0.047
	canvas.draw_colored_polygon(
		_ice_patch(center, forward, sideways, draw_radius, 1.0, phase),
		ownership_visual_color(Color(0.025, 0.22, 0.36, alpha * 0.52))
	)
	canvas.draw_colored_polygon(
		_ice_patch(center + forward * draw_radius * 0.05, forward, sideways, draw_radius, 0.72, phase + 1.3),
		ownership_visual_color(Color(0.2, 0.76, 0.9, alpha * 0.42))
	)
	canvas.draw_colored_polygon(
		_ice_patch(center - forward * draw_radius * 0.08, forward, sideways, draw_radius, 0.38, phase + 2.6),
		ownership_visual_color(Color(0.78, 0.98, 1.0, alpha * 0.54))
	)
	for crack_index in range(3):
		var along := (-0.52 + float(crack_index) * 0.5) * draw_radius
		var root := center + forward * along - sideways * draw_radius * 0.38
		var elbow := root + sideways * draw_radius * 0.34 + forward * draw_radius * (0.08 if crack_index % 2 == 0 else -0.08)
		var tip := elbow + sideways * draw_radius * 0.35 - forward * draw_radius * 0.1
		canvas.draw_polyline(
			PackedVector2Array([root, elbow, tip]),
			ownership_visual_color(Color(0.82, 0.99, 1.0, alpha * 0.7)),
			maxf(0.8, scale_factor * 1.1),
			true
		)
	for crystal_index in range(2):
		var ratio := -0.34 + float(crystal_index) * 0.72
		var root := center + forward * draw_radius * ratio + sideways * draw_radius * 0.3
		var tip := root - sideways * draw_radius * (0.34 + float(crystal_index) * 0.08)
		var half_width := draw_radius * 0.08
		canvas.draw_colored_polygon(PackedVector2Array([
			root - forward * half_width,
			tip,
			root + forward * half_width,
		]), ownership_visual_color(Color(0.72, 0.96, 1.0, alpha * 0.78)))

func _ice_patch(
	center: Vector2,
	forward: Vector2,
	sideways: Vector2,
	draw_radius: float,
	scale: float,
	phase: float
) -> PackedVector2Array:
	var length := draw_radius * 1.12 * scale
	var width := draw_radius * 0.68 * scale
	return PackedVector2Array([
		center - forward * length - sideways * width * (0.2 + 0.08 * sin(phase)),
		center - forward * length * 0.58 - sideways * width * 0.88,
		center - forward * length * 0.06 - sideways * width * 0.7,
		center + forward * length * 0.5 - sideways * width,
		center + forward * length - sideways * width * 0.22,
		center + forward * length * 0.7 + sideways * width * 0.66,
		center + forward * length * 0.1 + sideways * width * 0.78,
		center - forward * length * 0.52 + sideways * width,
	])

func is_absorbable() -> bool:
	return true

func can_transfer_ownership() -> bool:
	return false

func absorption_radius() -> float:
	return minf(_absorption_radius_cap, radius * _absorption_radius_ratio)

func absorption_visual_color() -> Color:
	return ownership_visual_color(Color("73e9ff"))
