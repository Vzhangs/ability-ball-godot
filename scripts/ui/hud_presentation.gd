extends RefCounted

var health_states: Dictionary = {}
const MAX_SPARKS := 48
var _spark_budget := MAX_SPARKS

func begin_frame() -> void:
	_spark_budget = MAX_SPARKS

func reset() -> void:
	health_states.clear()

func observe(uid: int, hp: float, maximum: float, elapsed: float) -> void:
	var ratio := clampf(hp / maxf(0.001, maximum), 0.0, 1.0)
	if not health_states.has(uid):
		health_states[uid] = {"hp": hp, "maximum": maximum, "ratio": ratio, "from": ratio, "fill_from": ratio, "lost": 0.0, "damage_at": -100.0, "heal_at": -100.0}
		return
	var state: Dictionary = health_states[uid]
	if not is_equal_approx(maximum, float(state.maximum)):
		state.from = ratio
		state.fill_from = ratio
		state.lost = 0.0
		state.damage_at = -100.0
		state.heal_at = -100.0
	elif hp < float(state.hp):
		state.fill_from = float(feedback(uid, elapsed).fill)
		state.lost = maxf(0.0, float(state.ratio) - ratio)
		state.from = maxf(float(feedback(uid, elapsed).trail), float(state.ratio))
		state.damage_at = elapsed
		state.heal_at = -100.0
	elif hp > float(state.hp):
		state.fill_from = float(feedback(uid, elapsed).fill)
		state.lost = 0.0
		state.from = ratio
		state.damage_at = -100.0
		state.heal_at = elapsed
	state.hp = hp
	state.maximum = maximum
	state.ratio = ratio

func feedback(uid: int, elapsed: float) -> Dictionary:
	var state: Dictionary = health_states[uid]
	var age := maxf(0.0, elapsed - float(state.damage_at))
	var change_age := maxf(0.0, elapsed - maxf(float(state.damage_at), float(state.heal_at)))
	return {
		"fill": lerpf(float(state.fill_from), float(state.ratio), smoothstep(0.0, 0.20, change_age)),
		"age": age,
		"lost": state.lost,
		"trail": lerpf(float(state.from), float(state.ratio), smoothstep(0.16, 0.78, age)),
		"damage": 1.0 - smoothstep(0.0, 0.42, age),
		"heal": 1.0 - smoothstep(0.0, 0.65, maxf(0.0, elapsed - float(state.heal_at))),
	}

func health_bar(canvas: CanvasItem, bounds: Rect2, ratio: float, accent: Color, reverse: bool, feedback_state: Dictionary, elapsed: float) -> void:
	var value := clampf(float(feedback_state.fill), 0.0, 1.0)
	var damage := float(feedback_state.damage)
	var heal := float(feedback_state.heal)
	var danger := (0.20 + 0.08 * sin(elapsed * 5.0)) if ratio > 0.0 and ratio <= 0.25 else 0.0
	var tint := accent.lerp(Color("ed7770"), danger).lerp(Color("8be4b7"), heal * 0.4)
	tint = tint.lerp(Color.WHITE, damage * 0.12)
	canvas.draw_rect(bounds, Color(0.24, 0.29, 0.34, 0.26))
	var trail := clampf(float(feedback_state.trail), value, 1.0)
	if trail > value:
		canvas.draw_rect(_fill(bounds, trail, reverse), Color(tint, 0.24))
	if value > 0.0:
		var fill := _fill(bounds, value, reverse)
		canvas.draw_polygon(PackedVector2Array([fill.position, Vector2(fill.end.x, fill.position.y), fill.end, Vector2(fill.position.x, fill.end.y)]), PackedColorArray([
			Color(tint.lightened(0.18), 0.86), Color(tint.lightened(0.08), 0.80),
			Color(tint.darkened(0.24), 0.60), Color(tint.darkened(0.12), 0.66),
		]))
	_draw_sparks(canvas, bounds, value, tint, reverse, feedback_state)

func _draw_sparks(canvas: CanvasItem, bounds: Rect2, ratio: float, tint: Color, reverse: bool, state: Dictionary) -> void:
	var age := float(state.age)
	var lost := float(state.lost)
	if age >= 0.60 or lost < 0.001 or _spark_budget <= 0:
		return
	var compact := bounds.size.y < 12.0
	var count := mini(_spark_budget, 3 if compact else clampi(int(ceil(lost * 24.0)), 3, 9))
	_spark_budget -= count
	var direction := -1.0 if reverse else 1.0
	var edge := bounds.end.x - bounds.size.x * ratio if reverse else bounds.position.x + bounds.size.x * ratio
	for index in range(count):
		var scatter_angle := float(index) * 2.39996
		var origin_x := edge + direction * minf(bounds.size.x * lost, 32.0) * float(index) / float(count)
		var velocity := Vector2(direction * (8.0 + sin(scatter_angle) * 15.0), 10.0 + float(index % 3) * 16.0)
		var point := Vector2(origin_x, bounds.get_center().y) + velocity * age + Vector2(0, 30.0 * age * age)
		# Keep sparks inside the bar's horizontal extent so they cannot reach the values.
		point.x = clampf(point.x, bounds.position.x + 1.0, bounds.end.x - 1.0)
		if compact:
			point.y = clampf(point.y, bounds.position.y, bounds.end.y + 1.0)
		var alpha := (1.0 - age / 0.60) * 0.75
		canvas.draw_line(point, point - velocity.normalized() * (1.4 if compact else 2.6), Color(tint.lightened(0.5), alpha), 1.0, true)

static func _fill(bounds: Rect2, ratio: float, reverse: bool) -> Rect2:
	var width := bounds.size.x * ratio
	return Rect2(Vector2(bounds.end.x - width if reverse else bounds.position.x, bounds.position.y), Vector2(width, bounds.size.y))
