extends BallEntity

const UnlimitedVoidStatus := preload("res://scripts/balls/gojo/unlimited_void_status.gd")

var _source
var _domain_radius := 280.0
var _damage_per_tick := 2.0
var _tick_interval := 0.5
var _duration := 3.0
var _affected_targets: Dictionary = {}

func _init(spawn_owner_side: int, source, config: Dictionary) -> void:
	owner_side = spawn_owner_side
	owner_fighter_uid = source.fighter_uid
	_source = source
	pos = source.pos
	_domain_radius = maxf(1.0, float(config.get("radius", 280.0)))
	radius = _domain_radius
	_duration = maxf(0.05, float(config.get("duration", 3.0)))
	remaining = _duration
	_damage_per_tick = maxf(0.0, float(config.get("damage_per_tick", 2.0)))
	_tick_interval = maxf(0.05, float(config.get("tick_interval", 0.5)))
	tags = PackedStringArray(["gojo_unlimited_void"])
	draw_layer = -80

func step(battle, _delta: float) -> void:
	if _source == null or _source.hp <= 0.0:
		removed = true
		return
	_apply_domain(battle)

func affected_target_count() -> int:
	return _affected_targets.size()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var draw_radius := _domain_radius * context.scale_factor
	var progress := clampf(1.0 - remaining / _duration, 0.0, 1.0)
	var envelope := minf(1.0, progress * 7.0) * minf(1.0, remaining * 5.0)
	canvas.draw_circle(center, draw_radius, Color(0.015, 0.01, 0.07, 0.78 * envelope))
	canvas.draw_circle(center, draw_radius * 0.98, Color(0.12, 0.05, 0.28, 0.34 * envelope), false, 4.0, true)
	for index in range(34):
		var angle := float(index) * 2.399963 + context.elapsed * (0.05 + float(index % 3) * 0.02)
		var distance := draw_radius * (0.12 + 0.82 * fmod(float(index) * 0.6180339, 1.0))
		var star := center + Vector2.from_angle(angle) * distance
		var star_size := 1.0 + float(index % 4) * 0.55
		canvas.draw_circle(star, star_size, Color(0.65, 0.82, 1.0, (0.45 + float(index % 3) * 0.16) * envelope))
	for ring_index in range(4):
		var ring_radius := draw_radius * (0.23 + float(ring_index) * 0.18)
		var start := context.elapsed * (0.18 + float(ring_index) * 0.04) + float(ring_index)
		canvas.draw_arc(center, ring_radius, start, start + PI * 1.32, 64, Color(0.46, 0.32, 1.0, 0.24 * envelope), 1.5, true)

func _apply_domain(battle) -> void:
	for fighter in battle.hostile_fighters(owner_side):
		if _inside(fighter.pos, fighter.radius):
			_apply_status(battle, fighter, "fighter:%d" % int(fighter.fighter_uid))
	for entity: BallEntity in battle.entities():
		if entity == self or entity.removed or entity.is_captured() or not entity.is_hostile_to(owner_side):
			continue
		if not entity.has_tag("projectile") and not entity.can_receive_attack(owner_side) \
				and not (entity.participates_in_fighter_collision() or entity.participates_in_entity_collision() or entity.team_marker_world_height() > 0.0):
			continue
		if _inside(entity.pos, entity.radius):
			_apply_status(battle, entity, "entity:%d" % entity.get_instance_id())

func _apply_status(battle, target, target_key: String) -> void:
	var effect: BallStatusEffect = UnlimitedVoidStatus.new(
		_source, remaining, _damage_per_tick, _tick_interval, target.velocity
	)
	battle.apply_status(target, effect)
	if _affected_targets.has(target_key):
		return
	_affected_targets[target_key] = true
	battle.spawn_ring(target.pos, Color("8e6dff"), 3.0, target.radius * 1.8, 0.32)
	battle.record_stat("gojo_unlimited_void_targets")

func _inside(target_position: Vector2, target_radius: float) -> bool:
	var threshold := _domain_radius + maxf(0.0, target_radius)
	return target_position.distance_squared_to(pos) <= threshold * threshold
