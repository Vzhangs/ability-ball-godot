extends BallVisual

const BODY_DARK := Color("10191e")
const BODY_MID := Color("223841")
const METAL_BLACK := Color("11191d")
const METAL_DARK := Color("40565a")
const METAL_MID := Color("789296")
const METAL_LIGHT := Color("c5ded3")
const STOCK_COLOR := Color("57756a")
const SCOPE_GLASS := Color("ff496d")
const MUZZLE_LOCAL_FORWARD := 1.92

func trail_alpha() -> float:
	return 0.18

func trail_width_multiplier() -> float:
	return 0.82

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position + Vector2(0.0, radius * 0.22), radius * 1.08, Color(0.0, 0.0, 0.0, 0.30))

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var direction := _gun_direction()
	var perpendicular := direction.orthogonal()
	if perpendicular.y < 0.0 or (is_zero_approx(perpendicular.y) and perpendicular.x < 0.0):
		perpendicular = -perpendicular
	var recoil := _recoil_amount() * radius * 0.13
	var muzzle_distance_multiplier := 3.4
	if module != null:
		muzzle_distance_multiplier = module.settingf("muzzle_distance_multiplier")
	var gun_origin := (
		position
		+ direction * radius * (muzzle_distance_multiplier - MUZZLE_LOCAL_FORWARD)
		- direction * recoil
	)
	canvas.draw_circle(position, radius, BODY_DARK)
	canvas.draw_circle(position, radius * 0.86, BODY_MID)
	canvas.draw_arc(position, radius * 0.68, -PI * 0.1, PI * 1.18, 26, Color(fighter.accent.r, fighter.accent.g, fighter.accent.b, 0.48), maxf(1.5, radius * 0.08), true)
	_draw_stock(canvas, gun_origin, direction, perpendicular, radius)
	_draw_receiver(canvas, gun_origin, direction, perpendicular, radius, fighter.accent)
	_draw_barrel(canvas, gun_origin, direction, perpendicular, radius, fighter.accent)
	_draw_scope(canvas, gun_origin, direction, perpendicular, radius)
	canvas.draw_circle(position, radius, fighter.accent, false, maxf(2.0, radius * 0.08), true)

func _draw_stock(
	canvas: CanvasItem,
	origin: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	radius: float
) -> void:
	var polygon := PackedVector2Array([
		_point(origin, direction, perpendicular, radius, -1.38, -0.22),
		_point(origin, direction, perpendicular, radius, -1.36, 0.22),
		_point(origin, direction, perpendicular, radius, -1.10, 0.32),
		_point(origin, direction, perpendicular, radius, -0.60, 0.20),
		_point(origin, direction, perpendicular, radius, -0.42, 0.07),
		_point(origin, direction, perpendicular, radius, -0.44, -0.18),
		_point(origin, direction, perpendicular, radius, -0.96, -0.30),
	])
	canvas.draw_colored_polygon(polygon, STOCK_COLOR)
	canvas.draw_polyline(PackedVector2Array([
		_point(origin, direction, perpendicular, radius, -1.38, -0.22),
		_point(origin, direction, perpendicular, radius, -0.96, -0.30),
		_point(origin, direction, perpendicular, radius, -0.44, -0.18),
		_point(origin, direction, perpendicular, radius, -0.42, 0.07),
		_point(origin, direction, perpendicular, radius, -0.60, 0.20),
		_point(origin, direction, perpendicular, radius, -1.10, 0.32),
		_point(origin, direction, perpendicular, radius, -1.36, 0.22),
		_point(origin, direction, perpendicular, radius, -1.38, -0.22),
	]), METAL_BLACK, maxf(1.8, radius * 0.075), true)
	canvas.draw_line(
		_point(origin, direction, perpendicular, radius, -1.16, -0.16),
		_point(origin, direction, perpendicular, radius, -0.57, -0.04),
		METAL_LIGHT,
		maxf(1.4, radius * 0.065),
		true
	)

func _draw_receiver(
	canvas: CanvasItem,
	origin: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	radius: float,
	accent: Color
) -> void:
	var polygon := PackedVector2Array([
		_point(origin, direction, perpendicular, radius, -0.48, -0.25),
		_point(origin, direction, perpendicular, radius, 0.52, -0.25),
		_point(origin, direction, perpendicular, radius, 0.64, -0.08),
		_point(origin, direction, perpendicular, radius, 0.52, 0.22),
		_point(origin, direction, perpendicular, radius, -0.48, 0.22),
	])
	canvas.draw_colored_polygon(polygon, METAL_MID)
	canvas.draw_polyline(PackedVector2Array([
		_point(origin, direction, perpendicular, radius, -0.48, -0.25),
		_point(origin, direction, perpendicular, radius, 0.52, -0.25),
		_point(origin, direction, perpendicular, radius, 0.64, -0.08),
		_point(origin, direction, perpendicular, radius, 0.52, 0.22),
		_point(origin, direction, perpendicular, radius, -0.48, 0.22),
		_point(origin, direction, perpendicular, radius, -0.48, -0.25),
	]), METAL_BLACK, maxf(2.0, radius * 0.08), true)
	canvas.draw_line(
		_point(origin, direction, perpendicular, radius, -0.33, -0.05),
		_point(origin, direction, perpendicular, radius, 0.43, -0.05),
		accent,
		maxf(1.6, radius * 0.07),
		true
	)

func _draw_barrel(
	canvas: CanvasItem,
	origin: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	radius: float,
	accent: Color
) -> void:
	var barrel_start := _point(origin, direction, perpendicular, radius, 0.48, -0.02)
	var muzzle_start := _point(origin, direction, perpendicular, radius, 1.57, -0.02)
	var muzzle_tip := _point(origin, direction, perpendicular, radius, MUZZLE_LOCAL_FORWARD, -0.02)
	canvas.draw_line(barrel_start, muzzle_start, METAL_BLACK, maxf(4.4, radius * 0.22), true)
	canvas.draw_line(barrel_start, muzzle_start, METAL_LIGHT, maxf(1.8, radius * 0.075), true)
	var muzzle_polygon := PackedVector2Array([
		_point(origin, direction, perpendicular, radius, 1.54, -0.16),
		_point(origin, direction, perpendicular, radius, 1.84, -0.16),
		_point(origin, direction, perpendicular, radius, MUZZLE_LOCAL_FORWARD, -0.09),
		_point(origin, direction, perpendicular, radius, MUZZLE_LOCAL_FORWARD, 0.06),
		_point(origin, direction, perpendicular, radius, 1.84, 0.13),
		_point(origin, direction, perpendicular, radius, 1.54, 0.13),
	])
	canvas.draw_colored_polygon(muzzle_polygon, METAL_DARK)
	canvas.draw_line(muzzle_start, muzzle_tip, accent, maxf(1.6, radius * 0.07), true)
	canvas.draw_line(
		_point(origin, direction, perpendicular, radius, MUZZLE_LOCAL_FORWARD, -0.13),
		_point(origin, direction, perpendicular, radius, MUZZLE_LOCAL_FORWARD, 0.10),
		METAL_LIGHT,
		maxf(1.5, radius * 0.065),
		true
	)

func _draw_scope(
	canvas: CanvasItem,
	origin: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	radius: float
) -> void:
	var scope_back := _point(origin, direction, perpendicular, radius, -0.38, -0.52)
	var scope_front := _point(origin, direction, perpendicular, radius, 0.72, -0.52)
	canvas.draw_line(scope_back, scope_front, METAL_BLACK, maxf(8.0, radius * 0.36), true)
	canvas.draw_line(scope_back, scope_front, METAL_LIGHT, maxf(3.6, radius * 0.17), true)
	canvas.draw_circle(scope_back, radius * 0.18, METAL_DARK)
	var objective_bell := PackedVector2Array([
		_point(origin, direction, perpendicular, radius, 0.52, -0.68),
		_point(origin, direction, perpendicular, radius, 0.76, -0.73),
		_point(origin, direction, perpendicular, radius, 0.84, -0.65),
		_point(origin, direction, perpendicular, radius, 0.84, -0.39),
		_point(origin, direction, perpendicular, radius, 0.76, -0.31),
		_point(origin, direction, perpendicular, radius, 0.52, -0.36),
	])
	canvas.draw_colored_polygon(objective_bell, METAL_DARK)
	canvas.draw_circle(scope_front, radius * 0.20, METAL_BLACK)
	canvas.draw_circle(scope_front, radius * 0.155, SCOPE_GLASS)
	canvas.draw_circle(
		_point(origin, direction, perpendicular, radius, 0.76, -0.57),
		radius * 0.045,
		Color.WHITE
	)
	for mount_x in [-0.14, 0.40]:
		canvas.draw_line(
			_point(origin, direction, perpendicular, radius, mount_x, -0.37),
			_point(origin, direction, perpendicular, radius, mount_x, -0.23),
			METAL_DARK,
			maxf(2.4, radius * 0.11),
			true
		)

func _point(
	origin: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	radius: float,
	forward: float,
	down: float
) -> Vector2:
	return origin + direction * radius * forward + perpendicular * radius * down

func _gun_direction() -> Vector2:
	if ability != null and ability.has_method("gun_direction"):
		var direction: Vector2 = ability.call("gun_direction")
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	return Vector2.RIGHT

func _recoil_amount() -> float:
	if ability != null and ability.has_method("recoil_amount"):
		return float(ability.call("recoil_amount"))
	return 0.0
