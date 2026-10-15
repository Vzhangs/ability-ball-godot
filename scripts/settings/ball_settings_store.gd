class_name BallSettingsStore
extends RefCounted

const SETTINGS_PATH := "user://ability_ball_settings.json"
const BOSS_SETTINGS_PATH := "user://ability_ball_boss_settings.json"
const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const FORMAT_VERSION := 1

static func settings_path_for_mode(mode: String) -> String:
	return BOSS_SETTINGS_PATH if mode == BattleSetupScript.MODE_BOSS else SETTINGS_PATH

static func load_settings(path: String = SETTINGS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var source := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(source)
	if not parsed is Dictionary:
		push_warning("球参数文件损坏，已使用默认值：%s" % path)
		return {}
	var document := parsed as Dictionary
	if int(document.get("version", 0)) != FORMAT_VERSION:
		push_warning("球参数文件版本不受支持，已使用默认值：%s" % path)
		return {}
	var balls = document.get("balls", {})
	return balls.duplicate(true) if balls is Dictionary else {}

static func save_settings(settings: Dictionary, path: String = SETTINGS_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": FORMAT_VERSION,
		"balls": settings,
	}, "\t"))
	file.close()
	return OK
