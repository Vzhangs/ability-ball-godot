extends BallEntity

var _fighter
var _ability_ref: WeakRef

func _init(side: int, fighter, ability: BallAbility) -> void:
	owner_side = side
	owner_fighter_uid = fighter.fighter_uid
	_fighter = fighter
	_ability_ref = weakref(ability)
	pos = fighter.pos
	radius = fighter.radius
	draw_layer = 120
	tags = PackedStringArray(["prism_charge_vfx"])

func step(_battle, _delta: float) -> void:
	var ability = _ability_ref.get_ref()
	if _fighter.hp <= 0.0 or ability == null or not ability.is_charging():
		removed = true
		return
	pos = _fighter.pos

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var ability = _ability_ref.get_ref()
	if removed or _fighter.hp <= 0.0 or ability == null or not ability.is_charging():
		return
	var progress: float = ability.charge_progress()
	var pulse := sin(progress * PI)
	var direction: Vector2 = ability.aim_direction()
	var center := context.point(_fighter.pos + direction * radius * 1.28)
	var size := radius * context.scale_factor * (0.20 + pulse * 0.18)
	var alpha := 0.25 + pulse * 0.70
	canvas.draw_circle(center, size * 1.5, Color(1.0, 0.84, 0.35, alpha * 0.12))
	canvas.draw_circle(center, size * 0.24, Color(1.0, 1.0, 0.91, alpha))
	for index in range(4):
		var ray := Vector2.from_angle(float(index) * PI * 0.5 + direction.angle())
		var outer := center + ray * size * (1.90 - progress * 0.75)
		canvas.draw_line(outer, center + ray * size * 0.35, Color(1.0, 0.96, 0.71, alpha * 0.8), maxf(1.1, size * 0.09), true)
