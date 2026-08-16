extends SceneTree

const GlobalGameSettingsScript := preload("res://scripts/settings/global_game_settings.gd")

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
	"res://scripts/settings/ball_settings_store.gd",
	"res://scripts/settings/global_game_settings.gd",
	"res://scripts/settings/global_settings_store.gd",
	"res://scripts/ui/ball_settings_dialog.gd",
	"res://scripts/ui/battle_view.gd",
	"res://scripts/ui/global_settings_dialog.gd",
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
	_check_per_ball_tuning_contract()
	_check_global_settings_contract()
	_check_ball_modules_do_not_reference_each_other()
	_check_contact_damage_policy()
	_check_no_global_progression_state()
	_check_no_special_scenarios()
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

func _check_per_ball_tuning_contract() -> void:
	var ball_ids := BallRegistry.ids()
	for ball_id in ball_ids:
		var module: BallModule = BallRegistry.get_module(ball_id)
		var specs := module.setting_specs()
		var defaults := module.default_settings_snapshot()
		_check(is_equal_approx(float(defaults.get("max_hp", 0.0)), 100.0), "%s 本体默认生命值为 100" % ball_id)
		_check(specs.keys().size() == defaults.keys().size(), "%s 的参数 Schema 与默认值一一对应" % ball_id)
		for key in specs:
			var spec: Dictionary = specs[key]
			_check(spec.has("label") and spec.has("default"), "%s/%s 声明标签与默认值" % [ball_id, key])
			_check(float(spec["max"]) >= float(spec["min"]), "%s/%s 参数范围有效" % [ball_id, key])
	var target_id: String = ball_ids[0]
	BallRegistry.configure_settings({target_id: {"max_hp": 137.0}})
	for ball_id in ball_ids:
		var expected_hp := 137.0 if ball_id == target_id else 100.0
		_check(
			is_equal_approx(BallRegistry.get_module(ball_id).max_hp, expected_hp),
			"修改一个球的持久化参数不会改写其他球：%s" % ball_id
		)
	BallRegistry.configure_settings({})

func _check_global_settings_contract() -> void:
	var settings = GlobalGameSettingsScript.new()
	_check(settings.settingi("battle_time_seconds") == 120, "全局默认对局时限为两分钟")
	_check(settings.arena_size() == Vector2(640.0, 640.0), "全局默认竞技场为 640×640")
	var specs: Dictionary = settings.setting_specs()
	_check(specs.size() == 3, "全局 Schema 只包含时限与竞技场宽高")
	_check(not specs.has("max_hp") and not specs.has("damage"), "全局设置不接管任何球属性")
	var simulation_source := FileAccess.get_file_as_string("res://scripts/simulation/battle_simulation.gd")
	_check(simulation_source.contains("time_limit_seconds"), "模拟器显式接收全局默认对局时限")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("GlobalSettingsStoreScript.load_settings"), "入口启动时加载全局持久化设置")
	_check(not main_source.contains("time_limit_spin_box"), "入口不保留第二套单局时限输入")

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
		"res://scripts/ui",
	]
	var forbidden_pattern := RegEx.new()
	forbidden_pattern.compile("(^|[^A-Za-z0-9_])(phase|phase_[A-Za-z0-9_]*|[A-Za-z0-9_]*_phase|stage|stage_[A-Za-z0-9_]*|[A-Za-z0-9_]*_stage)([^A-Za-z0-9_]|$)")
	for root in gameplay_roots:
		for file_path in _gd_files_recursive(root):
			var source := FileAccess.get_file_as_string(file_path)
			_check(forbidden_pattern.search(source) == null, "公共玩法和视图不得拥有全局阶段：%s" % file_path)

func _check_no_special_scenarios() -> void:
	_check(not DirAccess.dir_exists_absolute("res://scripts/scenarios"), "源码不保留任何特殊场景目录")
	var simulation_source := FileAccess.get_file_as_string("res://scripts/simulation/battle_simulation.gd")
	var module_source := FileAccess.get_file_as_string("res://scripts/balls/core/ball_module.gd")
	_check(not simulation_source.contains("Scenario"), "通用模拟器不依赖场景注册或匹配")
	_check(not simulation_source.contains("profile"), "通用模拟器不按组合选择球档案")
	_check(not module_source.contains("register_profile"), "球模块只保留唯一能力实现")
	_check(not module_source.contains("create_profile_ability"), "球模块不提供特殊档案能力入口")
	for ball_id in BallRegistry.ids():
		for file_path in _gd_files_recursive("res://scripts/balls/%s" % ball_id):
			var source := FileAccess.get_file_as_string(file_path)
			_check(not source.contains("showcase"), "球目录不保留特殊场景实现：%s" % file_path)
	_check(simulation_source.contains("const DAMAGE_SCALE := 1.0"), "通用伤害结算使用恒等倍率")
	_check(simulation_source.contains("const RECOVERY_SCALE := 1.0"), "通用回复结算使用恒等倍率")

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
	var simulation_source := FileAccess.get_file_as_string("res://scripts/simulation/battle_simulation.gd")
	_check(simulation_source.count("spawn_text(") == 4, "战斗核心只保留本体伤害、实体伤害、治疗和通用浮字入口")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
