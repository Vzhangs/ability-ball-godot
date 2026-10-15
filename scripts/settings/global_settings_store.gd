class_name GlobalSettingsStore
extends RefCounted

const BattleSetupScript := preload("res://scripts/simulation/battle_setup.gd")
const SETTINGS_PATH := "user://ability_ball_global_settings.json"
const FORMAT_VERSION := 2

static func load_mode_settings(mode: String, path: String = SETTINGS_PATH) -> Dictionary:
	if not mode in BattleSetupScript.SUPPORTED_MODES:
		push_warning("未知玩法的全局设置已忽略：%s" % mode)
		return {}
	return (load_all_mode_settings(path).get(mode, {}) as Dictionary).duplicate(true)

static func load_all_mode_settings(path: String = SETTINGS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var source := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(source)
	if not parsed is Dictionary:
		push_warning("全局设置文件损坏，已使用默认值：%s" % path)
		return {}
	var document := parsed as Dictionary
	var version := int(document.get("version", 0))
	if version != FORMAT_VERSION:
		push_error("全局设置文件版本不受支持（要求版本 %d）：%s" % [FORMAT_VERSION, path])
		return {}
	var raw_profiles = document.get("mode_settings", {})
	if not raw_profiles is Dictionary:
		return {}
	var profiles := {}
	for mode in BattleSetupScript.SUPPORTED_MODES:
		var raw_settings = raw_profiles.get(mode, {})
		if raw_settings is Dictionary:
			profiles[mode] = (raw_settings as Dictionary).duplicate(true)
	return profiles

static func save_mode_settings(mode: String, settings: Dictionary, path: String = SETTINGS_PATH) -> Error:
	if not mode in BattleSetupScript.SUPPORTED_MODES:
		return ERR_INVALID_PARAMETER
	var profiles := load_all_mode_settings(path)
	profiles[mode] = settings.duplicate(true)
	return save_all_mode_settings(profiles, path)

static func save_all_mode_settings(mode_settings: Dictionary, path: String = SETTINGS_PATH) -> Error:
	var profiles := {}
	for mode in BattleSetupScript.SUPPORTED_MODES:
		var settings = mode_settings.get(mode, {})
		if settings is Dictionary:
			profiles[mode] = (settings as Dictionary).duplicate(true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": FORMAT_VERSION,
		"mode_settings": profiles,
	}, "\t"))
	file.close()
	return OK
