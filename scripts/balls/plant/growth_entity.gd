extends BallEntity

const PeaProjectileEntity := preload("res://scripts/balls/plant/pea_projectile_entity.gd")
const SunPickupEntity := preload("res://scripts/balls/plant/sun_pickup_entity.gd")

enum GrowthForm {
	SEED,
	SUNFLOWER,
	PEA_FIRE,
	PEA_ICE,
	PEA_GATLING,
}

var hp := 0.0
var max_hp := 0.0

var _form: GrowthForm = GrowthForm.SEED
var _body_color := Color("39f05f")
var _accent_color := Color("d8ff67")
var _config: Dictionary = {}
var _growth_timer := 0.0
var _growth_animation_duration := 0.0
var _growth_animation_elapsed := 0.0
var _action_timer := 0.0
var _hit_flash := 0.0
var _entity_contact_timer := 0.0

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	body_color: Color,
	accent_color: Color,
	config: Dictionary
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_body_color = body_color
	_accent_color = accent_color
	_config = config.duplicate(true)
	radius = float(_config["seed_radius"])
	_growth_timer = float(_config["growth_delay"])
	tags = PackedStringArray(["plant_attachment", "plant_growth"])
	draw_layer = -4

func growth_form() -> GrowthForm:
	return _form

func form_name() -> String:
	match _form:
		GrowthForm.SEED:
			return "seed"
		GrowthForm.SUNFLOWER:
			return "sunflower"
		GrowthForm.PEA_FIRE:
			return "pea_fire"
		GrowthForm.PEA_ICE:
			return "pea_ice"
		GrowthForm.PEA_GATLING:
			return "pea_gatling"
	return "unknown"

func step(battle, delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta * 5.0)
	_entity_contact_timer = maxf(0.0, _entity_contact_timer - delta)
	if _form == GrowthForm.SEED:
		_growth_timer -= delta
		if _growth_timer <= 0.0:
			_grow_once(battle)
		return
	_growth_animation_elapsed = minf(
		_growth_animation_duration,
		_growth_animation_elapsed + delta
	)
	_action_timer -= delta
	if _action_timer > 0.0:
		return
	if _form == GrowthForm.SUNFLOWER:
		_action_timer += float(_config["sun_launch_interval"])
		_launch_sun(battle)
	else:
		_action_timer += _current_fire_interval()
		_fire_projectile(battle)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var position := screen_position(context)
	var draw_radius := radius * context.scale_factor
	var form_color := ownership_visual_color(_form_color())
	var accent := ownership_visual_color(_accent_color)
	if is_captured():
		form_color.a = 0.62
		accent.a = 0.62
	if _form == GrowthForm.SEED:
		_draw_seed(canvas, position, draw_radius, form_color, accent, context.elapsed)
	else:
		var growth_scale := growth_animation_scale()
		var mature_radius := draw_radius * growth_scale
		var mature_position := position + Vector2(
			0.0,
			draw_radius * (1.0 - growth_scale) * 0.58
		)
		_draw_ground_shadow(canvas, mature_position, mature_radius)
		_draw_stem_and_leaves(canvas, mature_position, mature_radius)
		match _form:
			GrowthForm.SUNFLOWER:
				_draw_sunflower(canvas, mature_position, mature_radius, context.elapsed)
			GrowthForm.PEA_FIRE:
				_draw_fire_pea(canvas, context, mature_position, mature_radius)
			GrowthForm.PEA_ICE:
				_draw_ice_pea(canvas, context, mature_position, mature_radius)
			GrowthForm.PEA_GATLING:
				_draw_gatling_pea(canvas, context, mature_position, mature_radius)
		_draw_health_bar(canvas, position, draw_radius, accent)
	if _hit_flash > 0.0:
		canvas.draw_circle(position, draw_radius, Color(1.0, 1.0, 1.0, _hit_flash * 0.65))

func growth_animation_progress() -> float:
	if _form == GrowthForm.SEED or _growth_animation_duration <= 0.0:
		return 1.0
	return clampf(_growth_animation_elapsed / _growth_animation_duration, 0.0, 1.0)

func growth_animation_scale() -> float:
	var progress := growth_animation_progress()
	var eased_progress := 1.0 - pow(1.0 - progress, 3.0)
	return lerpf(0.32, 1.0, eased_progress) + sin(progress * PI) * 0.14

func _draw_seed(
	canvas: CanvasItem,
	position: Vector2,
	draw_radius: float,
	form_color: Color,
	accent: Color,
	elapsed: float
) -> void:
	var pulse := 1.0 + sin(elapsed * 4.0 + float(get_instance_id() % 17)) * 0.06
	canvas.draw_circle(position, draw_radius * 1.38 * pulse, Color(accent.r, accent.g, accent.b, 0.12))
	var shell_points := PackedVector2Array([
		position + Vector2(0.0, -draw_radius),
		position + Vector2(draw_radius * 0.82, -draw_radius * 0.22),
		position + Vector2(draw_radius * 0.58, draw_radius * 0.82),
		position + Vector2(-draw_radius * 0.58, draw_radius * 0.82),
		position + Vector2(-draw_radius * 0.82, -draw_radius * 0.22),
	])
	canvas.draw_colored_polygon(shell_points, form_color)
	var shell_outline := shell_points.duplicate()
	shell_outline.append(shell_points[0])
	canvas.draw_polyline(shell_outline, ownership_visual_color(Color("d9a96b")), maxf(1.2, draw_radius * 0.14), true)
	canvas.draw_arc(position, draw_radius * 0.52, -PI * 0.82, PI * 0.22, 12, ownership_visual_color(Color("5b351d")), maxf(1.2, draw_radius * 0.12), true)
	var sprout_root := position + Vector2(0.0, -draw_radius * 0.82)
	canvas.draw_line(sprout_root, sprout_root + Vector2(0.0, -draw_radius * 0.62), accent, maxf(1.6, draw_radius * 0.15), true)
	canvas.draw_colored_polygon(PackedVector2Array([
		sprout_root + Vector2(0.0, -draw_radius * 0.44),
		sprout_root + Vector2(draw_radius * 0.78, -draw_radius * 0.72),
		sprout_root + Vector2(draw_radius * 0.2, -draw_radius * 0.12),
	]), accent)
	canvas.draw_colored_polygon(PackedVector2Array([
		sprout_root + Vector2(0.0, -draw_radius * 0.38),
		sprout_root + Vector2(-draw_radius * 0.64, -draw_radius * 0.6),
		sprout_root + Vector2(-draw_radius * 0.18, -draw_radius * 0.06),
	]), ownership_visual_color(Color("72e85b")))

func _draw_ground_shadow(canvas: CanvasItem, position: Vector2, draw_radius: float) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		position + Vector2(-draw_radius * 0.92, draw_radius * 0.72),
		position + Vector2(-draw_radius * 0.52, draw_radius * 0.54),
		position + Vector2(draw_radius * 0.58, draw_radius * 0.54),
		position + Vector2(draw_radius * 0.96, draw_radius * 0.72),
		position + Vector2(draw_radius * 0.5, draw_radius * 0.88),
		position + Vector2(-draw_radius * 0.52, draw_radius * 0.88),
	]), Color(0.0, 0.0, 0.0, 0.24))

func _draw_stem_and_leaves(canvas: CanvasItem, position: Vector2, draw_radius: float) -> void:
	var stem_bottom := position + Vector2(0.0, draw_radius * 0.68)
	var stem_top := position + Vector2(0.0, -draw_radius * 0.22)
	var stem_shadow := ownership_visual_color(Color("176a35"))
	var stem_light := ownership_visual_color(Color("72e85b"))
	canvas.draw_line(stem_bottom, stem_top, stem_shadow, maxf(3.0, draw_radius * 0.27), true)
	canvas.draw_line(stem_bottom + Vector2(-draw_radius * 0.07, 0.0), stem_top + Vector2(-draw_radius * 0.04, 0.0), stem_light, maxf(1.2, draw_radius * 0.08), true)
	_draw_leaf(canvas, position + Vector2(-draw_radius * 0.04, draw_radius * 0.34), -2.78, draw_radius, Color("36c95a"))
	_draw_leaf(canvas, position + Vector2(draw_radius * 0.04, draw_radius * 0.46), -0.22, draw_radius, Color("66e65a"))

func _draw_leaf(
	canvas: CanvasItem,
	root: Vector2,
	angle: float,
	draw_radius: float,
	leaf_color: Color
) -> void:
	var direction := Vector2.from_angle(angle)
	var perpendicular := direction.rotated(PI * 0.5)
	var length := draw_radius * 0.98
	var width := draw_radius * 0.31
	var points := PackedVector2Array([
		root,
		root + direction * length * 0.48 + perpendicular * width,
		root + direction * length,
		root + direction * length * 0.48 - perpendicular * width,
	])
	canvas.draw_colored_polygon(points, ownership_visual_color(leaf_color))
	canvas.draw_line(root, root + direction * length * 0.86, ownership_visual_color(Color("d2ff7c")), maxf(1.0, draw_radius * 0.055), true)

func _draw_sunflower(
	canvas: CanvasItem,
	position: Vector2,
	draw_radius: float,
	elapsed: float
) -> void:
	var center := position + Vector2(0.0, -draw_radius * 0.48)
	var rotation := sin(elapsed * 0.8 + float(get_instance_id() % 7)) * 0.035
	canvas.draw_circle(center, draw_radius * 1.02, Color(1.0, 0.76, 0.1, 0.12))
	for petal in range(14):
		var angle := float(petal) * TAU / 14.0 + rotation
		canvas.draw_colored_polygon(
			_petal_points(center, angle, draw_radius * 0.96, draw_radius * 0.25),
			ownership_visual_color(Color("ffd43d" if petal % 2 == 0 else "ffb82e"))
		)
	var face_color := ownership_visual_color(Color("8c5528"))
	var face_shadow := ownership_visual_color(Color("59331d"))
	canvas.draw_circle(center, draw_radius * 0.66, face_shadow)
	canvas.draw_circle(center + Vector2(-draw_radius * 0.05, -draw_radius * 0.05), draw_radius * 0.57, face_color)
	var eye_offset := draw_radius * 0.22
	for eye_x in [-eye_offset, eye_offset]:
		canvas.draw_circle(center + Vector2(eye_x, -draw_radius * 0.1), draw_radius * 0.085, Color("20160f"))
		canvas.draw_circle(center + Vector2(eye_x - draw_radius * 0.025, -draw_radius * 0.13), draw_radius * 0.025, Color.WHITE)
	canvas.draw_arc(center + Vector2(0.0, draw_radius * 0.03), draw_radius * 0.27, PI * 0.16, PI * 0.84, 10, Color("3b2115"), maxf(1.2, draw_radius * 0.08), true)

func _petal_points(center: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var direction := Vector2.from_angle(angle)
	var perpendicular := direction.rotated(PI * 0.5)
	var root := center + direction * length * 0.42
	return PackedVector2Array([
		root - perpendicular * width,
		center + direction * length,
		root + perpendicular * width,
		center + direction * length * 0.2,
	])

func _draw_fire_pea(
	canvas: CanvasItem,
	context: BallRenderContext,
	position: Vector2,
	draw_radius: float
) -> void:
	var direction := _aim_direction(context, position)
	var perpendicular := direction.rotated(PI * 0.5)
	var head_center := position + Vector2(0.0, -draw_radius * 0.42)
	canvas.draw_circle(head_center, draw_radius * 0.98, Color(1.0, 0.22, 0.04, 0.14))
	_draw_back_sepals(canvas, head_center, direction, draw_radius, Color("b82919"))
	canvas.draw_circle(head_center, draw_radius * 0.69, ownership_visual_color(Color("e94322")))
	canvas.draw_circle(head_center - direction * draw_radius * 0.08, draw_radius * 0.5, ownership_visual_color(Color("ff7a2f")))
	_draw_flame_crest(canvas, head_center, direction, perpendicular, draw_radius, context.elapsed)
	_draw_single_barrel(canvas, head_center, direction, draw_radius, Color("ff7a2f"), Color("5c1d16"), Color("ffd85a"))
	_draw_pea_eye(canvas, head_center, direction, perpendicular, draw_radius, Color("31100c"))

func _draw_ice_pea(
	canvas: CanvasItem,
	context: BallRenderContext,
	position: Vector2,
	draw_radius: float
) -> void:
	var direction := _aim_direction(context, position)
	var perpendicular := direction.rotated(PI * 0.5)
	var head_center := position + Vector2(0.0, -draw_radius * 0.42)
	canvas.draw_circle(head_center, draw_radius * 1.02, Color(0.28, 0.9, 1.0, 0.14))
	_draw_back_sepals(canvas, head_center, direction, draw_radius, Color("3aa9c8"))
	canvas.draw_circle(head_center, draw_radius * 0.7, ownership_visual_color(Color("48bdd9")))
	canvas.draw_circle(head_center - direction * draw_radius * 0.08, draw_radius * 0.51, ownership_visual_color(Color("8ceaff")))
	_draw_ice_crown(canvas, head_center, direction, perpendicular, draw_radius)
	_draw_single_barrel(canvas, head_center, direction, draw_radius, Color("67d8ed"), Color("174e67"), Color("d5fbff"))
	_draw_pea_eye(canvas, head_center, direction, perpendicular, draw_radius, Color("123b52"))
	canvas.draw_arc(head_center, draw_radius * 0.78, -PI * 0.4, PI * 0.72, 14, ownership_visual_color(Color("d5fbff")), maxf(1.2, draw_radius * 0.07), true)

func _draw_gatling_pea(
	canvas: CanvasItem,
	context: BallRenderContext,
	position: Vector2,
	draw_radius: float
) -> void:
	var direction := _aim_direction(context, position)
	var perpendicular := direction.rotated(PI * 0.5)
	var head_center := position + Vector2(0.0, -draw_radius * 0.42)
	_draw_back_sepals(canvas, head_center, direction, draw_radius, Color("1f7036"))
	canvas.draw_circle(head_center, draw_radius * 0.76, ownership_visual_color(Color("277e3d")))
	canvas.draw_circle(head_center - direction * draw_radius * 0.1, draw_radius * 0.57, ownership_visual_color(Color("4fbd4b")))
	_draw_gatling_helmet(canvas, head_center, direction, perpendicular, draw_radius)
	var barrel_offsets := [
		perpendicular * draw_radius * 0.29 - Vector2(0.0, draw_radius * 0.13),
		-perpendicular * draw_radius * 0.29 - Vector2(0.0, draw_radius * 0.13),
		perpendicular * draw_radius * 0.29 + Vector2(0.0, draw_radius * 0.24),
		-perpendicular * draw_radius * 0.29 + Vector2(0.0, draw_radius * 0.24),
	]
	for barrel_offset: Vector2 in barrel_offsets:
		var start := head_center + direction * draw_radius * 0.18 + barrel_offset
		var finish := start + direction * draw_radius * 0.92
		canvas.draw_line(start, finish, ownership_visual_color(Color("144c2b")), maxf(4.0, draw_radius * 0.34), true)
		canvas.draw_line(start, finish, ownership_visual_color(Color("4fbd4b")), maxf(2.4, draw_radius * 0.2), true)
		canvas.draw_circle(finish, draw_radius * 0.22, ownership_visual_color(Color("123a25")))
		canvas.draw_circle(finish - direction * draw_radius * 0.03, draw_radius * 0.1, ownership_visual_color(Color("8ceb54")))
	_draw_pea_eye(canvas, head_center, direction, perpendicular, draw_radius, Color("0d2b19"))

func _aim_direction(context: BallRenderContext, head_position: Vector2) -> Vector2:
	var target = context.opponent_for_entity(self)
	if target == null:
		return Vector2.RIGHT if owner_side == 0 else Vector2.LEFT
	var direction: Vector2 = (context.point(target.pos) - head_position).normalized()
	return direction if direction.length_squared() > 0.001 else Vector2.RIGHT

func _draw_back_sepals(
	canvas: CanvasItem,
	center: Vector2,
	direction: Vector2,
	draw_radius: float,
	sepal_color: Color
) -> void:
	var back := -direction
	for offset_angle in [-0.68, 0.0, 0.68]:
		var sepal_direction := back.rotated(float(offset_angle))
		var perpendicular := sepal_direction.rotated(PI * 0.5)
		canvas.draw_colored_polygon(PackedVector2Array([
			center + sepal_direction * draw_radius * 0.34 - perpendicular * draw_radius * 0.19,
			center + sepal_direction * draw_radius * 1.0,
			center + sepal_direction * draw_radius * 0.34 + perpendicular * draw_radius * 0.19,
		]), ownership_visual_color(sepal_color))

func _draw_single_barrel(
	canvas: CanvasItem,
	center: Vector2,
	direction: Vector2,
	draw_radius: float,
	barrel_color: Color,
	mouth_color: Color,
	highlight_color: Color
) -> void:
	var start := center + direction * draw_radius * 0.16
	var finish := center + direction * draw_radius * 1.16
	canvas.draw_line(start, finish, ownership_visual_color(mouth_color), maxf(5.0, draw_radius * 0.54), true)
	canvas.draw_line(start, finish, ownership_visual_color(barrel_color), maxf(3.0, draw_radius * 0.36), true)
	canvas.draw_circle(finish, draw_radius * 0.32, ownership_visual_color(mouth_color))
	canvas.draw_circle(finish - direction * draw_radius * 0.04, draw_radius * 0.17, ownership_visual_color(highlight_color))

func _draw_pea_eye(
	canvas: CanvasItem,
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	draw_radius: float,
	eye_color: Color
) -> void:
	var eye_position := center + direction * draw_radius * 0.08 - perpendicular * draw_radius * 0.3
	canvas.draw_circle(eye_position, draw_radius * 0.13, Color(0.96, 1.0, 0.9, 0.95))
	canvas.draw_circle(eye_position + direction * draw_radius * 0.035, draw_radius * 0.075, eye_color)
	canvas.draw_circle(eye_position - Vector2.ONE * draw_radius * 0.025, draw_radius * 0.022, Color.WHITE)

func _draw_flame_crest(
	canvas: CanvasItem,
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	draw_radius: float,
	elapsed: float
) -> void:
	for flame_index in range(4):
		var side_offset := (float(flame_index) - 1.5) * draw_radius * 0.24
		var root := center - direction * draw_radius * 0.38 + perpendicular * side_offset
		var height := draw_radius * (0.62 + 0.1 * sin(elapsed * 8.0 + float(flame_index)))
		canvas.draw_colored_polygon(PackedVector2Array([
			root - perpendicular * draw_radius * 0.13,
			root - Vector2(0.0, height),
			root + perpendicular * draw_radius * 0.13,
			root - Vector2(0.0, height * 0.24),
		]), ownership_visual_color(Color("ff9a2e" if flame_index % 2 == 0 else "ff4a20")))

func _draw_ice_crown(
	canvas: CanvasItem,
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	draw_radius: float
) -> void:
	for crystal_index in range(4):
		var side_offset := (float(crystal_index) - 1.5) * draw_radius * 0.24
		var root := center - direction * draw_radius * 0.38 + perpendicular * side_offset
		var height := draw_radius * (0.46 + 0.12 * float(crystal_index % 2))
		canvas.draw_colored_polygon(PackedVector2Array([
			root - perpendicular * draw_radius * 0.12,
			root - Vector2(0.0, height),
			root + perpendicular * draw_radius * 0.12,
		]), ownership_visual_color(Color("b9f7ff" if crystal_index % 2 == 0 else "61d7f0")))

func _draw_gatling_helmet(
	canvas: CanvasItem,
	center: Vector2,
	direction: Vector2,
	perpendicular: Vector2,
	draw_radius: float
) -> void:
	var back := center - direction * draw_radius * 0.22
	var helmet := PackedVector2Array([
		back - perpendicular * draw_radius * 0.66 - Vector2(0.0, draw_radius * 0.18),
		back - perpendicular * draw_radius * 0.48 - Vector2(0.0, draw_radius * 0.62),
		back + perpendicular * draw_radius * 0.48 - Vector2(0.0, draw_radius * 0.62),
		back + perpendicular * draw_radius * 0.66 - Vector2(0.0, draw_radius * 0.18),
	])
	canvas.draw_colored_polygon(helmet, ownership_visual_color(Color("205b32")))
	canvas.draw_polyline(helmet, ownership_visual_color(Color("8adb4b")), maxf(1.2, draw_radius * 0.07), true)
	canvas.draw_circle(back - Vector2(0.0, draw_radius * 0.38), draw_radius * 0.09, ownership_visual_color(Color("b8ef55")))

func _draw_health_bar(canvas: CanvasItem, position: Vector2, draw_radius: float, accent: Color) -> void:
	var bar_size := Vector2(draw_radius * 1.9, maxf(2.0, draw_radius * 0.13))
	var bar_position := position + Vector2(-bar_size.x * 0.5, -draw_radius * 1.62)
	var bounds := Rect2(bar_position, bar_size)
	canvas.draw_rect(bounds.grow(1.0), Color(0.01, 0.035, 0.02, 0.9))
	canvas.draw_rect(Rect2(bounds.position, Vector2(bounds.size.x * hp / max_hp, bounds.size.y)), accent)
	canvas.draw_rect(bounds, Color(0.86, 1.0, 0.76, 0.72), false, 1.0)

func can_receive_attack(source_side: int) -> bool:
	return (
		_form != GrowthForm.SEED
		and not removed
		and not is_captured()
		and is_hostile_to(source_side)
	)

func participates_in_entity_collision() -> bool:
	return _form != GrowthForm.SEED and not removed and not is_captured()

func participates_in_fighter_collision() -> bool:
	return _form != GrowthForm.SEED and not removed and not is_captured()

func entity_collision_inverse_mass() -> float:
	return 0.0

func fighter_collision_inverse_mass() -> float:
	# Mature plants stay rooted while the hostile fighter receives the rebound.
	return 0.0

func entity_contact_damage() -> float:
	return float(_config["plant_contact_damage"])

func entity_contact_color() -> Color:
	return ownership_visual_color(_accent_color)

func can_resolve_entity_contact(other: BallEntity) -> bool:
	return (
		participates_in_entity_collision()
		and other != null
		and other.owner_side >= 0
		and other.owner_side != owner_side
		and _entity_contact_timer <= 0.0
	)

func begin_entity_contact(_other: BallEntity) -> void:
	_entity_contact_timer = float(_config["plant_contact_interval"])

func can_resolve_fighter_contact(fighter_side: int) -> bool:
	return (
		participates_in_fighter_collision()
		and fighter_side >= 0
		and fighter_side != owner_side
		and _entity_contact_timer <= 0.0
	)

func begin_fighter_contact(_fighter_side: int) -> void:
	_entity_contact_timer = float(_config["plant_contact_interval"])

func receive_attack(
	battle,
	amount: float,
	source_side: int,
	hit_color: Color
) -> float:
	if not can_receive_attack(source_side) or amount <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp = maxf(0.0, hp - applied)
	_hit_flash = 1.0
	if hp > 0.0:
		battle.spawn_particles(pos, hit_color, 3, 72.0)
		return applied
	removed = true
	battle.record_stat("plant_attachments_destroyed")
	battle.spawn_ring(pos, absorption_visual_color(), radius, 56.0, 0.3)
	battle.spawn_particles(pos, absorption_visual_color(), 10, 125.0)
	battle.emit_combat_event("impact", 0.4)
	return applied

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return ownership_visual_color(_form_color())

func _grow_once(battle) -> void:
	_mature_body()
	_growth_animation_duration = maxf(0.001, float(_config["growth_animation_duration"]))
	_growth_animation_elapsed = 0.0
	_form = _choose_growth_form(battle)
	match _form:
		GrowthForm.SUNFLOWER:
			_action_timer = float(_config["sun_launch_interval"])
			battle.record_stat("plant_sunflowers_grown")
		GrowthForm.PEA_FIRE:
			_action_timer = float(_config["fire_fire_interval"])
			battle.record_stat("plant_fire_peas_grown")
		GrowthForm.PEA_ICE:
			_action_timer = float(_config["ice_fire_interval"])
			battle.record_stat("plant_ice_peas_grown")
		GrowthForm.PEA_GATLING:
			_action_timer = float(_config["gatling_fire_interval"])
			battle.record_stat("plant_gatlings_grown")
	battle.spawn_ring(pos, absorption_visual_color(), radius * 0.65, radius * 3.2, 0.5)
	battle.spawn_particles(pos, absorption_visual_color(), 13, 126.0)
	battle.emit_combat_event("split", 0.48)

func _choose_growth_form(battle) -> GrowthForm:
	var sunflower_weight := maxf(0.0, float(_config["sunflower_growth_weight"]))
	var fire_weight := maxf(0.0, float(_config["fire_pea_growth_weight"]))
	var ice_weight := maxf(0.0, float(_config["ice_pea_growth_weight"]))
	var gatling_weight := maxf(0.0, float(_config["gatling_pea_growth_weight"]))
	var total_weight := sunflower_weight + fire_weight + ice_weight + gatling_weight
	if total_weight <= 0.0:
		sunflower_weight = 3.0
		fire_weight = 1.0
		ice_weight = 1.0
		gatling_weight = 1.0
		total_weight = 6.0
	var roll: float = battle.random_range(0.0, total_weight)
	if roll < sunflower_weight:
		return GrowthForm.SUNFLOWER
	roll -= sunflower_weight
	if roll < fire_weight:
		return GrowthForm.PEA_FIRE
	roll -= fire_weight
	if roll < ice_weight:
		return GrowthForm.PEA_ICE
	return GrowthForm.PEA_GATLING

func _mature_body() -> void:
	max_hp = float(_config["plant_max_hp"])
	hp = max_hp
	radius = float(_config["plant_radius"])

func _current_fire_interval() -> float:
	match _form:
		GrowthForm.PEA_FIRE:
			return float(_config["fire_fire_interval"])
		GrowthForm.PEA_ICE:
			return float(_config["ice_fire_interval"])
	return float(_config["gatling_fire_interval"])

func _current_projectile_kind() -> String:
	match _form:
		GrowthForm.PEA_FIRE:
			return "fire"
		GrowthForm.PEA_ICE:
			return "ice"
	return "pea_gatling"

func _current_projectile_damage() -> float:
	match _form:
		GrowthForm.PEA_FIRE:
			return float(_config["fire_pea_damage"])
		GrowthForm.PEA_ICE:
			return float(_config["ice_pea_damage"])
	return float(_config["gatling_pea_damage"])

func _fire_projectile(battle) -> void:
	var target = battle.opponent_for_side(owner_side)
	if target == null:
		return
	var direction: Vector2 = (target.pos - pos).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT if owner_side == 0 else Vector2.LEFT
	var spread := float(_config["pea_projectile_spread"])
	direction = direction.rotated(battle.random_range(-spread, spread))
	var projectile_radius := float(_config["pea_projectile_radius"])
	var projectile_kind := _current_projectile_kind()
	var projectile_color := ownership_visual_color(_projectile_color(projectile_kind))
	var origin: Vector2 = pos + direction * (
		radius + projectile_radius + float(_config["projectile_spawn_gap"])
	)
	battle.add_entity(PeaProjectileEntity.new(
		owner_side,
		origin,
		direction * float(_config["pea_projectile_speed"]),
		projectile_radius,
		_current_projectile_damage(),
		projectile_color,
		float(_config["pea_projectile_lifetime"]),
		projectile_kind,
		float(_config["ice_slow_multiplier"]),
		float(_config["ice_slow_duration"]),
		float(_config["fire_burn_damage"]),
		float(_config["fire_burn_tick_interval"]),
		float(_config["fire_burn_duration"]),
		float(_config["projectile_boundary_padding"])
	))
	battle.record_stat("projectiles_spawned")
	battle.record_stat("plant_projectiles_fired")
	battle.spawn_particles(origin, projectile_color, 3, 54.0)
	battle.emit_combat_event("volley", 0.28 if projectile_kind == "pea_gatling" else 0.38)

func _launch_sun(battle) -> void:
	var arena_size: Vector2 = battle.arena_size()
	var pickup_radius := float(_config["sun_pickup_radius"])
	var configured_margin := float(_config["sun_pickup_margin"])
	var margin_x := minf(configured_margin, maxf(0.0, arena_size.x * 0.5 - pickup_radius))
	var margin_y := minf(configured_margin, maxf(0.0, arena_size.y * 0.5 - pickup_radius))
	var landing_position := Vector2(
		battle.random_range(pickup_radius + margin_x, arena_size.x - pickup_radius - margin_x),
		battle.random_range(pickup_radius + margin_y, arena_size.y - pickup_radius - margin_y)
	)
	battle.add_entity(SunPickupEntity.new(
		owner_side,
		pos,
		landing_position,
		pickup_radius,
		float(_config["sun_travel_duration"]),
		float(_config["sun_pickup_lifetime"]),
		float(_config["sun_pickup_heal"]),
		float(_config["sun_arc_height"])
	))
	battle.record_stat("plant_sun_pickups_spawned")
	battle.spawn_particles(pos, ownership_visual_color(Color("ffd84d")), 8, 82.0)
	battle.emit_combat_event("track", 0.36)

func _projectile_color(kind: String) -> Color:
	match kind:
		"fire":
			return Color("ff6724")
		"ice":
			return Color("73e9ff")
	return Color("70df49")

func _form_color() -> Color:
	match _form:
		GrowthForm.SEED:
			return Color("80552d")
		GrowthForm.SUNFLOWER:
			return Color("ffc83d")
		GrowthForm.PEA_FIRE:
			return Color("f25c2a")
		GrowthForm.PEA_ICE:
			return Color("65d8ef")
		GrowthForm.PEA_GATLING:
			return Color("45bd50")
	return _body_color
