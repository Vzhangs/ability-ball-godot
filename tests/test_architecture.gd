extends SceneTree

const CORE_FILES := [
	"res://scripts/simulation/battle_simulation.gd",
	"res://scripts/balls/core/ball_ability.gd",
	"res://scripts/balls/core/ball_battle_context.gd",
	"res://scripts/balls/core/ball_entity.gd",
	"res://scripts/balls/core/ball_module.gd",
	"res://scripts/balls/core/ball_registry.gd",
	"res://scripts/balls/core/ball_render_context.gd",
	"res://scripts/balls/core/ball_status_effect.gd",
	"res://scripts/balls/core/ball_visual.gd",
	"res://scripts/balls/core/projectile_entity.gd",
	"res://scripts/scenarios/core/battle_scenario.gd",
	"res://scripts/scenarios/core/scenario_registry.gd",
	"res://scripts/ui/battle_view.gd",
]

const FORBIDDEN_SHARED_STATE := [
	"clone_count",
	"orbit_tethered",
	"ability_active",
	"secondary_timer",
	"wall_damage_cooldown",
	"aux_angle",
	"shield_flash",
	"invulnerable",
]

var failures: Array[String] = []

func _init() -> void:
	BallRegistry.reload()
	_check(BallRegistry.is_valid(), "所有球模块均可加载并通过注册校验：%s" % ", ".join(BallRegistry.validation_errors()))
	_check_core_has_no_ball_knowledge()
	_check_ball_modules_do_not_reference_each_other()
	_check_contact_damage_policy()
	_check_no_global_progression_state()
	_check_public_view_only_draws_generic_contracts()
	_check_single_engine_entrypoint()
	_check_floating_text_policy()
	if failures.is_empty():
		print("ABILITY_BALL_ARCHITECTURE_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("ARCHITECTURE TEST FAILED: " + failure)
		quit(1)

func _check_core_has_no_ball_knowledge() -> void:
	for path in CORE_FILES:
		var source := FileAccess.get_file_as_string(path)
		_check(not source.is_empty(), "可读取核心文件 %s" % path)
		for ball_id in BallRegistry.ids():
			_check(not source.contains('"%s"' % ball_id), "核心文件不得识别具体球 ID：%s -> %s" % [ball_id, path])
		for field in FORBIDDEN_SHARED_STATE:
			_check(not source.contains(field), "核心文件不得保存球种私有状态：%s -> %s" % [field, path])

func _check_ball_modules_do_not_reference_each_other() -> void:
	var dependency_pattern := RegEx.new()
	dependency_pattern.compile("res://scripts/balls/([^/]+)/")
	for owner_id in BallRegistry.ids():
		var owner_path := "res://scripts/balls/%s" % owner_id
		for file_path in _gd_files_recursive(owner_path):
			var source := FileAccess.get_file_as_string(file_path)
			_check(not source.contains('context["simulation"]'), "球模块不得通过渲染上下文访问具体模拟器（%s）" % file_path)
			for result in dependency_pattern.search_all(source):
				var dependency_id := result.get_string(1)
				_check(
					dependency_id == owner_id or dependency_id == "core",
					"球模块 %s 不得引用球模块 %s（%s）" % [owner_id, dependency_id, file_path]
				)

func _check_contact_damage_policy() -> void:
	var module_source := FileAccess.get_file_as_string("res://scripts/balls/core/ball_module.gd")
	var simulation_source := FileAccess.get_file_as_string("res://scripts/simulation/battle_simulation.gd")
	_check(not module_source.contains("var contact_damage"), "公共球模块不得保存默认碰撞伤害")
	_check(not simulation_source.contains('spec["contact_damage"]'), "公共战士状态不得接收默认碰撞伤害")
	for ball_id in BallRegistry.ids():
		var entry_source := FileAccess.get_file_as_string("res://scripts/balls/%s/module.gd" % ball_id)
		_check(not entry_source.contains('"contact_damage"'), "%s 不得通过模块配置获得默认碰撞伤害" % ball_id)

func _check_no_global_progression_state() -> void:
	var gameplay_roots := [
		"res://scripts/simulation",
		"res://scripts/balls/core",
		"res://scripts/scenarios",
		"res://scripts/ui",
	]
	var forbidden_pattern := RegEx.new()
	forbidden_pattern.compile("(^|[^A-Za-z0-9_])(phase|phase_[A-Za-z0-9_]*|[A-Za-z0-9_]*_phase|stage|stage_[A-Za-z0-9_]*|[A-Za-z0-9_]*_stage)([^A-Za-z0-9_]|$)")
	for root in gameplay_roots:
		for file_path in _gd_files_recursive(root):
			var source := FileAccess.get_file_as_string(file_path)
			_check(forbidden_pattern.search(source) == null, "公共玩法、场景和视图不得拥有全局阶段：%s" % file_path)

func _gd_files_recursive(path: String) -> PackedStringArray:
	var files := PackedStringArray()
	for file_name in DirAccess.get_files_at(path):
		if file_name.ends_with(".gd"):
			files.append("%s/%s" % [path, file_name])
	for directory_name in DirAccess.get_directories_at(path):
		files.append_array(_gd_files_recursive("%s/%s" % [path, directory_name]))
	return files

func _check_public_view_only_draws_generic_contracts() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/battle_view.gd")
	for feature_renderer in ["_draw_fire_zones", "_draw_gravity_wells", "_draw_anchors", "_draw_projectiles"]:
		_check(not source.contains(feature_renderer), "公共视图不得包含球种实体绘制器：%s" % feature_renderer)
	_check(source.contains("entity.draw(self, context)"), "公共视图通过 BallEntity 契约绘制附属物")
	_check(source.contains("entity.draw_hud(self, health_bar_bounds)"), "公共视图通过 BallEntity 契约绘制实体 HUD")
	_check(source.contains("effect.draw_overlay(self, fighter, context)"), "公共视图通过 BallStatusEffect 契约绘制状态")

func _check_single_engine_entrypoint() -> void:
	var simulation_files := PackedStringArray()
	for file_name in DirAccess.get_files_at("res://scripts/simulation"):
		if file_name.ends_with(".gd"):
			simulation_files.append(file_name)
	_check(simulation_files == PackedStringArray(["battle_simulation.gd"]), "运行时只保留一个战斗模拟器")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(not main_source.contains("_is_reference_match"), "入口不得按具体球组合切换引擎")
	_check(not main_source.contains("simulation is"), "入口不得按模拟器类型分支")
	_check(main_source.contains("BattleViewScript.new()"), "所有对局统一创建 BattleView")

func _check_floating_text_policy() -> void:
	for owner_id in BallRegistry.ids():
		for file_path in _gd_files_recursive("res://scripts/balls/%s" % owner_id):
			var source := FileAccess.get_file_as_string(file_path)
			_check(not source.contains("spawn_text("), "球模块不得生成说明性浮字，应改用数值、符号或特效：%s" % file_path)
	for file_path in _gd_files_recursive("res://scripts/scenarios"):
		var source := FileAccess.get_file_as_string(file_path)
		_check(not source.contains("spawn_text("), "场景不得生成说明性浮字，应改用符号或特效：%s" % file_path)
	var simulation_source := FileAccess.get_file_as_string("res://scripts/simulation/battle_simulation.gd")
	_check(simulation_source.count("spawn_text(") == 4, "战斗核心只保留本体伤害、实体伤害、治疗和通用浮字入口")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
