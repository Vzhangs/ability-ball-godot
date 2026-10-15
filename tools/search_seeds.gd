extends SceneTree

const Setup := preload("res://scripts/simulation/battle_setup.gd")
const Simulation := preload("res://scripts/simulation/battle_simulation.gd")
const BallStore := preload("res://scripts/settings/ball_settings_store.gd")
const GlobalStore := preload("res://scripts/settings/global_settings_store.gd")
const Settings := preload("res://scripts/settings/global_game_settings.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("Expected requests.json results.jsonl")
		quit(2)
		return
	var requests = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	if not requests is Array or output == null:
		quit(2)
		return
	var started := Time.get_ticks_msec()
	for request: Dictionary in requests:
		if Time.get_ticks_msec() - started > 240000:
			break
		var result := evaluate(request)
		output.store_line(JSON.stringify(result))
		output.flush()
	output.close()
	quit(0)

func evaluate(request: Dictionary) -> Dictionary:
	var mode := String(request["mode"])
	BallRegistry.configure_settings(BallStore.load_settings(BallStore.settings_path_for_mode(mode)))
	var config := Settings.new(GlobalStore.load_mode_settings(mode))
	var rosters: Array = request["rosters"]
	var setup = null
	match mode:
		"duel": setup = Setup.duel(rosters[0][0], rosters[1][0])
		"relay": setup = Setup.relay(rosters[0], rosters[1])
		"team_brawl": setup = Setup.team_brawl(rosters[0], rosters[1])
		"free_for_all": setup = Setup.free_for_all(rosters)
		"boss": setup = Setup.boss(rosters)
	if setup == null or not setup.is_valid() or not BallRegistry.is_valid():
		return {"request": request, "error": "invalid_setup"}
	var rules := {}
	var sim := Simulation.new(int(request["seed"]), setup, config.settingf("battle_time_seconds"), config.arena_size(), rules)
	sim.death_effect_duration = config.settingf("result_reveal_delay_seconds")
	sim.handoff_pause_duration_seconds = config.settingf("relay_handoff_pause_seconds")
	var started := Time.get_ticks_msec()
	var samples: Array = []
	var last_leader := -1
	var lead_changes := 0
	var steps := 0
	var needs_yuri_target := false
	for roster: Array in rosters:
		if "yuri" in roster: needs_yuri_target = true
	var yuri_target_available := false
	while not sim.finished:
		if needs_yuri_target and not yuri_target_available:
			for fighter in sim.fighters:
				if fighter.id != "yuri" or fighter.hp <= 0.0: continue
				for entity in sim.entities:
					if entity.is_hostile_to(fighter.team_id) and entity.can_transfer_ownership():
						yuri_target_available = true
						break
		sim.step(Simulation.FIXED_STEP)
		steps += 1
		if steps % 60 == 0:
			if Time.get_ticks_msec() - started > 15000 or steps > 600 * 60:
				return {"request": request, "error": "budget_exceeded"}
			var ratios: Array[float] = []
			for team in sim.teams: ratios.append(sim.team_remaining_hp_ratio(team))
			var best: float = ratios.max()
			var leader: int = ratios.find(best)
			var ordered := ratios.duplicate()
			ordered.sort()
			if best - ordered[-2] >= 0.10:
				if last_leader >= 0 and leader != last_leader: lead_changes += 1
				last_leader = leader
			samples.append({"seconds": sim.elapsed, "ratios": ratios})
	var deficit := 0.0
	var survivor_ratio := 0.0
	if sim.winner_team_id >= 0:
		for team in sim.teams:
			if team.team_id == sim.winner_team_id: survivor_ratio = sim.team_remaining_hp_ratio(team)
		for sample: Dictionary in samples:
			var ratios: Array = sample["ratios"]
			deficit = maxf(deficit, float(ratios.max()) - float(ratios[sim.winner_team_id]))
	var close_win := sim.winner_team_id >= 0 and survivor_ratio > 0.0 and survivor_ratio <= 0.15
	yuri_target_available = yuri_target_available or int(sim.stats.get("mind_controls", 0)) > 0
	var score := mini(lead_changes, 5) * 12.0 + deficit * 70.0 + (25.0 if close_win else 0.0)
	if sim.elapsed < 15.0: score *= 0.25
	return {"request": request, "score": score, "dramatic": score >= 25.0,
		"yuri_target_available": yuri_target_available,
		"lead_changes": lead_changes, "winner_max_deficit": deficit, "winner_hp_ratio": survivor_ratio,
		"winner_team_id": sim.winner_team_id, "duration": sim.elapsed, "time_limit": sim.max_battle_time,
		"finish_reason": sim.finish_reason, "samples": samples,
		"wall_seconds": (Time.get_ticks_msec() - started) / 1000.0}
