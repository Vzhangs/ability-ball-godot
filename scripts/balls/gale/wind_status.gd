extends BallStatusEffect

var _ratio := 1.0
var _age := 0.0

func _init(duration: float, side: int, ratio: float) -> void:
	key = "gale_tailwind" if ratio >= 1.0 else "gale_headwind"
	remaining = duration
	source_side = side
	_ratio = ratio

func fighter_speed_multiplier() -> float:
	return _ratio

func entity_step_multiplier() -> float:
	return _ratio

func refresh_from(other: BallStatusEffect) -> void:
	super(other)
	var ratio := float(other.get("_ratio"))
	_ratio = maxf(_ratio, ratio) if _ratio >= 1.0 else minf(_ratio, ratio)

func tick(battle, target, delta: float) -> void:
	_age += delta
	super(battle, target, delta)

func draw_overlay(canvas: CanvasItem, _target, context: Dictionary) -> void:
	var p: Vector2 = context["position"]
	var r: float = context["radius"]
	var sign := 1.0 if _ratio >= 1.0 else -1.0
	var color := Color("b0ffdf") if sign > 0.0 else Color("b6cbde")
	for index in range(2):
		var shift := fposmod(_age * 2.0 + index * 0.5, 1.0)
		var center := p + Vector2(-r * 1.25, (0.8 - shift * 1.6) * r * sign)
		canvas.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.12, r * 0.12 * sign), center, center + Vector2(r * 0.12, r * 0.12 * sign)]), Color(color, sin(shift * PI) * 0.85), maxf(1.2, r * 0.06), true)
