class_name BurnStatusEffect
extends BallStatusEffect

## Reusable damage-over-time status. Each caller owns and injects its damage,
## cadence, duration, source identity, and color; this class has no ball defaults.

const VISUAL_PULSE_INTERVAL := 0.18
const VISUAL_PARTICLE_COUNT := 2
const VISUAL_PARTICLE_SPEED := 42.0

var _damage_per_tick := 0.0
var _tick_interval := 1.0
var _tick_timer := 1.0
var _effect_color := Color("ff712e")
var _age := 0.0
var _visual_timer := 0.0

func _init(
	duration: float,
	effect_source_side: int,
	tick_damage: float,
	damage_interval: float,
	source_key: String,
	visual_color: Color = Color("ff712e")
) -> void:
	assert(not source_key.is_empty(), "Burn status requires a caller-owned source key")
	key = "burn_%d_%s" % [effect_source_side, source_key.replace(" ", "_")]
	remaining = maxf(0.0, duration)
	source_side = effect_source_side
	_damage_per_tick = maxf(0.0, tick_damage)
	_tick_interval = maxf(0.001, damage_interval)
	_tick_timer = _tick_interval
	_effect_color = visual_color

func damage_per_tick() -> float:
	return _damage_per_tick

func tick_interval() -> float:
	return _tick_interval

func effect_color() -> Color:
	return _effect_color

func tick(battle, target, delta: float) -> void:
	super(battle, target, delta)
	_age += delta
	_visual_timer -= delta
	if _visual_timer <= 0.0:
		_visual_timer += VISUAL_PULSE_INTERVAL
		battle.spawn_particles(
			target.pos,
			_effect_color,
			VISUAL_PARTICLE_COUNT,
			VISUAL_PARTICLE_SPEED
		)
	_tick_timer -= delta
	while _tick_timer <= 0.0:
		_tick_timer += _tick_interval
		var source = battle.fighter_for_side(source_side)
		var applied: float = battle.damage(target, _damage_per_tick, _effect_color, source)
		if applied > 0.0:
			battle.record_stat("burn_damage_ticks")
		if applied <= 0.0 and target.hp <= 0.0:
			break

func refresh_from(other: BallStatusEffect) -> void:
	super(other)
	_damage_per_tick = maxf(_damage_per_tick, float(other.call("damage_per_tick")))
	_tick_interval = minf(_tick_interval, float(other.call("tick_interval")))
	_tick_timer = minf(_tick_timer, _tick_interval)
	_effect_color = other.call("effect_color") as Color

func draw_overlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	# Fire stays attached to the body and always rises. Nothing revolves around it.
	canvas.draw_colored_polygon(PackedVector2Array([
		position + Vector2(-radius * 0.88, radius * 0.38),
		position + Vector2(-radius * 0.58, radius * 0.76),
		position + Vector2(radius * 0.58, radius * 0.76),
		position + Vector2(radius * 0.88, radius * 0.38),
	]), Color(_effect_color.r, _effect_color.g, _effect_color.b, 0.13))
	for flame_index in range(6):
		var horizontal_ratio := -0.72 + float(flame_index) * 0.288
		var base := position + Vector2(
			horizontal_ratio * radius,
			radius * (0.6 - absf(horizontal_ratio) * 0.18)
		)
		var flicker := 0.82 + 0.24 * sin(_age * 10.5 + float(flame_index) * 1.91)
		var flame_height := radius * (0.92 + float(flame_index % 3) * 0.16) * flicker
		var sideways_sway := sin(elapsed * 8.2 + float(flame_index) * 2.17) * radius * 0.12
		var tip := base + Vector2(sideways_sway, -flame_height)
		var flame_width := radius * (0.18 + float(flame_index % 2) * 0.035)
		_draw_flame_tongue(canvas, base, tip, flame_width)

	# Thin rising embers read as sparks instead of orbiting dots.
	for ember_index in range(6):
		var travel := fposmod(
			elapsed * (0.56 + float(ember_index) * 0.035) + float(ember_index) * 0.19,
			1.0
		)
		var ember_x := (float(ember_index) - 2.5) * radius * 0.27
		ember_x += sin(elapsed * 4.7 + float(ember_index) * 1.4) * radius * 0.12
		var ember_position := position + Vector2(
			ember_x,
			radius * 0.5 - travel * radius * 1.85
		)
		var ember_alpha := sin(travel * PI) * 0.82
		var ember_size := maxf(1.0, radius * (0.035 + float(ember_index % 2) * 0.014))
		canvas.draw_colored_polygon(PackedVector2Array([
			ember_position + Vector2(0.0, -ember_size * 1.8),
			ember_position + Vector2(ember_size * 0.55, 0.0),
			ember_position + Vector2(0.0, ember_size * 1.8),
			ember_position + Vector2(-ember_size * 0.55, 0.0),
		]), Color(1.0, 0.72, 0.16, ember_alpha))

func _draw_flame_tongue(
	canvas: CanvasItem,
	base: Vector2,
	tip: Vector2,
	half_width: float
) -> void:
	var height := base.distance_to(tip)
	if height <= 0.001:
		return
	var upward := (tip - base) / height
	var sideways := upward.rotated(PI * 0.5)
	var shoulder := base + upward * height * 0.38
	var outer_color := Color(_effect_color.r, _effect_color.g, _effect_color.b, 0.84)
	canvas.draw_colored_polygon(PackedVector2Array([
		base - sideways * half_width,
		shoulder - sideways * half_width * 0.72,
		tip,
		shoulder + sideways * half_width * 0.5,
		base + sideways * half_width,
	]), outer_color)
	var inner_base := base + upward * height * 0.08
	var inner_tip := base + upward * height * 0.63 + sideways * half_width * 0.12
	var inner_shoulder := inner_base.lerp(inner_tip, 0.42)
	canvas.draw_colored_polygon(PackedVector2Array([
		inner_base - sideways * half_width * 0.45,
		inner_shoulder - sideways * half_width * 0.3,
		inner_tip,
		inner_shoulder + sideways * half_width * 0.25,
		inner_base + sideways * half_width * 0.45,
	]), Color(1.0, 0.78, 0.18, 0.9))
