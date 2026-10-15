class_name BattleSetup
extends RefCounted

## Immutable-at-runtime description of teams, ordered rosters, and active slots.
## Battle modes are presets of this single data model; the simulator does not
## branch into separate physics or ability engines by mode.

const MODE_DUEL := "duel"
const MODE_RELAY := "relay"
const MODE_FREE_FOR_ALL := "free_for_all"
const MODE_BOSS := "boss"
const MODE_TEAM_BRAWL := "team_brawl"
const SUPPORTED_MODES := [MODE_DUEL, MODE_RELAY, MODE_FREE_FOR_ALL, MODE_TEAM_BRAWL, MODE_BOSS]
const MAX_TEAMS := 8
const MAX_ACTIVE_PER_TEAM := 16
const MAX_ROSTER_SIZE := 32
const MAX_TEAM_NAME_LENGTH := 12
const RELAY_RED_TEAM_NAME := "红队"
const RELAY_BLUE_TEAM_NAME := "蓝队"
const RELAY_RED_TEAM_COLOR := Color("ff5c73")
const RELAY_BLUE_TEAM_COLOR := Color("68d8ff")
const COMPETITIVE_TEAM_NAMES := [
	"红队",
	"蓝队",
	"黄队",
	"紫队",
	"绿队",
	"橙队",
	"粉队",
	"白队",
]
const COMPETITIVE_TEAM_COLORS := [
	Color("ff5c73"),
	Color("68d8ff"),
	Color("ffd166"),
	Color("a78bfa"),
	Color("5ee7a0"),
	Color("ff9f43"),
	Color("f472b6"),
	Color("d7f5ff"),
]

var mode := MODE_DUEL
var teams: Array[Dictionary] = []
var _validation_errors: Array[String] = []

func _init(requested_mode: String = MODE_DUEL, requested_teams: Array = []) -> void:
	mode = requested_mode
	for raw_team in requested_teams:
		if raw_team is Dictionary:
			teams.append((raw_team as Dictionary).duplicate(true))
	_validate()

static func team(
	team_id: int,
	display_name: String,
	roster: Array,
	active_count: int = 1,
	color: Color = Color.TRANSPARENT
) -> Dictionary:
	var normalized_roster: Array[String] = []
	for ball_id in roster:
		normalized_roster.append(String(ball_id))
	return {
		"id": team_id,
		"name": display_name,
		"roster": normalized_roster,
		"active_count": active_count,
		"color": color,
	}

static func _make(requested_mode: String, requested_teams: Array):
	return (load("res://scripts/simulation/battle_setup.gd") as Script).new(
		requested_mode,
		requested_teams
	)

static func competitive_team_name(team_index: int) -> String:
	if team_index < 0:
		return "未知队伍"
	return String(COMPETITIVE_TEAM_NAMES[team_index % COMPETITIVE_TEAM_NAMES.size()])

static func competitive_team_color(team_index: int) -> Color:
	if team_index < 0:
		return Color("b7c2c8")
	return COMPETITIVE_TEAM_COLORS[team_index % COMPETITIVE_TEAM_COLORS.size()]

static func default_team_name(requested_mode: String, team_index: int) -> String:
	if requested_mode == MODE_DUEL:
		return "左方" if team_index == 0 else "右方"
	return competitive_team_name(team_index)

static func sanitize_team_name(raw_name: String, requested_mode: String, team_index: int) -> String:
	var sanitized := raw_name.strip_edges()
	for separator in ["\n", "\r", "\t", "|"]:
		sanitized = sanitized.replace(separator, " ")
	while sanitized.contains("  "):
		sanitized = sanitized.replace("  ", " ")
	sanitized = sanitized.left(MAX_TEAM_NAME_LENGTH).strip_edges()
	return default_team_name(requested_mode, team_index) if sanitized.is_empty() else sanitized

static func _requested_team_name(requested_mode: String, team_index: int, team_names: Array) -> String:
	var raw_name := String(team_names[team_index]) if team_index < team_names.size() else ""
	return sanitize_team_name(raw_name, requested_mode, team_index)

static func duel(left_ball_id: String, right_ball_id: String):
	return _make(MODE_DUEL, [
		team(0, default_team_name(MODE_DUEL, 0), [left_ball_id]),
		team(1, default_team_name(MODE_DUEL, 1), [right_ball_id]),
	])

static func relay(left_roster: Array, right_roster: Array, team_names: Array = []):
	return _make(MODE_RELAY, [
		team(0, _requested_team_name(MODE_RELAY, 0, team_names), left_roster, 1, RELAY_RED_TEAM_COLOR),
		team(1, _requested_team_name(MODE_RELAY, 1, team_names), right_roster, 1, RELAY_BLUE_TEAM_COLOR),
	])

static func free_for_all(team_rosters: Array, team_names: Array = []):
	var requested_teams: Array[Dictionary] = []
	for index in range(team_rosters.size()):
		requested_teams.append(team(
			index,
			_requested_team_name(MODE_FREE_FOR_ALL, index, team_names),
			team_rosters[index],
			1,
			competitive_team_color(index)
		))
	return _make(MODE_FREE_FOR_ALL, requested_teams)

static func boss(team_rosters: Array, team_names: Array = []):
	return _make(MODE_BOSS, free_for_all(team_rosters, team_names).teams)

static func is_free_for_all_mode(requested_mode: String) -> bool:
	return requested_mode in [MODE_FREE_FOR_ALL, MODE_BOSS]

static func allows_team_editing(requested_mode: String) -> bool:
	return is_free_for_all_mode(requested_mode)

static func team_brawl(left_roster: Array, right_roster: Array, team_names: Array = []):
	return _make(MODE_TEAM_BRAWL, [
		team(0, _requested_team_name(MODE_TEAM_BRAWL, 0, team_names), left_roster, left_roster.size(), RELAY_RED_TEAM_COLOR),
		team(1, _requested_team_name(MODE_TEAM_BRAWL, 1, team_names), right_roster, right_roster.size(), RELAY_BLUE_TEAM_COLOR),
	])

func is_valid() -> bool:
	return _validation_errors.is_empty()

func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()

func snapshot() -> Dictionary:
	return {"mode": mode, "teams": teams.duplicate(true)}

func _validate() -> void:
	_validation_errors.clear()
	if not mode in SUPPORTED_MODES:
		_validation_errors.append("unsupported battle mode: %s" % mode)
	if teams.size() < 2:
		_validation_errors.append("a battle requires at least two teams")
	if teams.size() > MAX_TEAMS:
		_validation_errors.append("battle team count exceeds %d" % MAX_TEAMS)
	if mode in [MODE_DUEL, MODE_RELAY, MODE_TEAM_BRAWL] and teams.size() != 2:
		_validation_errors.append("%s mode requires exactly two teams" % mode)
	if is_free_for_all_mode(mode) and teams.size() < 3:
		_validation_errors.append("%s mode requires at least three teams" % mode)
	var seen_team_ids := {}
	for team_index in range(teams.size()):
		var team_spec: Dictionary = teams[team_index]
		var team_id := int(team_spec.get("id", -1))
		var display_name := String(team_spec.get("name", ""))
		var roster: Array = team_spec.get("roster", [])
		var active_count := int(team_spec.get("active_count", 0))
		if team_id < 0:
			_validation_errors.append("team %d requires a non-negative id" % team_index)
		elif seen_team_ids.has(team_id):
			_validation_errors.append("duplicate team id: %d" % team_id)
		else:
			seen_team_ids[team_id] = true
		if display_name.is_empty() or display_name.length() > MAX_TEAM_NAME_LENGTH \
				or display_name.contains("\n") or display_name.contains("\r") \
				or display_name.contains("\t") or display_name.contains("|"):
			_validation_errors.append("team %d display name is invalid" % team_id)
		if roster.is_empty():
			_validation_errors.append("team %d roster cannot be empty" % team_id)
		if roster.size() > MAX_ROSTER_SIZE:
			_validation_errors.append("team %d roster exceeds %d" % [team_id, MAX_ROSTER_SIZE])
		if active_count < 1 or active_count > mini(roster.size(), MAX_ACTIVE_PER_TEAM):
			_validation_errors.append("team %d active_count is outside its roster limits" % team_id)
		for raw_ball_id in roster:
			var ball_id := String(raw_ball_id)
			if ball_id.is_empty() or not BallRegistry.has_id(ball_id):
				_validation_errors.append("team %d contains unknown ball id: %s" % [team_id, ball_id])

	if mode in [MODE_DUEL, MODE_RELAY, MODE_FREE_FOR_ALL, MODE_BOSS]:
		for team_spec in teams:
			if int(team_spec.get("active_count", 0)) != 1:
				_validation_errors.append("%s mode requires one active fighter per team" % mode)
				break
	if mode == MODE_DUEL:
		for team_spec in teams:
			if (team_spec.get("roster", []) as Array).size() != 1:
				_validation_errors.append("duel mode requires one roster entry per team")
				break
