extends BallEntity

const Paralysis := preload("res://scripts/balls/qing/paralysis_status.gd")
var _first: WeakRef
var _second: WeakRef
var _config: Dictionary
var _age := 0.0
var _cooldowns := {}
var _previous_targets := {}
var _flash := 0.0

func _init(first: BallEntity, second: BallEntity, config: Dictionary) -> void:
	_first = weakref(first)
	_second = weakref(second)
	_config = config.duplicate()
	owner_side = first.owner_side
	owner_fighter_uid = first.owner_fighter_uid
	combat_source = first.combat_identity()
	tags = PackedStringArray(["qing_arc"])
	draw_layer = 2

func connects(first: BallEntity, second: BallEntity) -> bool:
	return (_first.get_ref() == first and _second.get_ref() == second) or (_first.get_ref() == second and _second.get_ref() == first)

func _valid() -> bool:
	var a: BallEntity = _first.get_ref()
	var b: BallEntity = _second.get_ref()
	return a != null and b != null and not a.removed and not b.removed and not a.is_captured() and not b.is_captured() and a.owner_side == owner_side and b.owner_side == owner_side and a.owner_fighter_uid == owner_fighter_uid and b.owner_fighter_uid == owner_fighter_uid

func step(battle, delta: float) -> void:
	if not _valid():
		removed = true
		return
	_age += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	var a: BallEntity = _first.get_ref()
	var b: BallEntity = _second.get_ref()
	pos = (a.pos + b.pos) * 0.5
	if _age < float(_config["arc_charge_time"]) or a.pos.distance_squared_to(b.pos) < 0.0001: return
	var targets: Array = []
	targets.append_array(battle.hostile_fighters(owner_side))
	targets.append_array(battle.damageable_entities(owner_side))
	var active := {}
	for target in targets:
		var id: int = target.get_instance_id()
		active[id] = true
		var before: Vector2 = _previous_targets.get(id, target.pos)
		_previous_targets[id] = target.pos
		_cooldowns[id] = maxf(0.0, float(_cooldowns.get(id, 0.0)) - delta)
		if _distance_segments(before, target.pos, a.pos, b.pos) > target.radius + float(_config["arc_half_width"]): continue
		if float(_cooldowns[id]) > 0.0: continue
		_cooldowns[id] = float(_config["arc_interval"])
		var source = battle.fighter_for_uid(owner_fighter_uid)
		var damage := float(_config["arc_damage"])
		var applied: float
		if target is BallEntity:
			applied = battle.damage_entity(target, damage, absorption_visual_color(), owner_side, true, self)
		else:
			applied = battle.damage(target, damage, absorption_visual_color(), source, true, self)
		if applied > 0.0:
			var status := Paralysis.new(float(_config["paralysis_duration"]), owner_side)
			status.source_fighter_uid = owner_fighter_uid
			status.combat_source = combat_source.duplicate(true)
			battle.apply_status(target, status)
			battle.emit_combat_event("projectile_hit", 0.32)
			battle.record_stat("qing_arc_hits")
			_flash = 1.0
	for id in _previous_targets.keys():
		if not active.has(id):
			_previous_targets.erase(id)
			_cooldowns.erase(id)

func _distance_segments(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null: return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))))

func absorption_visual_color() -> Color:
	var first: BallEntity = _first.get_ref()
	return first.absorption_visual_color() if first != null else Color("75e5ff")

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	if not _valid(): return
	var a: BallEntity = _first.get_ref()
	var b: BallEntity = _second.get_ref()
	var start := context.point(a.pos)
	var end := start.lerp(context.point(b.pos), clampf(_age / float(_config["arc_charge_time"]), 0.0, 1.0))
	if start.distance_squared_to(end) < 0.01: return
	var tangent := (end - start).normalized().orthogonal()
	var points := PackedVector2Array()
	for index in range(13):
		var t := index / 12.0
		var jitter := sin(index * 2.4 + _age * 35.0) * sin(t * PI) * 5.0 * context.scale_factor
		points.append(start.lerp(end, t) + tangent * jitter)
	var color := absorption_visual_color()
	canvas.draw_polyline(points, Color(color, 0.14 + _flash * 0.13), 9.0 * context.scale_factor, true)
	canvas.draw_polyline(points, Color(color, 0.85), 2.5 * context.scale_factor, true)
	canvas.draw_polyline(points, Color(0.93, 1.0, 1.0, 0.95), maxf(0.8, context.scale_factor), true)
