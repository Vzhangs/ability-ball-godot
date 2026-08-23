extends BallAbility

const GridEntity := preload("res://scripts/balls/wdc/grid_entity.gd")
const CastIconEntity := preload("res://scripts/balls/wdc/cast_icon_entity.gd")
const TEMPLATE_DAMAGE_MAX := 50
const DAMAGE_BANDS := [
	Vector2i(0, 10),
	Vector2i(11, 20),
	Vector2i(21, 30),
	Vector2i(31, 40),
	Vector2i(41, 50),
]
const WEIGHT_KEYS := [
	"weight_0_10",
	"weight_11_20",
	"weight_21_30",
	"weight_31_40",
	"weight_41_50",
]

var _active_grid: BallEntity

func activate(battle, fighter, _opponent, side: int) -> void:
	if _active_grid != null and not _active_grid.removed:
		_active_grid.removed = true
	var cell_values: Array[int] = []
	for _cell_index in range(9):
		cell_values.append(_roll_damage(battle))
	_active_grid = GridEntity.new(
		side,
		battle.arena_size(),
		cell_values,
		settingf("skill_duration"),
		settingf("grid_fade_duration"),
		settingi("damage_max"),
		fighter.color,
		fighter.accent
	)
	battle.add_entity(_active_grid)
	battle.add_entity(CastIconEntity.new(
		side,
		fighter,
		settingf("cast_icon_duration"),
		fighter.color,
		fighter.accent
	))
	battle.spawn_ring(fighter.pos, fighter.accent, fighter.radius * 0.9, fighter.radius * 3.4, 0.58)
	battle.spawn_particles(fighter.pos, fighter.accent, 18, 155.0)
	battle.record_stat("wdc_grid_casts")

func contact_damage(_battle, fighter, target) -> float:
	if not is_grid_active() or target == null:
		return 0.0
	var contact_point := _contact_point(fighter, target)
	return float(_active_grid.call("damage_at", contact_point))

func is_grid_active() -> bool:
	return _active_grid != null and not _active_grid.removed and _active_grid.remaining > 0.0

func active_grid() -> BallEntity:
	return _active_grid

func current_values() -> Array[int]:
	if not is_grid_active():
		return []
	var snapshot: Array[int] = _active_grid.call("values_snapshot")
	return snapshot

func _contact_point(fighter, target) -> Vector2:
	var combined_radius := maxf(0.001, float(fighter.radius) + float(target.radius))
	return (
		Vector2(fighter.pos) * float(target.radius)
		+ Vector2(target.pos) * float(fighter.radius)
	) / combined_radius

func _roll_damage(battle) -> int:
	var weights: Array[float] = []
	var total_weight := 0.0
	for key: String in WEIGHT_KEYS:
		var weight := maxf(0.0, settingf(key))
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0.0001:
		weights.fill(1.0)
		total_weight = float(weights.size())
	var selection: float = battle.random_range(0.0, total_weight)
	var selected_band := weights.size() - 1
	var cumulative := 0.0
	for index in range(weights.size()):
		cumulative += weights[index]
		if selection <= cumulative:
			selected_band = index
			break
	var band: Vector2i = DAMAGE_BANDS[selected_band]
	var template_damage: int = battle.random_int(band.x, band.y)
	return int(round(
		float(template_damage) / float(TEMPLATE_DAMAGE_MAX)
		* float(settingi("damage_max"))
	))
