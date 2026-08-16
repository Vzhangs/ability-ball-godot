class_name BallVisual
extends RefCounted

var module: BallModule
var ability: BallAbility

func configure(owner_module: BallModule, owner_ability: BallAbility = null) -> void:
	module = owner_module
	ability = owner_ability

func trail_alpha() -> float:
	return 0.27

func trail_width_multiplier() -> float:
	return 1.0

func draw_underlay(_canvas: CanvasItem, _fighter, _context: Dictionary) -> void:
	pass

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	canvas.draw_circle(position, radius, fighter.color)
	canvas.draw_circle(position, radius, fighter.accent, false, 2.2)
