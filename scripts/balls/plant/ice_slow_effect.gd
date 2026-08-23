extends BallStatusEffect

const SNOWFLAKE_COUNT := 7
const ICE_COLOR := Color("74e8ff")
const ICE_HIGHLIGHT := Color("e9fdff")

var _speed_multiplier := 1.0
var _speed_cap := -1.0
var _age := 0.0

func _init(duration: float, effect_source_side: int, speed_multiplier: float) -> void:
	key = "plant_ice_slow_%d" % effect_source_side
	remaining = duration
	source_side = effect_source_side
	_speed_multiplier = clampf(speed_multiplier, 0.0, 1.0)

func tick(battle, target, delta: float) -> void:
	_age += delta
	# A temporary standstill is not a valid baseline for a percentage slow.
	# Wait for real movement so the effect cannot cache a zero cap and repeatedly
	# erase a lower-priority ability's resume velocity for its whole duration.
	if _speed_cap < 0.0 and target.velocity.length_squared() > 0.001:
		_speed_cap = target.velocity.length() * _speed_multiplier
	if _speed_cap >= 0.0 and target.velocity.length_squared() > 0.001:
		target.velocity = target.velocity.limit_length(_speed_cap)
	super(battle, target, delta)

func refresh_from(other: BallStatusEffect) -> void:
	super(other)
	var refreshed_multiplier: float = float(other.get("_speed_multiplier"))
	_speed_multiplier = minf(_speed_multiplier, refreshed_multiplier)
	_speed_cap = -1.0

func preserves_external_velocity() -> bool:
	return true

func draw_overlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius * 1.03, Color(ICE_COLOR.r, ICE_COLOR.g, ICE_COLOR.b, 0.075))
	canvas.draw_arc(position, radius * 1.08, 0.0, TAU, 36, Color(ICE_COLOR.r, ICE_COLOR.g, ICE_COLOR.b, 0.52), 1.7, true)
	canvas.draw_arc(
		position,
		radius * 1.16,
		_age * 0.72,
		_age * 0.72 + PI * 0.72,
		18,
		Color(ICE_HIGHLIGHT.r, ICE_HIGHLIGHT.g, ICE_HIGHLIGHT.b, 0.7),
		2.1,
		true
	)
	canvas.draw_arc(
		position,
		radius * 1.16,
		_age * 0.72 + PI,
		_age * 0.72 + PI * 1.58,
		14,
		Color(ICE_COLOR.r, ICE_COLOR.g, ICE_COLOR.b, 0.46),
		1.6,
		true
	)
	for snowflake_index in range(SNOWFLAKE_COUNT):
		var travel := fposmod(
			_age * (0.21 + float(snowflake_index % 3) * 0.025)
			+ float(snowflake_index) / float(SNOWFLAKE_COUNT),
			1.0
		)
		var horizontal_slot := -0.9 + float(snowflake_index % 4) * 0.6
		var sideways_drift := sin(
			_age * (1.05 + float(snowflake_index % 2) * 0.22)
			+ float(snowflake_index) * 2.07
		) * 0.22
		var snowflake_position := position + Vector2(
			(horizontal_slot + sideways_drift) * radius,
			lerpf(-1.38, 1.28, travel) * radius
		)
		var snowflake_size := radius * (0.22 + float(snowflake_index % 3) * 0.05)
		var snowflake_alpha := 0.12 + sin(travel * PI) * 0.82
		var rotation := _age * (0.65 + float(snowflake_index % 2) * 0.24) + float(snowflake_index) * 0.71
		_draw_snowflake(
			canvas,
			snowflake_position,
			snowflake_size,
			rotation,
			snowflake_alpha
		)

func _draw_snowflake(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	rotation: float,
	alpha: float
) -> void:
	var glow_color := Color(ICE_COLOR.r, ICE_COLOR.g, ICE_COLOR.b, alpha * 0.3)
	var crystal_color := Color(ICE_HIGHLIGHT.r, ICE_HIGHLIGHT.g, ICE_HIGHLIGHT.b, alpha)
	for arm_index in range(6):
		var direction := Vector2.from_angle(rotation + float(arm_index) * TAU / 6.0)
		var tip := center + direction * size
		var branch_root := center + direction * size * 0.57
		var sideways := direction.rotated(PI * 0.5)
		canvas.draw_line(center, tip, glow_color, maxf(2.2, size * 0.42), true)
		canvas.draw_line(center, tip, crystal_color, maxf(0.9, size * 0.16), true)
		canvas.draw_line(
			branch_root,
			branch_root - direction * size * 0.18 + sideways * size * 0.23,
			crystal_color,
			maxf(0.8, size * 0.13),
			true
		)
		canvas.draw_line(
			branch_root,
			branch_root - direction * size * 0.18 - sideways * size * 0.23,
			crystal_color,
			maxf(0.8, size * 0.13),
			true
		)
	canvas.draw_circle(center, maxf(0.9, size * 0.11), crystal_color)
