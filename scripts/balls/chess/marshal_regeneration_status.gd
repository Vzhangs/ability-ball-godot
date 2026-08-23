extends BallStatusEffect

const STATUS_KEY := "chess_marshal_regeneration"

var _heal_per_tick := 0.0
var _tick_interval := 1.0
var _tick_remaining := 1.0
var _color := Color("f6d89a")

func _init(
	duration: float,
	effect_source_side: int,
	heal_per_tick: float,
	tick_interval: float,
	color: Color
) -> void:
	key = STATUS_KEY
	remaining = maxf(0.0, duration)
	source_side = effect_source_side
	_heal_per_tick = maxf(0.0, heal_per_tick)
	_tick_interval = maxf(0.001, tick_interval)
	_tick_remaining = _tick_interval
	_color = color

func tick(battle, target, delta: float) -> void:
	var active_delta := minf(maxf(0.0, delta), remaining)
	_tick_remaining -= active_delta
	super(battle, target, delta)
	while _tick_remaining <= 0.0001:
		_tick_remaining += _tick_interval
		var applied: float = battle.heal(target, _heal_per_tick)
		if applied > 0.0:
			battle.spawn_ring(target.pos, _color, target.radius * 0.72, target.radius * 1.5, 0.28)
			battle.spawn_particles(target.pos, _color, 4, 62.0)
			battle.record_stat("chess_marshal_regen_ticks")
		if active_delta <= 0.0:
			break

func draw_overlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	var position: Vector2 = context["position"]
	var radius: float = context["radius"]
	var elapsed: float = context["elapsed"]
	for index in range(3):
		var angle := elapsed * 1.8 + TAU * float(index) / 3.0
		var leaf_position := position + Vector2.from_angle(angle) * radius * 0.78
		canvas.draw_circle(
			leaf_position,
			radius * 0.075,
			Color(_color.r, _color.g, _color.b, 0.62)
		)
