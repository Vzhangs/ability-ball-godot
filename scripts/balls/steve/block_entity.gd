extends BallEntity

const Art := preload("res://scripts/balls/steve/material_art.gd")
const Audio := preload("res://scripts/balls/steve/audio_catalog.gd")
const EPSILON := 0.0001

var hp := 1.0
var max_hp := 1.0
var _tier := 0
var _age := 0.0
var _hit_flash := 0.0
var _hit_sound_remaining := 0.0
var _config: Dictionary
var _ability_ref: WeakRef
var _collector_uid := -1
var _collector_left_spawn := false
var _fighter_contacts: Dictionary = {}
var _entity_contacts: Dictionary = {}
var _pending_wear: Array[Dictionary] = []

func _init(owner, spawn_position: Vector2, tier: int, owner_ability: BallAbility, config: Dictionary) -> void:
	owner_side = owner.team_id
	owner_fighter_uid = owner.fighter_uid
	_collector_uid = owner.fighter_uid
	pos = spawn_position
	_tier = tier
	_config = config.duplicate(true)
	radius = float(config["radius"])
	max_hp = float(config["max_hp"])
	hp = max_hp
	_ability_ref = weakref(owner_ability)
	draw_layer = -3
	tags = PackedStringArray(["steve_block", "steve_block_%s" % Art.IDS[tier]])

func material_tier() -> int:
	return _tier

func is_terrain() -> bool:
	return true

func combat_category() -> Dictionary:
	return {"id": "steve_block_%s" % Art.IDS[_tier], "name": "%s方块" % Art.NAMES[_tier]}

func step(battle, delta: float) -> void:
	_age += delta
	_hit_sound_remaining = maxf(0.0, _hit_sound_remaining - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta * 5.0)
	_apply_pending_wear(battle)
	if removed:
		return
	_refresh_contacts(battle)
	_collect_for_creator(battle)
	if removed:
		return
	for entity: BallEntity in battle.entities():
		_resolve_entity_contact(battle, entity)
	velocity = Vector2.ZERO

func _collect_for_creator(battle) -> void:
	if _ability_ref == null or _collector_uid < 0 or owner_fighter_uid != _collector_uid:
		return
	var owner = battle.fighter_for_uid(_collector_uid)
	if owner == null or owner.hp <= 0.0 or owner.team_id != owner_side:
		return
	var reach: float = owner.radius + radius
	var distance: float = owner.pos.distance_to(pos)
	if _age < float(_config["pickup_delay"]):
		_collector_left_spawn = false
		return
	if not _collector_left_spawn:
		_collector_left_spawn = distance > reach + float(_config["release_margin"])
		return
	if distance > reach:
		return
	var collector = _ability_ref.get_ref()
	if collector != null and bool(collector.call("collect_equipment", battle, owner, _tier)):
		removed = true
		battle.record_stat("steve_blocks_collected")
		battle.spawn_particles(pos, Art.color_for(_tier), 8, 105.0)

func _refresh_contacts(battle) -> void:
	for uid in _fighter_contacts.keys():
		var fighter = battle.fighter_for_uid(int(uid))
		if fighter == null or fighter.hp <= 0.0 or fighter.pos.distance_to(pos) > radius + fighter.radius + float(_config["release_margin"]):
			_fighter_contacts.erase(uid)
	for key in _entity_contacts.keys():
		var other: BallEntity = _entity_contacts[key].get_ref()
		if other == null or other.removed or other.is_captured() or other.pos.distance_to(pos) > radius + other.radius + float(_config["release_margin"]):
			_entity_contacts.erase(key)

func participates_in_fighter_collision() -> bool:
	return not removed and not is_captured()

func fighter_collision_inverse_mass() -> float:
	return 0.0

func can_resolve_fighter_contact(fighter_side: int) -> bool:
	var uid := int(combat_contact_source.get("fighter_uid", -1))
	return participates_in_fighter_collision() and is_hostile_to(fighter_side) and uid >= 0 and not _fighter_contacts.has(uid)

func begin_fighter_contact(fighter_side: int) -> void:
	var uid := int(combat_contact_source.get("fighter_uid", -1))
	_fighter_contacts[uid] = true
	_pending_wear.append({"side": fighter_side, "source": combat_contact_source.duplicate(true)})

func participates_in_entity_collision() -> bool:
	return participates_in_fighter_collision()

func entity_collision_inverse_mass() -> float:
	return 0.0

func entity_contact_damage() -> float:
	return 0.0

func entity_contact_color() -> Color:
	return ownership_visual_color(Art.color_for(_tier))

func can_resolve_entity_contact(other: BallEntity) -> bool:
	return participates_in_entity_collision() and other != null and is_hostile_to(other.owner_side) and not _entity_contacts.has(other.get_instance_id())

func begin_entity_contact(other: BallEntity) -> void:
	_entity_contacts[other.get_instance_id()] = weakref(other)
	_pending_wear.append({"side": other.owner_side, "source": other.combat_identity()})

func _resolve_entity_contact(battle, other: BallEntity) -> void:
	if other == self or not is_hostile_to(other.owner_side) or not other.participates_in_entity_collision():
		return
	var offset := other.pos - pos
	var separation := radius + other.radius
	var distance := offset.length()
	if distance >= separation:
		return
	var normal := offset / distance if distance > EPSILON else Vector2.RIGHT
	if other.entity_collision_inverse_mass() > 0.0:
		other.pos += normal * (separation - distance)
		var closing := other.velocity.dot(normal)
		if closing < 0.0:
			other.velocity -= normal * 2.0 * closing
	if not can_resolve_entity_contact(other) or not other.can_resolve_entity_contact(self):
		return
	begin_entity_contact(other)
	other.begin_entity_contact(self)
	if other.entity_contact_damage() > 0.0:
		battle.damage_entity(self, other.entity_contact_damage(), other.entity_contact_color(), other.owner_side, true, other)

func _apply_pending_wear(battle) -> void:
	var pending := _pending_wear.duplicate()
	_pending_wear.clear()
	for contact: Dictionary in pending:
		if removed:
			return
		battle.damage_entity(self, float(_config["collision_wear"]), Art.color_for(_tier), int(contact["side"]), true, contact["source"])

func can_receive_attack(source_side: int) -> bool:
	return not removed and not is_captured() and is_hostile_to(source_side)

func receive_attack(battle, amount: float, source_side: int, hit_color: Color) -> float:
	if not can_receive_attack(source_side) or amount <= 0.0:
		return 0.0
	var applied := minf(hp, amount)
	hp -= applied
	_hit_flash = 1.0
	if hp <= 0.0:
		removed = true
		battle.record_stat("steve_blocks_destroyed")
		battle.spawn_particles(pos, entity_contact_color(), 11, 116.0)
		battle.emit_combat_event(Audio.block_event("break", _tier), 0.7)
	else:
		battle.spawn_particles(pos, hit_color, 3, 54.0)
		if _hit_sound_remaining <= 0.0:
			battle.emit_combat_event(Audio.block_event("hit", _tier), 0.45)
			_hit_sound_remaining = 0.09
	return applied

func is_absorbable() -> bool:
	return true

func absorption_visual_color() -> Color:
	return entity_contact_color()

func team_marker_world_height() -> float:
	return radius * 1.45

func on_ownership_transferred(_previous_side: int, _new_side: int, _new_anchor) -> void:
	_ability_ref = null
	_collector_uid = -1
	_fighter_contacts.clear()
	_entity_contacts.clear()
	_pending_wear.clear()

func draw(canvas: CanvasItem, context: BallRenderContext) -> void:
	var center := screen_position(context)
	var progress := clampf(_age / maxf(0.001, float(_config["growth_duration"])), 0.0, 1.0)
	var scale := 0.3 + 0.7 * (1.0 - pow(1.0 - progress, 3.0)) + sin(progress * PI) * 0.1
	var half := radius * context.scale_factor * scale
	var color := entity_contact_color().lerp(Color.WHITE, _hit_flash * 0.6)
	Art.draw_block(canvas, center, half, _tier, color, 0.76 if is_captured() else 1.0)
	if is_captured():
		return
	if hp < max_hp:
		var crack := PackedVector2Array([center + Vector2(-0.2, -0.8) * half, center + Vector2(0.10, -0.25) * half, center + Vector2(-0.2, 0.2) * half, center + Vector2(0.25, 0.72) * half])
		canvas.draw_polyline(crack, Color(0.05, 0.035, 0.06, 0.86), maxf(1.0, half * 0.09), true)
	var bar := Rect2(center + Vector2(-half, -half - 5.0), Vector2(half * 2.0, 2.5))
	canvas.draw_rect(bar.grow(1.0), Color(0.015, 0.02, 0.025, 0.9))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / max_hp, bar.size.y)), Art.color_for(_tier).lightened(0.3))
