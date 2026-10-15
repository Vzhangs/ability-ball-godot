extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const CjkFontProviderScript := preload("res://scripts/ui/cjk_font_provider.gd")

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var sidebar := main.get_node_or_null("ConfigSidebar") as Control
	var ui_font: Font = main.theme.default_font
	_check(ui_font == CjkFontProviderScript.font(), "主界面安装统一中文 UI 字体")
	_check(ui_font.has_char("敌".unicode_at(0)), "主界面实际字体覆盖曾经显示成方框的‘敌’字")
	_check(
		CjkFontProviderScript.missing_characters(
			CjkFontProviderScript.validation_source(BallRegistry.modules())
		).is_empty(),
		"主界面实际字体覆盖全部球名和能力简介字符"
	)
	_check(main.get_window().content_scale_size == Vector2i(1180, 1280), "交互窗口使用带左侧栏的 1180×1280 逻辑画布")
	_check(sidebar != null and sidebar.size == Vector2(420.0, 1200.0), "左侧配置栏具有独立固定区域")
	_check(sidebar != null and sidebar.is_ancestor_of(main.mode_roster_editor), "玩法与阵容编辑器归入左侧配置栏")
	_check(
		sidebar != null and sidebar.position.x + sidebar.size.x < main.battle_idle_view.position.x,
		"左侧配置栏与右侧战斗区互不重叠"
	)
	_check(sidebar != null and sidebar.find_child("StartBattleButton", true, false) != null, "开始按钮位于左侧配置栏")
	_check(sidebar != null and sidebar.find_child("ModeGlobalSettingsButton", true, false) != null, "玩法设置入口位于左侧配置栏")
	_check(sidebar != null and sidebar.find_child("BallSettingsButton", true, false) != null, "球参数入口位于左侧配置栏")
	_check(main.battle_view == null, "交互式启动不会创建默认 BattleView 或 BattleSimulation")
	_check(main.battle_idle_view != null and main.battle_idle_view.visible, "启动后显示待开局占位区")
	_check(main.get_node_or_null("BattleIdleView") != null, "待开局状态具有稳定节点标识")
	_check(main.pause_button.disabled, "尚未开局时暂停按钮不可用")
	_check(main.record_button.disabled, "尚未开局时录制按钮不可用")

	main.call("_toggle_pause")
	main.call("_record_current_battle")
	_check(main.battle_view == null, "空闲状态调用暂停或录制不会偷偷创建对局")
	_check(main.result_label.text.contains("请先开始对战"), "空闲状态录制会提示先开始一局")

	main.battle_logger = null
	main.call("_start_selected_match")
	await process_frame
	_check(main.battle_view != null and main.battle_view.simulation != null, "点击开始对战后才创建真实模拟器")
	_check(main.battle_idle_view == null, "真实对局开始后移除待开局占位区")
	_check(not main.pause_button.disabled and not main.record_button.disabled, "开局后启用暂停与录制")

	main.call("_on_battle_mode_selected", 1)
	await process_frame
	_check(main.battle_view == null, "切换玩法返回阵容编辑状态，不自动开启另一局")
	_check(main.battle_idle_view != null and main.battle_idle_view.visible, "切换玩法后重新显示待开局区")
	_check(
		main.left_title_label.text == "红队(%d球)" % main.team_rosters[0].size()
			and main.right_title_label.text == "蓝队(%d球)" % main.team_rosters[1].size(),
		"擂台标题使用紧凑英文括号并明确标注球数"
	)
	_check(main.left_title_label.get_theme_color("font_color") == BattleSetup.RELAY_RED_TEAM_COLOR and main.right_title_label.get_theme_color("font_color") == BattleSetup.RELAY_BLUE_TEAM_COLOR, "擂台标题固定使用正确的红队与蓝队颜色")
	main.call("_on_team_name_changed", 0, "先锋队")
	_check(main.left_title_label.text == "先锋队(%d球)" % main.team_rosters[0].size(), "擂台自定义名立即进入标题预览")
	_check(main.left_title_label.get_theme_color("font_color") == BattleSetup.RELAY_RED_TEAM_COLOR, "擂台改名不会改变红方标题颜色")
	main.call("_on_battle_mode_selected", 3)
	await process_frame
	_check(
		main.left_title_label.text == "红队(%d球)" % main.team_rosters[0].size()
			and main.right_title_label.text == "蓝队(%d球)" % main.team_rosters[1].size(),
		"双方大混战标题沿用擂台观众 HUD 的红队蓝队命名"
	)
	main.call("_on_battle_mode_selected", 1)
	await process_frame
	_check(main.left_title_label.text.begins_with("先锋队("), "切换玩法后擂台仍保留本次自定义阵营名")
	main.call("_on_battle_mode_selected", 2)
	await process_frame
	var free_for_all_ball_count := 0
	for roster in main.team_rosters:
		free_for_all_ball_count += roster.size()
	_check(
		main.left_title_label.text == "%d队" % main.team_rosters.size()
			and main.right_title_label.text == "%d球" % free_for_all_ball_count,
		"多方混战标题只显示队伍数和参战球数，不再冒出队伍一或左方右方"
	)
	main.call("_on_battle_mode_selected", 1)
	await process_frame
	var square_idle_center_y: float = main.battle_idle_view.position.y + main.battle_idle_view.size.y * 0.5

	main.call("_apply_global_settings", {
		"arena_width": 440,
		"arena_height": 740,
	})
	main.call("_show_battle_idle_state", "tall_arena_layout_test")
	var expected_tall_size: Vector2 = BattleViewScript.view_size_for_arena(
		Vector2(440.0, 740.0),
		BattleViewScript.DEFAULT_VIEW_SIZE.x,
		main.battle_mode
	)
	_check(main.battle_idle_view.size == expected_tall_size, "空闲占位外框随 440×740 竞技场纵向增长")
	_check(is_equal_approx(main.battle_idle_view.size.x, BattleViewScript.DEFAULT_VIEW_SIZE.x), "空闲占位外框增高时不改变固定视觉宽度")
	_check(
		is_equal_approx(
			main.battle_idle_view.position.y + main.battle_idle_view.size.y * 0.5,
			square_idle_center_y
		),
		"交互竞技场围绕稳定垂直中心向上下两侧伸展"
	)
	main.call("_start_selected_match")
	await process_frame
	_check(main.battle_view.size == expected_tall_size, "真实对局沿用按竞技场高度增长后的外框尺寸")
	_check(main.battle_view.simulation.battle_setup.teams[0]["name"] == "先锋队", "开局运行时使用配置侧栏的自定义阵营名")
	_check(main.battle_view.position.y >= main.left_title_label.get_parent().position.y + main.left_title_label.get_parent().size.y, "擂台观众 HUD 位于对决标题下方")
	_check(main.battle_view.position.y + main.battle_view.size.y <= 1280.0, "440×740 的完整战斗外框不会被交互竖屏画布底部裁切")
	_check(main.result_label.position.y > main.battle_view.position.y + main.battle_view.size.y, "战斗结果提示跟随可变高度外框下移")
	main.queue_free()
	await process_frame

	if failures.is_empty():
		print("ABILITY_BALL_MAIN_STARTUP_IDLE_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
