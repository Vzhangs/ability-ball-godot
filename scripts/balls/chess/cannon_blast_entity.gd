extends BallEntity

const RAY_COUNT := 18

var _duration := 0.52
var _blast_radius := 78.0
var _body_color := Color("a92120")
var _accent_color := Color("f6d89a")

func _init(
	spawn_owner_side: int,
	spawn_position: Vector2,
	blast_radius: float,
	duration: float,
	body_color: Color,
	accent_color: Color
) -> void:
	owner_side = spawn_owner_side
	pos = spawn_position
	_blast_radius = maxf(4.0, blast_radius)
	radius = _blast_radius
	_duration = maxf(0.05, duration)
	remaining = _duration
	_body_color = body_color
	_accent_color = accent_color
	tags = PackedStringArray(["chess_cannon_blast_vfx"])
	draw_layer = 86

func animation_progress() -> float:
	return clampf(1.0 - remaining / _duration, 0.0, 1.0)

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := animation_progress()
	var eased := 1.0 - pow(1.0 - progress, 2.6)
	var fade := pow(1.0 - progress, 1.45)
	var center := screen_position(context)
	var blast_radius := _blast_radius * context.scale_factor
	var flash := clampf(1.0 - progress / 0.32, 0.0, 1.0)
	canvas.draw_circle(center, blast_radius * (0.22 + eased * 0.66), Color(_body_color.r, _body_color.g, _body_color.b, fade * 0.18))
	canvas.draw_circle(center, blast_radius * (0.09 + eased * 0.34), Color(_accent_color.r, _accent_color.g, _accent_color.b, fade * 0.42))
	canvas.draw_circle(center, blast_radius * maxf(0.025, 0.2 * (1.0 - eased)), Color(1.0, 0.98, 0.84, flash * 0.96))
	for ring_index in range(3):
		var delayed := clampf((progress - float(ring_index) * 0.08) / (1.0 - float(ring_index) * 0.08), 0.0, 1.0)
		var ring_eased := 1.0 - pow(1.0 - delayed, 2.2)
		var ring_fade := pow(1.0 - delayed, 1.55)
		var ring_color := _accent_color.lerp(Color.WHITE, 0.68 - ring_index * 0.17)
		ring_color.a = ring_fade * (0.9 - ring_index * 0.18)
		canvas.draw_arc(
			center,
			blast_radius * (0.12 + ring_eased * (0.9 - ring_index * 0.12)),
			0.0,
			TAU,
			64,
			ring_color,
			maxf(1.4, blast_radius * (0.075 - ring_index * 0.012) * ring_fade),
			true
		)
	for ray_index in range(RAY_COUNT):
		var angle := TAU * float(ray_index) / float(RAY_COUNT) + owner_side * 0.13
		var direction := Vector2.from_angle(angle)
		var inner := center + direction * blast_radius * (0.08 + eased * 0.14)
		var outer := center + direction * blast_radius * (0.34 + eased * (0.46 + float(ray_index % 4) * 0.06))
		var ray_color := _accent_color.lerp(Color.WHITE, 0.72 if ray_index % 3 == 0 else 0.28)
		ray_color.a = fade * (0.72 if ray_index % 3 == 0 else 0.42)
		canvas.draw_line(inner, outer, ray_color, maxf(1.0, blast_radius * 0.024 * fade), true)
