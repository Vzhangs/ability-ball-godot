extends BallEntity

var _owner
var _ability
var angle := 0.0
var _orbit_radius := 0.0
var _orbit_radius_per_level := 0.0
var _orbit_speed := 0.0
var _orbit_speed_per_level := 0.0

func _init(spawn_owner_side: int, owner, owner_ability, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	_owner = owner
	_ability = owner_ability
	pos = owner.pos
	radius = float(config["radius"])
	_orbit_radius = float(config["orbit_radius"])
	_orbit_radius_per_level = float(config["orbit_radius_per_level"])
	_orbit_speed = float(config["orbit_speed"])
	_orbit_speed_per_level = float(config["orbit_speed_per_level"])
	tags = PackedStringArray(["showcase_carriage"])
	draw_layer = -5

func step(_battle, delta: float) -> void:
	var crown_level: int = _ability.crown_level()
	angle += delta * (_orbit_speed + crown_level * _orbit_speed_per_level)
	var orbit_radius: float = _orbit_radius + crown_level * _orbit_radius_per_level
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
