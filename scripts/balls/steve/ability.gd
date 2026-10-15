extends BallAbility

const Art := preload("res://scripts/balls/steve/material_art.gd")
const Audio := preload("res://scripts/balls/steve/audio_catalog.gd")
const Block := preload("res://scripts/balls/steve/block_entity.gd")
const Armor := preload("res://scripts/balls/steve/armor_effect.gd")
const CastIcon := preload("res://scripts/balls/steve/cast_icon_entity.gd")

var _sword_tier := -1
var _armor_tier := -1
var _next_slot := 0
var _owner_uid := -1
var _battle_context
var _armor_effect: BallStatusEffect
var _sword_direction := Vector2.RIGHT
var _fighter_touches: Dictionary = {}
var _entity_touches: Dictionary = {}

func on_battle_started(battle, fighter, opponent, side: int) -> void:
	_battle_context = battle
	_owner_uid = fighter.fighter_uid
	_sword_tier = -1
	_armor_tier = -1
	_next_slot = 0
	_fighter_touches.clear()
	_entity_touches.clear()
	_armor_effect = Armor.new(side)
	battle.apply_status(fighter, _armor_effect)
	fighter.ability_timer = fighter.cooldown
	_aim(fighter, opponent)

func automatic_activation_enabled() -> bool:
	if _battle_context == null:
		return true
	var fighter = _battle_context.fighter_for_uid(_owner_uid)
	return fighter != null and fighter.hp > 0.0 and _owned_blocks(_battle_context).size() < settingi("maximum_blocks") and _can_place_at_feet(_battle_context, fighter)

func activate(battle, fighter, _opponent, _side: int) -> void:
	if _owned_blocks(battle).size() >= settingi("maximum_blocks") or not _can_place_at_feet(battle, fighter):
		return
	var block_radius := settingf("block_radius")
	var tier := roll_material_tier(battle)
	var material_id: String = Art.IDS[tier]
	var block: BallEntity = Block.new(fighter, fighter.pos, tier, self, {
		"radius": block_radius, "max_hp": settingf(material_id + "_block_durability"),
		"collision_wear": settingf("block_collision_wear"),
		"release_margin": settingf("contact_release_margin"),
		"growth_duration": settingf("block_growth_duration"),
		"pickup_delay": settingf("block_pickup_delay"),
	})
	battle.add_entity(block)
	battle.add_entity(CastIcon.new(fighter, "block", tier, settingf("cast_icon_duration")))
	battle.record_stat("steve_blocks_placed")
	battle.emit_combat_event(Audio.block_event("place", tier), 0.7)

func _can_place_at_feet(battle, fighter) -> bool:
	var block_radius := settingf("block_radius")
	var largest_body: float = fighter.radius
	for body in battle.active_fighters():
		largest_body = maxf(largest_body, body.radius)
	var clearance := block_radius + largest_body * 2.0 + settingf("contact_release_margin")
	var arena: Vector2 = battle.arena_size()
	if fighter.pos.x < clearance or fighter.pos.x > arena.x - clearance or fighter.pos.y < clearance or fighter.pos.y > arena.y - clearance:
		return false
	for existing: BallEntity in battle.entities(-1, "steve_block"):
		if not existing.is_captured() and existing.pos.distance_to(fighter.pos) < existing.radius + block_radius:
			return false
	return true

func roll_material_tier(battle) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for material_id: String in Art.IDS:
		var weight := settingf(material_id + "_spawn_weight")
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return 0
	var roll: float = battle.random_float() * total
	for tier in range(weights.size()):
		if roll < weights[tier]:
			return tier
		roll -= weights[tier]
	for tier in range(weights.size() - 1, -1, -1):
		if weights[tier] > 0.0:
			return tier
	return 0

func _owned_blocks(battle) -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for block: BallEntity in battle.entities(-1, "steve_block"):
		if block.owner_fighter_uid == _owner_uid and not block.is_captured():
			result.append(block)
	return result

func collect_equipment(battle, fighter, tier: int) -> bool:
	if fighter == null or fighter.hp <= 0.0 or fighter.fighter_uid != _owner_uid or tier < 0 or tier >= Art.IDS.size():
		return false
	var slot := _next_slot
	if _sword_tier < 0 and _armor_tier < 0:
		slot = 0 if battle.random_float() < settingf("first_sword_probability") else 1
	elif _sword_tier < 0:
		slot = 0
	elif _armor_tier < 0:
		slot = 1
	_next_slot = 1 - slot
	var previous := _sword_tier if slot == 0 else _armor_tier
	if tier <= previous:
		battle.emit_combat_event("steve_pickup", 0.4)
		return true
	var kind := "sword" if slot == 0 else "armor"
	if slot == 0:
		_sword_tier = tier
	else:
		_armor_tier = tier
		_armor_effect.set("reduction", settingf(String(Art.IDS[tier]) + "_armor_reduction") * 0.01)
	if slot == 0:
		battle.add_entity(CastIcon.new(fighter, kind, tier, settingf("cast_icon_duration")))
		battle.spawn_ring(fighter.pos, Art.color_for(tier), fighter.radius * 0.7, fighter.radius * 2.1, 0.32)
	battle.emit_combat_event("steve_upgrade" if slot == 0 else Audio.armor_event(tier), 0.7)
	battle.record_stat("steve_%s_upgrades" % kind)
	return true

func on_step(battle, fighter, opponent, side: int, _delta: float) -> void:
	_aim(fighter, opponent)
	if _sword_tier < 0:
		return
	var start: Vector2 = fighter.pos + _sword_direction * fighter.radius
	var finish := start + _sword_direction * settingf("sword_length")
	var width := settingf("sword_width") * 0.5
	var damage := settingf(String(Art.IDS[_sword_tier]) + "_sword_damage")
	var fighter_touches: Dictionary = {}
	var entity_touches: Dictionary = {}
	var hit_count := 0
	for target in battle.hostile_fighters(side):
		var margin := settingf("contact_release_margin") if _fighter_touches.has(target.fighter_uid) else 0.0
		if Geometry2D.get_closest_point_to_segment(target.pos, start, finish).distance_to(target.pos) > target.radius + width + margin:
			continue
		fighter_touches[target.fighter_uid] = true
		if not _fighter_touches.has(target.fighter_uid) and battle.damage(target, damage, Art.color_for(_sword_tier), fighter) > 0.0:
			hit_count += 1
	for entity: BallEntity in battle.damageable_entities(side):
		var key := entity.get_instance_id()
		var margin := settingf("contact_release_margin") if _entity_touches.has(key) else 0.0
		if Geometry2D.get_closest_point_to_segment(entity.pos, start, finish).distance_to(entity.pos) > entity.radius + width + margin:
			continue
		entity_touches[key] = true
		if not _entity_touches.has(key) and battle.damage_entity(entity, damage, Art.color_for(_sword_tier), side, true, fighter) > 0.0:
			hit_count += 1
	_fighter_touches = fighter_touches
	_entity_touches = entity_touches
	if hit_count > 0:
		battle.emit_combat_event("steve_sword_light" if _sword_tier < 2 else "steve_sword_heavy", 0.65)
		battle.spawn_particles(finish, Art.color_for(_sword_tier), 6, 110.0)
		battle.record_stat("steve_sword_hits", hit_count)

func _aim(fighter, opponent) -> void:
	if opponent != null and fighter.pos.distance_squared_to(opponent.pos) > 0.0001:
		_sword_direction = (opponent.pos - fighter.pos).normalized()
	elif fighter.velocity.length_squared() > 0.0001:
		_sword_direction = fighter.velocity.normalized()

func sword_tier() -> int:
	return _sword_tier

func armor_tier() -> int:
	return _armor_tier

func sword_direction() -> Vector2:
	return _sword_direction
