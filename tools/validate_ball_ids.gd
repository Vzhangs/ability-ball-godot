extends SceneTree

const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")

func _init() -> void:
	BallRegistry.reload()
	if not BallRegistry.is_valid():
		printerr("球模块注册失败：%s" % ", ".join(BallRegistry.validation_errors()))
		quit(2)
		return
	var requested := {}
	var battle_mode := BattleSetupScript.MODE_DUEL
	var encoded_rosters := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--left="):
			requested["left"] = argument.trim_prefix("--left=")
		elif argument.begins_with("--right="):
			requested["right"] = argument.trim_prefix("--right=")
		elif argument.begins_with("--battle-mode="):
			battle_mode = argument.trim_prefix("--battle-mode=")
		elif argument.begins_with("--team-rosters="):
			encoded_rosters = argument.trim_prefix("--team-rosters=")
	for side in ["left", "right"]:
		if not requested.has(side) or not BallRegistry.has_id(String(requested[side])):
			printerr("未知或缺失的%s球 ID。可用：%s" % [side, " ".join(BallRegistry.ids())])
			quit(2)
			return
	if battle_mode != BattleSetupScript.MODE_DUEL:
		var rosters: Array = []
		for raw_team in encoded_rosters.split("|", false):
			var roster: Array[String] = []
			for raw_ball_id in raw_team.split(",", false):
				roster.append(raw_ball_id.strip_edges())
			rosters.append(roster)
		var setup = null
		match battle_mode:
			BattleSetupScript.MODE_RELAY:
				if rosters.size() == 2: setup = BattleSetupScript.relay(rosters[0], rosters[1])
			BattleSetupScript.MODE_FREE_FOR_ALL:
				setup = BattleSetupScript.free_for_all(rosters)
			BattleSetupScript.MODE_TEAM_BRAWL:
				if rosters.size() == 2: setup = BattleSetupScript.team_brawl(rosters[0], rosters[1])
		if setup == null or not setup.is_valid():
			printerr("对战模式或阵容无效：%s %s" % [battle_mode, encoded_rosters])
			quit(2)
			return
	print("球 ID 与阵容校验通过：%s %s" % [battle_mode, encoded_rosters])
	quit(0)
