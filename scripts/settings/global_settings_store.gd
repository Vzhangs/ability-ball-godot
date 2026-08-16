class_name GlobalSettingsStore
extends RefCounted

const SETTINGS_PATH := "user://ability_ball_global_settings.json"
const FORMAT_VERSION := 1

static func load_settings(path: String = SETTINGS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var source := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(source)
	if not parsed is Dictionary:
		push_warning("全局设置文件损坏，已使用默认值：%s" % path)
		return {}
	var document := parsed as Dictionary
	if int(document.get("version", 0)) != FORMAT_VERSION:
		push_warning("全局设置文件版本不受支持，已使用默认值：%s" % path)
		return {}
	var settings = document.get("settings", {})
	return settings.duplicate(true) if settings is Dictionary else {}

static func save_settings(settings: Dictionary, path: String = SETTINGS_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": FORMAT_VERSION,
		"settings": settings,
	}, "\t"))
	file.close()
	return OK
