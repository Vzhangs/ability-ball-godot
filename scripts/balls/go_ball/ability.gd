extends BallAbility

const BoardEntity := preload("res://scripts/balls/go_ball/board_entity.gd")
const StoneEntity := preload("res://scripts/balls/go_ball/stone_entity.gd")

const FORM_BLACK := "black"
const FORM_WHITE := "white"
const FORM_BALANCED := "balanced"

var _board: BallEntity
var _next_stone_color := StoneEntity.StoneColor.BLACK
var _black_count := 0
var _white_count := 0

func on_battle_started(battle, fighter, _opponent, side: int) -> void:
	if _board != null and not _board.removed:
		_board.removed = true
	_next_stone_color = StoneEntity.StoneColor.BLACK
	_black_count = 0
	_white_count = 0
	_board = BoardEntity.new(
		side,
		battle.arena_size(),
		settingi("grid_size"),
		fighter.color,
		fighter.accent
	)
	battle.add_entity(_board)
	fighter.ability_timer = fighter.cooldown

func on_step(battle, _fighter, _opponent, _side: int, _delta: float) -> void:
	_refresh_counts(battle)

func activate(battle, fighter, _opponent, side: int) -> void:
	var grid_size := settingi("grid_size")
	var arena_size: Vector2 = battle.arena_size()
	var intersection := _intersection_at(fighter.pos, arena_size, grid_size)
	if _intersection_is_occupied(battle, intersection):
		return
	var line_spacing: Vector2 = arena_size / float(grid_size)
	var stone_radius := minf(line_spacing.x, line_spacing.y) * settingf("stone_radius_ratio")
	var stone := StoneEntity.new(
		side,
		_intersection_position(intersection, line_spacing),
		intersection,
		_next_stone_color,
		stone_radius,
		{
			"max_hp": settingf("stone_max_hp"),
			"collision_wear": settingf("stone_collision_wear"),
			"contact_interval": settingf("stone_contact_interval"),
			"placement_animation_duration": settingf("placement_animation_duration"),
		}
	)
	battle.add_entity(stone)
	battle.spawn_ring(stone.pos, stone.native_color(), stone.radius * 0.3, stone.radius * 2.6, settingf("placement_animation_duration"))
	battle.spawn_particles(stone.pos, stone.native_color(), 6, 64.0)
	battle.record_stat("go_stones_placed")
	_next_stone_color = StoneEntity.StoneColor.WHITE \
		if _next_stone_color == StoneEntity.StoneColor.BLACK \
		else StoneEntity.StoneColor.BLACK
	_refresh_counts(battle)

func contact_damage(battle, _fighter, _target) -> float:
	_refresh_counts(battle)
	if _black_count <= 0 or _black_count < _white_count:
		return 0.0
	return float(_black_count) * settingf("black_damage_per_stone")

func after_contact(battle, fighter, _opponent, _damage_dealt: float) -> void:
	_apply_white_heal(battle, fighter)

func after_entity_contact(
	battle,
	fighter,
	_entity: BallEntity,
	_damage_dealt: float
) -> void:
	_apply_white_heal(battle, fighter)

func form_kind() -> String:
	if _black_count > _white_count:
		return FORM_BLACK
	if _white_count > _black_count:
		return FORM_WHITE
	return FORM_BALANCED

func black_count() -> int:
	return _black_count

func white_count() -> int:
	return _white_count

func next_stone_color() -> int:
	return _next_stone_color

func active_board() -> BallEntity:
	return _board

func _apply_white_heal(battle, fighter) -> void:
	_refresh_counts(battle)
	if _white_count <= 0 or _white_count < _black_count:
		return
	var applied: float = battle.heal(
		fighter,
		float(_white_count) * settingf("white_heal_per_stone")
	)
	if applied > 0.0:
		battle.record_stat("go_white_healing", int(ceil(applied)))

func _refresh_counts(battle) -> void:
	_black_count = 0
	_white_count = 0
	for entity: BallEntity in battle.entities(-1, "go_stone"):
		var color_kind := int(entity.call("stone_color"))
		if color_kind == StoneEntity.StoneColor.BLACK:
			_black_count += 1
		elif color_kind == StoneEntity.StoneColor.WHITE:
			_white_count += 1

func _intersection_is_occupied(battle, intersection: Vector2i) -> bool:
	for entity: BallEntity in battle.entities(-1, "go_stone"):
		if entity.call("board_intersection") == intersection:
			return true
	return false


func _intersection_at(world_position: Vector2, arena_size: Vector2, grid_size: int) -> Vector2i:
	var line_spacing := arena_size / float(grid_size)
	return Vector2i(
		clampi(int(round(world_position.x / line_spacing.x - 0.5)), 0, grid_size - 1),
		clampi(int(round(world_position.y / line_spacing.y - 0.5)), 0, grid_size - 1)
	)


func _intersection_position(intersection: Vector2i, line_spacing: Vector2) -> Vector2:
	return (Vector2(intersection) + Vector2(0.5, 0.5)) * line_spacing
