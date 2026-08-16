extends BallEntity

var _owner
var _ability
var angle := 0.0

func _init(spawn_owner_side: int, owner, owner_ability) -> void:
	owner_side = spawn_owner_side
	_owner = owner
	_ability = owner_ability
	pos = owner.pos
	radius = 31.0
	tags = PackedStringArray(["showcase_carriage"])
	draw_layer = -5

func step(_battle, delta: float) -> void:
	var crown_level: int = _ability.crown_level()
	angle += delta * (1.25 + crown_level * 0.15)
	var orbit_radius: float = 82.0 + crown_level * 11.0
	pos = _owner.pos + Vector2.from_angle(angle) * orbit_radius

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var direction: float = (pos - _owner.pos).angle() + PI * 0.5
	var scale_factor := context.scale_factor
	canvas.draw_set_transform(screen_position(context) + context.shake_offset, direction, Vector2.ONE * scale_factor)
	canvas.draw_rect(Rect2(Vector2(-27.0, -38.0), Vector2(54.0, 76.0)), Color("292d31"))
	canvas.draw_rect(Rect2(Vector2(-22.0, -32.0), Vector2(44.0, 64.0)), Color("70777b"), false, 3.0)
	canvas.draw_rect(Rect2(Vector2(-17.0, -24.0), Vector2(34.0, 20.0)), Color("b8e4ed"))
	canvas.draw_rect(Rect2(Vector2(-19.0, 8.0), Vector2(38.0, 18.0)), Color("8d1523"))
	canvas.draw_circle(Vector2(-20.0, 29.0), 6.0, Color("17191b"))
	canvas.draw_circle(Vector2(20.0, 29.0), 6.0, Color("17191b"))
	canvas.draw_set_transform(context.shake_offset, 0.0, Vector2.ONE)

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return Color("70777b")
