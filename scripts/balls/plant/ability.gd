extends BallAbility

const GrowthEntity := preload("res://scripts/balls/plant/growth_entity.gd")
const PlantingIconOverlayEntity := preload("res://scripts/balls/plant/planting_icon_overlay_entity.gd")

var _planted_total := 0

func on_battle_started(_battle, fighter, _opponent, _side: int) -> void:
	# Planting is an exact five-second cadence, including the first seed.
	fighter.ability_timer = fighter.cooldown

func planted_total() -> int:
	return _planted_total

func activate(battle, fighter, _opponent, side: int) -> void:
	if battle.count_entities(side, "plant_growth") >= settingi("max_plants"):
		return
	# The seed is planted exactly beneath the moving main ball and remains there.
	var spawn_position: Vector2 = fighter.pos
	var entity: BallEntity = GrowthEntity.new(
		side,
		spawn_position,
		fighter.color,
		fighter.accent,
		module.settings_snapshot()
	)
	battle.add_entity(entity)
	battle.add_entity(PlantingIconOverlayEntity.new(
		side,
		fighter,
		settingf("planting_icon_duration"),
		fighter.color,
		fighter.accent
	))
	_planted_total += 1
	battle.record_stat("plant_seeds_planted")
	battle.spawn_ring(spawn_position, fighter.accent, settingf("seed_radius"), 38.0, 0.35)
	battle.spawn_particles(spawn_position, fighter.color, 7, 72.0)
