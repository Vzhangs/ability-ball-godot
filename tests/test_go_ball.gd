extends SceneTree

const BattleSimulationScript := preload("res://scripts/simulation/battle_simulation.gd")
const BoardEntityScript := preload("res://scripts/balls/go_ball/board_entity.gd")
const StoneEntityScript := preload("res://scripts/balls/go_ball/stone_entity.gd")

var failures: Array[String] = []

class ContactFixture extends BallEntity:
	var hp := 20.0
	var _ready := true

	func _init(spawn_owner_side: int, spawn_position: Vector2) -> void:
		owner_side = spawn_owner_side
		pos = spawn_position
		radius = 8.0
		tags = PackedStringArray(["go_test_fixture"])

	func participates_in_entity_collision() -> bool:
		return not removed

	func entity_collision_inverse_mass() -> float:
		return 1.0

	func can_resolve_entity_contact(other: BallEntity) -> bool:
		return _ready and other != null and is_hostile_to(other.owner_side)

	func begin_entity_contact(_other: BallEntity) -> void:
		_ready = false

	func can_receive_attack(source_side: int) -> bool:
		return not removed and is_hostile_to(source_side)

	func receive_attack(
		_battle,
		amount: float,
		source_side: int,
		_hit_color: Color
	) -> float:
		if not can_receive_attack(source_side):
			return 0.0
		var applied := minf(hp, maxf(0.0, amount))
		hp -= applied
		return applied

func _init() -> void:
	_check_module_contract()
	_check_persistent_settings_isolation()
	_check_rectangular_board_and_alternating_placement()
	_check_black_white_and_balanced_contact_rules()
	_check_stone_fighter_collision_wear()
	_check_stone_entity_collision_attack_capture_and_transfer()
	_check_owner_cleanup_and_determinism()
	BallRegistry.configure_settings({})
	if failures.is_empty():
		print("ABILITY_BALL_GO_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		print("ABILITY_BALL_GO_TESTS_FAILED count=", failures.size())
		quit(1)

func _check_module_contract() -> void:
	BallRegistry.configure_settings({})
	var module: BallModule = BallRegistry.get_module("go_ball")
	_check(BallRegistry.validation_errors().is_empty(), "围棋球注册后完整球库 Schema 校验通过")
	_check(module != null and module.display_name == "围棋球", "围棋球由注册表自动发现")
	_check(is_equal_approx(module.max_hp, 100.0), "围棋球默认生命值为 100")
	_check(is_equal_approx(module.cooldown, 2.0), "围棋球默认每 2 秒落子")
	_check(module.settingi("grid_size") == 10, "围棋球默认棋盘为横纵各 10 个交叉点")
	_check(is_equal_approx(module.settingf("stone_max_hp"), 10.0), "棋子默认生命值为 10")
	_check(is_equal_approx(module.settingf("stone_collision_wear"), 3.0), "棋子每次受撞默认损耗 3")
	var ability: BallAbility = module.create_ability()
	_check(ability.automatic_activation_enabled(), "围棋球按通用自动技能节奏落子")
	_check(module.create_visual(ability) is BallVisual, "围棋球装载独立黑白形态视觉")

func _check_persistent_settings_isolation() -> void:
	BallRegistry.configure_settings({
		"go_ball": {
			"max_hp": 180.0,
			"speed": 260.0,
			"cooldown": 1.25,
			"grid_size": 12,
			"stone_max_hp": 24.0,
			"stone_collision_wear": 4.5,
			"black_damage_per_stone": 2.5,
			"white_heal_per_stone": 3.0,
		},
	})
	var against_plant := BattleSimulationScript.new(20260830, "go_ball", "plant")
	var against_wdc := BattleSimulationScript.new(20260830, "go_ball", "wdc")
	for simulation in [against_plant, against_wdc]:
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).max_hp, 180.0), "围棋球生命配置跨对手保持")
		_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[0].team_id).base_speed, 260.0), "围棋球速度配置跨对手保持")
		_check(simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingi("grid_size") == 12, "围棋盘尺寸配置跨对手保持")
		_check(is_equal_approx(simulation.module_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).settingf("stone_max_hp"), 24.0), "棋子生命配置跨对手保持")
	_check(is_equal_approx(against_plant.fighter_for_side(against_plant.teams[1].team_id).max_hp, 100.0), "围棋球配置不串改植物球")
	_check(is_equal_approx(against_wdc.fighter_for_side(against_wdc.teams[1].team_id).max_hp, 100.0), "围棋球配置不串改 WDC")
	BallRegistry.configure_settings({})

func _check_rectangular_board_and_alternating_placement() -> void:
	BallRegistry.configure_settings({})
	var rectangle_board := BoardEntityScript.new(
		0,
		Vector2(440.0, 740.0),
		10,
		Color.BLACK,
		Color.WHITE
	)
	_check(rectangle_board.call("grid_size") == 10, "长竞技场仍绘制横纵各十条棋线")
	_check(rectangle_board.call("line_spacing") == Vector2(44.0, 74.0), "长竞技场棋线间距独立使用真实宽高")
	_check(rectangle_board.call("intersection_position", Vector2i(0, 0)) == Vector2(22.0, 37.0), "首个交叉点向竞技场内缩半个线距")
	_check(rectangle_board.call("intersection_position", Vector2i(9, 9)) == Vector2(418.0, 703.0), "长竞技场末端交叉点不按正方形缩窄")
	_check(rectangle_board.call("intersection_at", Vector2(34.0, 36.0)) == Vector2i(0, 0), "当前位置吸附到最近棋线交叉点")

	var simulation := BattleSimulationScript.new(20260831, "go_ball", "test_ball")
	var boards: Array[BallEntity] = simulation.entity_list(0, "go_board")
	_check(boards.size() == 1, "围棋球进场只创建自己的永久棋盘")
	_check(boards[0].owner_fighter_uid == simulation.fighter_for_side(simulation.teams[0].team_id).fighter_uid, "棋盘绑定真实创建主球 UID")
	_place(simulation, Vector2(34.0, 36.0))
	var stones: Array[BallEntity] = simulation.entity_list(-1, "go_stone")
	_check(stones.size() == 1, "首次落子在最近棋线交叉点生成一枚棋子")
	_check(int(stones[0].call("stone_color")) == StoneEntityScript.StoneColor.BLACK, "首次成功落黑子")
	var first_intersection: Vector2i = stones[0].call("board_intersection")
	var expected_position: Vector2 = boards[0].call("intersection_position", first_intersection)
	_check(stones[0].pos == expected_position, "棋子中心严格压在横纵棋线交叉点")
	_place(simulation, Vector2(34.0, 36.0))
	_check(simulation.entity_list(-1, "go_stone").size() == 1, "已占用交叉点不会叠放棋子")
	_check(int(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("next_stone_color")) == StoneEntityScript.StoneColor.WHITE, "落子失败不会跳过下一枚白子")
	_place(simulation, Vector2(102.0, 36.0))
	stones = simulation.entity_list(-1, "go_stone")
	_check(stones.size() == 2, "移动到空格后可以继续落子")
	_check(int(stones[1].call("stone_color")) == StoneEntityScript.StoneColor.WHITE, "成功落子按黑白顺序交替")
	_check(String(simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).call("form_kind")) == "balanced", "黑白数量相同时进入阴阳鱼形态")

func _check_black_white_and_balanced_contact_rules() -> void:
	var black := BattleSimulationScript.new(20260901, "go_ball", "test_ball")
	_place(black, Vector2(70.0, 70.0))
	black.fighter_for_side(black.teams[1].team_id).max_hp = 1000.0
	black.fighter_for_side(black.teams[1].team_id).hp = 1000.0
	_prepare_main_contact(black)
	var black_target_before: float = black.fighter_for_side(black.teams[1].team_id).hp
	black._resolve_fighter_pair(black.fighter_for_side(black.teams[0].team_id), black.fighter_for_side(black.teams[1].team_id))
	_check(is_equal_approx(black_target_before - black.fighter_for_side(black.teams[1].team_id).hp, 1.0), "黑子占优时按黑子数量造成碰撞伤害")
	_check(String(black._ability_for_fighter(black.fighter_for_side(black.teams[0].team_id)).call("form_kind")) == "black", "黑子占优时切换黑棋形态")

	var white := BattleSimulationScript.new(20260902, "go_ball", "test_ball")
	_place(white, Vector2(70.0, 70.0))
	_place(white, Vector2(140.0, 70.0))
	var white_stones: Array[BallEntity] = white.entity_list(-1, "go_stone")
	white_stones[0].removed = true
	white._ability_for_fighter(white.fighter_for_side(white.teams[0].team_id)).on_step(white.battle_context, white.fighter_for_side(white.teams[0].team_id), white.fighter_for_side(white.teams[1].team_id), 0, 0.0)
	white.fighter_for_side(white.teams[0].team_id).hp = 50.0
	white.fighter_for_side(white.teams[1].team_id).max_hp = 1000.0
	white.fighter_for_side(white.teams[1].team_id).hp = 1000.0
	_prepare_main_contact(white)
	var white_target_before: float = white.fighter_for_side(white.teams[1].team_id).hp
	white._resolve_fighter_pair(white.fighter_for_side(white.teams[0].team_id), white.fighter_for_side(white.teams[1].team_id))
	_check(is_equal_approx(white.fighter_for_side(white.teams[1].team_id).hp, white_target_before), "白子占优时本体碰撞不造成伤害")
	_check(is_equal_approx(white.fighter_for_side(white.teams[0].team_id).hp, 51.0), "白子占优时按白子数量回复生命")
	_check(String(white._ability_for_fighter(white.fighter_for_side(white.teams[0].team_id)).call("form_kind")) == "white", "白子占优时切换白棋形态")

	var balanced := BattleSimulationScript.new(20260903, "go_ball", "test_ball")
	_place(balanced, Vector2(70.0, 70.0))
	_place(balanced, Vector2(140.0, 70.0))
	balanced.fighter_for_side(balanced.teams[0].team_id).hp = 50.0
	balanced.fighter_for_side(balanced.teams[1].team_id).max_hp = 1000.0
	balanced.fighter_for_side(balanced.teams[1].team_id).hp = 1000.0
	_prepare_main_contact(balanced)
	var balanced_target_before: float = balanced.fighter_for_side(balanced.teams[1].team_id).hp
	balanced._resolve_fighter_pair(balanced.fighter_for_side(balanced.teams[0].team_id), balanced.fighter_for_side(balanced.teams[1].team_id))
	_check(is_equal_approx(balanced_target_before - balanced.fighter_for_side(balanced.teams[1].team_id).hp, 1.0), "势均力敌时保留黑子伤害")
	_check(is_equal_approx(balanced.fighter_for_side(balanced.teams[0].team_id).hp, 51.0), "势均力敌时同时保留白子回复")

func _check_stone_fighter_collision_wear() -> void:
	var simulation := BattleSimulationScript.new(20260904, "go_ball", "test_ball")
	_place(simulation, Vector2(220.0, 220.0))
	var stone: BallEntity = simulation.entity_list(0, "go_stone")[0]
	var stone_hp_before: float = float(stone.get("hp"))
	var opponent_hp_before: float = simulation.fighter_for_side(simulation.teams[1].team_id).hp
	_overlap_fighter_with_stone(simulation.fighter_for_side(simulation.teams[1].team_id), stone)
	simulation._resolve_fighter_entity_collisions()
	stone.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(stone_hp_before - float(stone.get("hp")), 3.0), "敌方主球每次撞到棋子使棋子损耗 3 点")
	_check(is_equal_approx(simulation.fighter_for_side(simulation.teams[1].team_id).hp, opponent_hp_before), "棋子本身不对碰撞主球造成伤害")

	_overlap_fighter_with_stone(simulation.fighter_for_side(simulation.teams[1].team_id), stone)
	simulation._resolve_fighter_entity_collisions()
	stone.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(float(stone.get("hp")), 7.0), "同一次持续接触不会重复磨损棋子")
	for _frame in range(32):
		stone.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_overlap_fighter_with_stone(simulation.fighter_for_side(simulation.teams[1].team_id), stone)
	simulation._resolve_fighter_entity_collisions()
	stone.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(float(stone.get("hp")), 4.0), "离开重复碰撞间隔后再次撞击会重新损耗棋子")

func _check_stone_entity_collision_attack_capture_and_transfer() -> void:
	var simulation := BattleSimulationScript.new(20260905, "go_ball", "test_ball")
	_place(simulation, Vector2(260.0, 260.0))
	var stone: BallEntity = simulation.entity_list(0, "go_stone")[0]
	var fixture := ContactFixture.new(1, stone.pos + Vector2(stone.radius + 6.0, 0.0))
	fixture.owner_fighter_uid = simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid
	simulation.add_entity(fixture)
	stone.call("resolve_entity_collision", simulation.battle_context, fixture)
	stone.process_step(simulation.battle_context, BattleSimulation.FIXED_STEP)
	_check(is_equal_approx(float(stone.get("hp")), 7.0), "敌方附属物撞到棋子同样触发棋子磨损")
	_check(is_equal_approx(fixture.hp, 20.0), "棋子不会反向伤害敌方附属物")

	var attack_applied: float = simulation.damage_entity(stone, 2.0, Color.RED, 1)
	_check(is_equal_approx(attack_applied, 2.0) and is_equal_approx(float(stone.get("hp")), 5.0), "投射物和范围攻击可通过通用受击契约伤害棋子")
	_check(stone.is_absorbable() and stone.can_be_captured(), "棋子可被黑洞捕获和吞噬")
	var color_before := int(stone.call("stone_color"))
	_check(stone.transfer_ownership(1, simulation.fighter_for_side(simulation.teams[1].team_id)), "棋子可被通用所有权转移能力永久夺取")
	_check(stone.owner_side == 1 and stone.owner_fighter_uid == simulation.fighter_for_side(simulation.teams[1].team_id).fighter_uid, "夺取后棋子立即归属新主球")
	_check(int(stone.call("stone_color")) == color_before, "所有权变化不改写棋子的黑白棋理身份")

func _check_owner_cleanup_and_determinism() -> void:
	var cleanup := BattleSimulationScript.new(20260906, "go_ball", "test_ball")
	_place(cleanup, Vector2(70.0, 70.0))
	var owned_entities := cleanup.entity_list(0)
	for entity: BallEntity in owned_entities:
		_check(entity.owner_fighter_uid == cleanup.fighter_for_side(cleanup.teams[0].team_id).fighter_uid, "围棋球棋盘和棋子都记录真实创建主球 UID")
	cleanup.damage(cleanup.fighter_for_side(cleanup.teams[0].team_id), cleanup.fighter_for_side(cleanup.teams[0].team_id).hp, Color.WHITE, cleanup.fighter_for_side(cleanup.teams[1].team_id))
	cleanup._process_pending_deaths()
	_check(cleanup.entity_list(0, "go_board").is_empty(), "围棋球退场时自己的棋盘同步清理")
	_check(cleanup.entity_list(0, "go_stone").is_empty(), "围棋球退场时自己的棋子同步清理")

	var first := BattleSimulationScript.new(20260907, "go_ball", "plant")
	var replay := BattleSimulationScript.new(20260907, "go_ball", "plant")
	for _frame in range(720):
		first.step(BattleSimulation.FIXED_STEP)
		replay.step(BattleSimulation.FIXED_STEP)
		if first.finished and replay.finished:
			break
	_check(first.snapshot() == replay.snapshot(), "围棋球相同种子和配置的主战斗快照完全一致")
	_check(_stone_snapshot(first) == _stone_snapshot(replay), "围棋落子颜色、格位、生命和归属可确定性重放")

func _place(simulation, position: Vector2) -> void:
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = position
	var previous = simulation._set_execution_fighter(simulation.fighter_for_side(simulation.teams[0].team_id))
	simulation._ability_for_fighter(simulation.fighter_for_side(simulation.teams[0].team_id)).activate(
		simulation.battle_context,
		simulation.fighter_for_side(simulation.teams[0].team_id),
		simulation.fighter_for_side(simulation.teams[1].team_id),
		simulation.fighter_for_side(simulation.teams[0].team_id).team_id
	)
	simulation._set_execution_fighter(previous)

func _prepare_main_contact(simulation) -> void:
	simulation._contact_timers.clear()
	simulation.fighter_for_side(simulation.teams[0].team_id).pos = Vector2(300.0, 320.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).pos = Vector2(350.0, 320.0)
	simulation.fighter_for_side(simulation.teams[0].team_id).velocity = Vector2(195.0, 0.0)
	simulation.fighter_for_side(simulation.teams[1].team_id).velocity = Vector2(-180.0, 0.0)

func _overlap_fighter_with_stone(fighter, stone: BallEntity) -> void:
	fighter.pos = stone.pos + Vector2(stone.radius + fighter.radius - 2.0, 0.0)
	fighter.velocity = Vector2(-180.0, 0.0)

func _stone_snapshot(simulation) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for stone: BallEntity in simulation.entity_list(-1, "go_stone"):
		snapshot.append({
			"intersection": stone.call("board_intersection"),
			"color": stone.call("stone_color"),
			"hp": stone.get("hp"),
			"owner_side": stone.owner_side,
			"owner_fighter_uid": stone.owner_fighter_uid,
		})
	snapshot.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_intersection: Vector2i = first["intersection"]
		var second_intersection: Vector2i = second["intersection"]
		return first_intersection.y < second_intersection.y or (first_intersection.y == second_intersection.y and first_intersection.x < second_intersection.x)
	)
	return snapshot

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
