extends BallEntity

const CURVE_SEGMENTS := 18
const FLOW_BEAD_COUNT := 3
const FLOW_SPEED := 2.8
const WHIP_FREQUENCY := 9.5
const MOUTH_RADIUS_SCALE := 0.92
const MOUTH_SEPARATION_SCALE := 0.34
const MAX_VISIBLE_STRAND_WORLD_LENGTH := 118.0

var _strand_count := 5
var _travel_duration := 0.85
var _strand_stagger := 0.07
var _suction_duration := 0.42
var _attach_time := 1.0
var _damage := 14.0
var _heal_ratio := 1.0
var _color := Color("ff3858")
var _elapsed := 0.0
var _resolved := false

func _init(
	spawn_owner_side: int,
	strand_count: int,
	travel_duration: float,
	strand_stagger: float,
	suction_duration: float,
	drain_damage: float,
	heal_ratio: float,
	color: Color
) -> void:
	owner_side = spawn_owner_side
	_strand_count = maxi(1, strand_count)
	_travel_duration = maxf(0.01, travel_duration)
	_strand_stagger = maxf(0.0, strand_stagger)
	_suction_duration = maxf(0.01, suction_duration)
	_attach_time = _travel_duration + float(_strand_count - 1) * _strand_stagger
	_damage = maxf(0.0, drain_damage)
	_heal_ratio = maxf(0.0, heal_ratio)
	_color = color
	remaining = _attach_time + _suction_duration
	tags = PackedStringArray(["vampire_remote_drain", "vampire_blood_line"])
	draw_layer = 24

func step(battle, delta: float) -> void:
	_elapsed += delta
	var vampire = battle.owner_for_entity(self)
	var victim = battle.opponent_for_entity(self)
	if vampire == null or victim == null or vampire.hp <= 0.0 or victim.hp <= 0.0:
		removed = true
		return
	pos = (vampire.pos + victim.pos) * 0.5
	if _resolved or _elapsed < _attach_time:
		return
	_resolved = true
	var applied: float = battle.damage(victim, _damage, _color, vampire)
	if applied <= 0.0:
		return
	battle.heal(vampire, applied * _heal_ratio, true)
	var direction: Vector2 = (victim.pos - vampire.pos).normalized()
	var mouth_position: Vector2 = vampire.pos + direction * vampire.radius * 1.2
	battle.spawn_ring(mouth_position, _color, 4.0, 54.0, 0.3)
	battle.spawn_particles(mouth_position, _color, _strand_count * 2, 86.0)
	battle.record_stat("vampire_remote_drains")
	battle.shake_camera(2.6)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var vampire = context.owner_for_entity(self)
	var victim = context.opponent_for_entity(self)
	if vampire == null or victim == null:
		return
	var direction: Vector2 = vampire.pos - victim.pos
	if direction.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var tangent := Vector2(-direction.y, direction.x)
	var suction_progress := clampf(
		(_elapsed - _attach_time) / _suction_duration,
		0.0,
		1.0
	)
	for strand_index in range(_strand_count):
		var delay := float(strand_index) * _strand_stagger
		var growth := clampf((_elapsed - delay) / _travel_duration, 0.0, 1.0)
		if growth <= 0.0:
			continue
		var source_angle := TAU * float(strand_index) / float(_strand_count) + 0.38
		var source: Vector2 = victim.pos + Vector2.from_angle(source_angle) * victim.radius * 0.68
		var mouth_side := -1.0 if strand_index % 2 == 0 else 1.0
		var mouth_offset: float = mouth_side * MOUTH_SEPARATION_SCALE
		var target: Vector2 = (
			vampire.pos
			- direction * vampire.radius * MOUTH_RADIUS_SCALE
			+ tangent * vampire.radius * mouth_offset
		)
		var bend_sign := -1.0 if strand_index % 2 == 0 else 1.0
		var strand_distance := source.distance_to(target)
		var whip := sin(context.elapsed * WHIP_FREQUENCY + float(strand_index) * 1.73)
		var control: Vector2 = (
			(source + target) * 0.5
			+ tangent * strand_distance * (0.105 * bend_sign + 0.065 * whip)
		)
		var end_t := 1.0 if _elapsed >= _attach_time else growth
		var visible_t_span := minf(1.0, MAX_VISIBLE_STRAND_WORLD_LENGTH / maxf(strand_distance, 0.001))
		var moving_tail_t := maxf(0.0, end_t - visible_t_span)
		var start_t := maxf(suction_progress, moving_tail_t) if _elapsed >= _attach_time else moving_tail_t
		var points := _curve_points(context, source, control, target, start_t, end_t)
		if points.size() < 2:
			continue
		var line_pulse := 1.0 + 0.24 * sin(context.elapsed * 17.0 + float(strand_index) * 0.9)
		var alpha := (1.0 - suction_progress * 0.78) * (0.8 + 0.16 * sin(context.elapsed * 13.0 + float(strand_index)))
		canvas.draw_polyline(points, Color(_color.r, 0.0, 0.08, alpha * 0.3), maxf(5.0, 9.5 * line_pulse * context.scale_factor), true)
		canvas.draw_polyline(points, Color(1.0, _color.g, _color.b, alpha), maxf(1.6, 2.8 * line_pulse * context.scale_factor), true)
		for bead_index in range(FLOW_BEAD_COUNT):
			var bead_progress := fmod(
				context.elapsed * FLOW_SPEED
				+ float(strand_index) * 0.17
				+ float(bead_index) / float(FLOW_BEAD_COUNT),
				1.0
			)
			var bead_t := lerpf(start_t, end_t, bead_progress)
			var bead_world := _quadratic(source, control, target, bead_t)
			var bead_position := context.point(bead_world)
			var bead_radius := maxf(1.8, (2.7 + float(bead_index) * 0.35) * context.scale_factor)
			canvas.draw_circle(bead_position, bead_radius * 2.0, Color(_color.r, 0.0, 0.08, alpha * 0.2))
			canvas.draw_circle(bead_position, bead_radius, Color(1.0, 0.36, 0.46, alpha))
		if _elapsed < _attach_time:
			var leading_world := _quadratic(source, control, target, end_t)
			canvas.draw_circle(context.point(leading_world), maxf(2.2, 3.5 * context.scale_factor), Color("ffafba"))

func _curve_points(
	context: BallRenderContext,
	start: Vector2,
	control: Vector2,
	finish: Vector2,
	start_t: float,
	end_t: float
) -> PackedVector2Array:
	var points := PackedVector2Array()
	if end_t <= start_t:
		return points
	for segment_index in range(CURVE_SEGMENTS + 1):
		var progress := float(segment_index) / float(CURVE_SEGMENTS)
		var curve_t := lerpf(start_t, end_t, progress)
		points.append(context.point(_quadratic(start, control, finish, curve_t)))
	return points

func _quadratic(start: Vector2, control: Vector2, finish: Vector2, progress: float) -> Vector2:
	var inverse := 1.0 - progress
	return start * inverse * inverse + control * 2.0 * inverse * progress + finish * progress * progress
