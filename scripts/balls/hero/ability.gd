extends BallAbility

const AttributeBubbleEntity := preload("res://scripts/balls/hero/attribute_bubble_entity.gd")
const AttributeIcon := preload("res://scripts/balls/hero/attribute_icon.gd")
const UpgradeBurstEntity := preload("res://scripts/balls/hero/upgrade_burst_entity.gd")
const ATTRIBUTE_TYPES := ["speed", "max_hp", "impact", "regen"]
const PROBABILITY_KEYS := [
	"speed_spawn_probability",
	"max_hp_spawn_probability",
	"impact_spawn_probability",
	"regen_spawn_probability",
]

var _attribute_stacks := {
	"speed": 0,
	"max_hp": 0,
	"impact": 0,
	"regen": 0,
}
var _spawned_bubbles: Array[WeakRef] = []
var _regen_elapsed := 0.0
var _battle_context
var _owner_side := -1
var _owner_fighter_uid := -1

func on_battle_started(battle, fighter, _opponent, side: int) -> void:
	_attribute_stacks = {"speed": 0, "max_hp": 0, "impact": 0, "regen": 0}
	_spawned_bubbles.clear()
	_regen_elapsed = 0.0
	_battle_context = battle
	_owner_side = side
	_owner_fighter_uid = fighter.fighter_uid
	fighter.ability_timer = fighter.cooldown

func automatic_activation_enabled() -> bool:
	return (
		_battle_context != null
		and _owner_side >= 0
		and _active_bubbles().size() < settingi("max_bubbles")
	)

func speed_multiplier(_battle, _fighter, _opponent, _side: int) -> float:
	return 1.0 + float(stack_count("speed")) * settingf("speed_bonus_ratio")

func contact_damage(_battle, _fighter, _opponent) -> float:
	return (
		settingf("initial_impact_damage")
		+ float(stack_count("impact")) * settingf("impact_damage_bonus")
	)

func on_step(battle, fighter, _opponent, _side: int, delta: float) -> void:
	var regen_stacks := stack_count("regen")
	if regen_stacks <= 0:
		return
	var interval := maxf(0.001, settingf("regen_tick_interval"))
	_regen_elapsed += delta
	while _regen_elapsed + 0.000001 >= interval:
		_regen_elapsed -= interval
		var applied: float = battle.heal(
			fighter,
			settingf("regen_per_second") * float(regen_stacks) * interval
		)
		if applied > 0.0:
			battle.record_stat("hero_regen_ticks")

func activate(battle, fighter, _opponent, side: int) -> void:
	if _active_bubbles().size() >= settingi("max_bubbles"):
		return
	var attribute_kind := _roll_attribute(battle)
	var bubble_radius := settingf("bubble_radius")
	var arena_size: Vector2 = battle.arena_size()
	var spawn_position := Vector2(
		battle.random_range(bubble_radius, arena_size.x - bubble_radius),
		battle.random_range(bubble_radius, arena_size.y - bubble_radius)
	)
	var bubble: BallEntity = AttributeBubbleEntity.new(
		side,
		spawn_position,
		bubble_radius,
		attribute_kind,
		self
	)
	# Bind the exact creating fighter so team modes never hand a bubble to an ally.
	bubble.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(bubble)
	_spawned_bubbles.append(weakref(bubble))
	var color := AttributeIcon.color_for(attribute_kind)
	battle.spawn_ring(spawn_position, color, bubble_radius * 0.4, bubble_radius * 2.2, 0.42)
	battle.spawn_particles(spawn_position, color, 7, 82.0)
	battle.record_stat("hero_attribute_bubbles_spawned")
	battle.record_stat("hero_%s_bubbles_spawned" % attribute_kind)

func collect_attribute(
	battle,
	fighter,
	attribute_kind: String,
	pickup_position: Vector2
) -> bool:
	if (
		fighter == null
		or fighter.hp <= 0.0
		or fighter.fighter_uid != _owner_fighter_uid
		or not _attribute_stacks.has(attribute_kind)
	):
		return false
	_attribute_stacks[attribute_kind] = stack_count(attribute_kind) + 1
	if attribute_kind == "max_hp":
		fighter.max_hp += settingf("max_hp_bonus")
	var burst: BallEntity = UpgradeBurstEntity.new(
		_owner_side,
		fighter,
		attribute_kind,
		settingf("pickup_icon_duration")
	)
	burst.owner_fighter_uid = fighter.fighter_uid
	battle.add_entity(burst)
	var color := AttributeIcon.color_for(attribute_kind)
	battle.spawn_ring(pickup_position, color, fighter.radius * 0.45, fighter.radius * 2.8, 0.5)
	battle.spawn_particles(pickup_position, color, 13, 132.0)
	battle.shake_camera(2.4)
	battle.emit_combat_event("judgment", 0.52)
	battle.record_stat("hero_attribute_bubbles_collected")
	battle.record_stat("hero_%s_stacks_collected" % attribute_kind)
	return true

func stack_count(attribute_kind: String) -> int:
	return int(_attribute_stacks.get(attribute_kind, 0))

func total_upgrades() -> int:
	var total := 0
	for attribute_kind: String in ATTRIBUTE_TYPES:
		total += stack_count(attribute_kind)
	return total

func active_bubble_count() -> int:
	return _active_bubbles().size()

func _active_bubbles() -> Array[BallEntity]:
	var result: Array[BallEntity] = []
	for index in range(_spawned_bubbles.size() - 1, -1, -1):
		var bubble: BallEntity = _spawned_bubbles[index].get_ref()
		if bubble == null or bubble.removed:
			_spawned_bubbles.remove_at(index)
			continue
		result.append(bubble)
	return result

func _roll_attribute(battle) -> String:
	var probabilities: Array[float] = []
	var total_probability := 0.0
	for probability_key: String in PROBABILITY_KEYS:
		var probability := maxf(0.0, settingf(probability_key))
		probabilities.append(probability)
		total_probability += probability
	if total_probability <= 0.0001:
		return ATTRIBUTE_TYPES[battle.random_int(0, ATTRIBUTE_TYPES.size() - 1)]
	var selection: float = battle.random_range(0.0, total_probability)
	var cumulative := 0.0
	for index in range(probabilities.size()):
		cumulative += probabilities[index]
		if selection <= cumulative:
			return ATTRIBUTE_TYPES[index]
	return ATTRIBUTE_TYPES.back()
