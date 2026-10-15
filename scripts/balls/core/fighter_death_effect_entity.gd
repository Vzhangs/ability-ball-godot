class_name FighterDeathEffectEntity
extends BallEntity

## Universal main-fighter death presentation. It owns no combat behavior and
## derives animation time from the shared entity lifetime. The effect stays
## below active fighters so a relay replacement or a nearby survivor can never
## be visually mistaken for another defeated fighter.

const SHARD_COUNT := 18
const RING_COUNT := 3
const Glow := preload("res://scripts/balls/core/combat_glow.gd")

var _duration := 1.2
var _body_color := Color.WHITE
var _accent_color := Color.WHITE
var _source_radius := 27.0

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	spawn_radius: float,
	body_color: Color,
	accent_color: Color,
	duration: float
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	radius = maxf(1.0, spawn_radius)
	_source_radius = radius
	_body_color = body_color
	_accent_color = accent_color
	_duration = maxf(0.05, duration)
	remaining = _duration
	tags = PackedStringArray(["fighter_death_vfx"])
	draw_layer = 0

func animation_progress() -> float:
	return clampf(1.0 - remaining / _duration, 0.0, 1.0)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := animation_progress()
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var fade := pow(1.0 - progress, 1.35)
	var center := screen_position(context)
	var source_radius := _source_radius * context.scale_factor
	var flash := clampf(1.0 - progress / 0.24, 0.0, 1.0)
	Glow.halo(canvas, center, source_radius * (3.0 + eased * 2.0), Color(_accent_color, fade * 0.48))
	if flash > 0.0:
		canvas.draw_circle(center, source_radius * (1.5 + eased * 0.45), Color(1.0, 1.0, 1.0, flash * 0.18))
		canvas.draw_circle(center, source_radius * (0.92 - eased * 0.28), Color(1.0, 1.0, 1.0, flash * 0.92))
	for ring_index in range(RING_COUNT):
		var offset := float(ring_index) * 0.12
		var ring_progress := clampf((progress - offset) / maxf(0.01, 1.0 - offset), 0.0, 1.0)
		if ring_progress <= 0.0:
			continue
		var ring_eased := 1.0 - pow(1.0 - ring_progress, 2.4)
		var ring_alpha := pow(1.0 - ring_progress, 1.7)
		var ring_color := _accent_color.lerp(Color.WHITE, 0.34 + ring_index * 0.12)
		ring_color.a = ring_alpha * (0.72 - ring_index * 0.12)
		canvas.draw_arc(
			center,
			source_radius * (0.72 + ring_eased * (2.7 + ring_index * 0.42)),
			0.0,
			TAU,
			64,
			ring_color,
			maxf(1.5, source_radius * (0.12 - ring_index * 0.02) * (1.0 - ring_progress)),
			true
		)
	for shard_index in range(SHARD_COUNT):
		_draw_shard(canvas, center, source_radius, shard_index, eased, fade)
	for spark_index in range(28):
		var angle := float(spark_index) * 2.399963 + owner_side * 0.137
		var direction := Vector2.from_angle(angle)
		var reach := source_radius * (0.4 + eased * (2.0 + float(spark_index % 7) * 0.46))
		var point := center + direction * reach
		var spark_color := Color(_accent_color.lerp(Color.WHITE, 0.65), fade * 0.85)
		Glow.halo(canvas, point, source_radius * 0.28, Color(spark_color, fade * 0.28))
		canvas.draw_line(point - direction * source_radius * 0.18 * fade, point, spark_color, maxf(0.7, source_radius * 0.045 * fade), true)
	var core_color := _accent_color.lerp(Color.WHITE, 0.58)
	core_color.a = fade * 0.6
	canvas.draw_circle(center, source_radius * maxf(0.04, 0.48 * (1.0 - eased)), core_color)

func _draw_shard(
	canvas: CanvasItem,
	center: Vector2,
	source_radius: float,
	shard_index: int,
	eased: float,
	fade: float
) -> void:
	var angle := TAU * float(shard_index) / float(SHARD_COUNT) + owner_side * 0.137
	var direction := Vector2.from_angle(angle)
	var tangent := direction.orthogonal()
	var lane := 0.82 + float(shard_index % 5) * 0.09
	var distance := source_radius * (0.38 + eased * (2.15 + lane))
	var shard_length := source_radius * (0.78 - eased * 0.43) * (0.78 + float(shard_index % 3) * 0.12)
	var shard_width := source_radius * (0.22 - eased * 0.11)
	var tip := center + direction * distance
	var polygon := PackedVector2Array([
		tip + direction * shard_length * 0.56,
		tip - direction * shard_length * 0.44 + tangent * shard_width,
		tip - direction * shard_length * 0.31 - tangent * shard_width * 0.82,
	])
	var shard_color := _accent_color if shard_index % 3 != 0 else _body_color
	shard_color = shard_color.lerp(Color.WHITE, 0.22 if shard_index % 4 != 0 else 0.58)
	shard_color.a = fade * (0.62 + float(shard_index % 4) * 0.08)
	canvas.draw_colored_polygon(polygon, shard_color)
	var streak_color := _accent_color.lerp(Color.WHITE, 0.72)
	streak_color.a = fade * 0.38
	canvas.draw_line(
		center + direction * source_radius * (0.46 + eased * 0.38),
		tip - direction * shard_length * 0.28,
		streak_color,
		maxf(1.0, source_radius * 0.055 * (1.0 - eased * 0.5)),
		true
	)
