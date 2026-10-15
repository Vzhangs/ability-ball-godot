extends SceneTree

const MainScript := preload("res://scripts/main.gd")
const BattleViewScript := preload("res://scripts/ui/battle_view.gd")
const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")

var failures: Array[String] = []
var _result_wait_finished := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check("--render-video" in OS.get_cmdline_user_args(), "测试必须携带 --render-video")
	var main = MainScript.new()
	get_root().add_child(main)
	await process_frame
	await process_frame
	_check(main.recording_mode, "录制参数启用独立呈现模式")
	_check(main.get_window().content_scale_size == Vector2i(720, 1280), "录制继续使用 720×1280 逻辑母版")
	_check(main.get_node_or_null("ConfigSidebar") == null, "录制呈现不创建左侧配置栏")
	_check(main.battle_view != null and main.battle_view.simulation != null, "录制呈现仍自动创建待录制对局")
	_check(
		is_equal_approx(main.battle_view.position.x, 35.0)
			and is_equal_approx(
				main.battle_view.position.y + main.battle_view.size.y * 0.5,
				650.0
			),
		"录制战斗区以固定视觉宽度围绕母版垂直中心排列"
	)
	_check(main.left_title_label.get_parent().position == Vector2(0.0, 32.0), "录制标题为顶部水印留出空间")
	_check(not main.result_label.visible, "录制画面不显示交互结果提示")
	var ticker = main.recording_ability_ticker
	_check(ticker != null and ticker.visible, "竖屏录制创建观众能力简介滚动区")
	var square_battle_rect := Rect2(main.battle_view.position, main.battle_view.size)
	var square_ticker_rect := Rect2(ticker.position, ticker.size)
	_check(
		not square_battle_rect.intersects(square_ticker_rect)
			and is_equal_approx(square_ticker_rect.position.y, square_battle_rect.end.y + 8.0),
		"能力简介紧跟在竞技场下方且不留固定空洞"
	)
	_check(square_ticker_rect.end.y <= 1272.0, "能力简介完整留在录制母版安全区内")
	var square_battle_center_y := square_battle_rect.get_center().y
	main.call("_apply_global_settings", {
		"arena_width": 440,
		"arena_height": 740,
	})
	main.call("_replace_battle_view", "responsive_tall_recording_layout_test")
	await process_frame
	await process_frame
	var tall_battle_rect := Rect2(main.battle_view.position, main.battle_view.size)
	var tall_ticker_rect := Rect2(ticker.position, ticker.size)
	_check(not tall_battle_rect.intersects(tall_ticker_rect), "440×740 长竞技场不会被下方简介截断")
	_check(
		is_equal_approx(tall_ticker_rect.position.y, tall_battle_rect.end.y + 8.0)
			and tall_ticker_rect.end.y <= 1272.0,
		"长竞技场简介跟随竞技场底部下移且完整留在母版内"
	)
	_check(tall_ticker_rect.size.y >= 70.0, "长竞技场仍为可滚动简介保留最小可读高度")
	_check(
		square_ticker_rect.position.y < tall_ticker_rect.position.y
			and square_ticker_rect.size.y > tall_ticker_rect.size.y,
		"竞技场较短时简介自动上抬并填满更多剩余高度"
	)
	_check(
		absf(tall_battle_rect.get_center().y - square_battle_center_y) <= 24.0,
		"录制竞技场从稳定垂直中心向上下两侧伸展"
	)
	main.battle_mode = BattleSetupScript.MODE_RELAY
	main.team_rosters = [["vampire", "splitter"], ["wdc", "black_hole"]]
	main.team_names.assign(["先锋队", "守擂队"])
	main.call("_replace_battle_view", "responsive_tall_relay_recording_layout_test")
	await process_frame
	await process_frame
	var tall_relay_battle_rect := Rect2(main.battle_view.position, main.battle_view.size)
	var tall_relay_ticker_rect := Rect2(ticker.position, ticker.size)
	_check(
		not tall_relay_battle_rect.intersects(tall_relay_ticker_rect)
			and is_equal_approx(tall_relay_ticker_rect.position.y, tall_relay_battle_rect.end.y + 8.0)
			and tall_relay_ticker_rect.size.y >= 70.0,
		"440×740 擂台 HUD、完整竞技场和简介区也不会互相遮挡"
	)
	_check(main.battle_view.simulation.teams[0].display_name == "先锋队", "录制对局使用传入的自定义阵营名")
	main.battle_mode = BattleSetupScript.MODE_DUEL
	main.team_rosters = [["vampire"], ["wdc"]]
	main.call("_apply_global_settings", {
		"arena_width": 440,
		"arena_height": 440,
	})
	main.call("_replace_battle_view", "responsive_recording_layout_restore")
	await process_frame
	await process_frame
	_check(ticker.entry_count() == 2, "单挑录制循环介绍当前对阵的两颗球")
	_check(ticker.current_entry_id() == "vampire", "能力简介按红方到蓝方的稳定顺序开始播放")
	_check(ticker.current_title().contains("吸血鬼"), "滚动区标题直接标出正在介绍的球")
	_check(ticker.current_body_text() == BallRegistry.get_module("vampire").formatted_ability_description(), "滚动区展示当前球的完整观众向简介")
	_check(not ticker.current_body_text().contains("可配置"), "录制简介不向观众展示配置口吻")
	_check(
		BallModule.sanitize_ability_text(ticker.current_body_text()) == ticker.current_body_text(),
		"录制滚动简介不向字体整形链注入零宽排版字符"
	)
	ticker.call("_advance_entry")
	_check(ticker.current_entry_id() == "wdc", "简介播完后切换到下一颗当前参战球")
	ticker.call("_advance_entry")
	_check(ticker.current_entry_id() == "vampire", "全部参战球介绍完后从第一颗继续循环")
	var render_script := FileAccess.get_file_as_string("res://tools/render_video.sh")
	_check(render_script.contains("--team-names=$team_names"), "录制子进程显式传递自定义阵营名")
	_check(not render_script.contains("crop=1080:1200:0:0"), "视频合成不再用固定高度裁断响应式竞技场")
	_check(not render_script.contains("crop=1080:360:0:1560[ticker]"), "视频合成不再二次裁切和搬运简介区")
	main.battle_logger = null
	main.battle_mode = BattleSetupScript.MODE_RELAY
	main.team_rosters = [["vampire", "splitter"], ["wdc", "black_hole"]]
	main.team_names.assign(["先锋队", "守擂队"])
	main.relay_handoff_pause_seconds = BattleSimulation.FIXED_STEP
	main.call("_replace_battle_view", "recording_ticker_relay_test")
	await process_frame
	await process_frame
	main.call("_sync_recording_ability_ticker")
	_check(ticker.entry_count() == 2 and ticker.current_entry_id() == "vampire", "擂台简介只罗列双方当前上场球，不提前介绍候补")
	var relay_simulation: BattleSimulation = main.battle_view.simulation
	relay_simulation.death_effect_duration = BattleSimulation.FIXED_STEP
	relay_simulation.handoff_pause_duration_seconds = BattleSimulation.FIXED_STEP
	var defeated = relay_simulation.fighter_for_side(0)
	var opponent = relay_simulation.fighter_for_side(1)
	relay_simulation.damage(defeated, defeated.hp + 1.0, defeated.color, opponent)
	for _step in range(4):
		relay_simulation.step(BattleSimulation.FIXED_STEP)
	main.call("_sync_recording_ability_ticker")
	_check(ticker.entry_count() == 2 and ticker.current_entry_id() == "splitter", "擂台换人后简介列表立即改为新上场球和仍存活对手")
	_check(ticker.current_title().contains("分身球"), "候补上场后从新球简介开始新一轮循环")
	await _check_recording_waits_for_whole_report(main)
	main.queue_free()
	await process_frame

	if failures.is_empty():
		print("ABILITY_BALL_RECORDING_LAYOUT_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error("TEST FAILED: " + failure)
		quit(1)

func _check_recording_waits_for_whole_report(main) -> void:
	main.battle_mode = BattleSetupScript.MODE_BOSS
	var roster: Array = []
	for _index in range(8): roster.append("test_ball")
	main.team_rosters = [roster.duplicate(), roster.duplicate(), roster.duplicate()]
	main._replace_battle_view("recording_report_test")
	main._recording_quit_scheduled = true
	var view = main.battle_view
	view.paused = true
	view.simulation.finished = true
	view.simulation.winner_team_id = -1
	view._result_reveal_elapsed = 999.0
	view._sync_result_panel()
	for _frame in range(12): await process_frame
	var panel = view.result_panel
	panel.set_process(false)
	_check(panel.automatic_scroll and panel.scroll_distance() > 0.0, "录制呈现模式启用长战报自动滚动")
	_check(panel.get_global_rect().end.y < main.recording_ability_ticker.position.y, "结算战报留在录制内容区且不遮挡底部简介")
	_observe_result_wait(main)
	for _frame in range(3): await process_frame
	_check(not _result_wait_finished, "录制不会在战报尚未滚完时结束")
	for _tick in range(int(ceilf(panel.presentation_duration() * 60.0))):
		panel._process(1.0 / 60.0)
		if float(panel.scroll.scroll_vertical) >= panel.scroll_distance() - 1.0: break
	for _frame in range(3): await process_frame
	_check(not _result_wait_finished, "刚到最后一行时仍等待片尾停留")
	panel._process(panel.TAIL_HOLD + 0.1)
	for _frame in range(3): await process_frame
	_check(_result_wait_finished and panel.presentation_finished(), "最后一行完整展示并停留后才解除录制退出等待")

func _observe_result_wait(main) -> void:
	await main._wait_for_result_presentation()
	_result_wait_finished = true

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
