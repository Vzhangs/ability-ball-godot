extends BallEntity

const Art := preload("res://scripts/balls/steve/material_art.gd")
var _anchor
var _kind := "block"
var _tier := 0
var _duration := 0.0

func _init(owner, kind: String, tier: int, duration: float) -> void:
	_anchor = owner
	owner_side = owner.team_id
	owner_fighter_uid = owner.fighter_uid
	pos = owner.pos
	radius = owner.radius
	_kind = kind
	_tier = tier
	_duration = maxf(0.001, duration)
	remaining = _duration
	draw_layer = 120
	tags = PackedStringArray(["steve_cast_vfx"])

func step(_battle, _delta: float) -> void:
	if _anchor == null or _anchor.hp <= 0.0:
		removed = true
		return
	pos = _anchor.pos

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var pulse := sin(progress * PI)
	if pulse < 0.001:
		return
	var center := screen_position(context)
	var size := radius * context.scale_factor * (0.48 + pulse * 0.72)
	var color := Art.color_for(_tier)
	canvas.draw_circle(center, size * 1.3, Color(color, pulse * 0.13))
	match _kind:
		"sword":
			var direction := Vector2(0.6, -0.8)
			Art.draw_sword(canvas, center - direction * size * 0.55, direction, size * 1.4, size * 0.29, _tier, pulse)
		_:
			Art.draw_block(canvas, center, size * 0.72, _tier, color, pulse)
