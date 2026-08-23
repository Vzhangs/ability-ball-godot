class_name GlobalGameSettings
extends RefCounted

const DEFAULT_BATTLE_TIME := 120.0
const DEFAULT_ARENA_SIZE := Vector2(640.0, 640.0)
const DEFAULT_RECORDING_FPS := 60
const DEFAULT_RESULT_REVEAL_DELAY := 1.2

const SETTING_SPECS := {
	"battle_time_seconds": {
		"label": "默认对局时限",
		"group": "对局规则",
		"default": DEFAULT_BATTLE_TIME,
		"min": 15,
		"max": 600,
		"step": 5,
		"kind": "int",
		"order": 10,
		"suffix": " 秒",
		"tooltip": "所有新对局的硬时限；命令行 --time-limit 只临时覆盖当前进程。",
	},
	"arena_width": {
		"label": "竞技场宽度",
		"group": "可对战区域",
		"default": DEFAULT_ARENA_SIZE.x,
		"min": 320,
		"max": 1920,
		"step": 10,
		"kind": "int",
		"order": 20,
		"suffix": " px",
		"tooltip": "场地白框内的实际横向碰撞范围，不是系统窗口宽度。",
	},
	"arena_height": {
		"label": "竞技场高度",
		"group": "可对战区域",
		"default": DEFAULT_ARENA_SIZE.y,
		"min": 320,
		"max": 1920,
		"step": 10,
		"kind": "int",
		"order": 30,
		"suffix": " px",
		"tooltip": "场地白框内的实际纵向碰撞范围，不是系统窗口高度。",
	},
	"recording_fps": {
		"label": "录制帧率",
		"group": "视频录制",
		"default": DEFAULT_RECORDING_FPS,
		"min": 24,
		"max": 120,
		"step": 1,
		"kind": "int",
		"order": 40,
		"suffix": " FPS",
		"tooltip": "只控制成片画面帧率；战斗物理始终以 60 Hz 固定步长计算。",
	},
	"result_reveal_delay_seconds": {
		"label": "胜负揭晓延迟",
		"group": "战斗表现",
		"default": DEFAULT_RESULT_REVEAL_DELAY,
		"min": 0.4,
		"max": 5.0,
		"step": 0.1,
		"kind": "float",
		"order": 50,
		"suffix": " 秒",
		"tooltip": "败方死亡特效和音效先完整呈现，随后再显示获胜弹窗。",
	},
}

var _values := {}

func _init(overrides: Dictionary = {}) -> void:
	apply_settings(overrides)

func apply_settings(overrides: Dictionary) -> void:
	_values.clear()
	for key in SETTING_SPECS:
		var spec: Dictionary = SETTING_SPECS[key]
		_values[key] = _normalize_value(spec, overrides.get(key, spec["default"]))

func setting(key: String):
	assert(_values.has(key), "Unknown global setting: %s" % key)
	return _values[key]

func settingf(key: String) -> float:
	return float(setting(key))

func settingi(key: String) -> int:
	return int(setting(key))

func setting_specs() -> Dictionary:
	return SETTING_SPECS.duplicate(true)

func ordered_setting_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in SETTING_SPECS:
		keys.append(String(key))
	keys.sort_custom(func(left: String, right: String) -> bool:
		return int(SETTING_SPECS[left]["order"]) < int(SETTING_SPECS[right]["order"])
	)
	return keys

func settings_snapshot() -> Dictionary:
	return _values.duplicate(true)

func default_settings_snapshot() -> Dictionary:
	var result := {}
	for key in SETTING_SPECS:
		result[key] = SETTING_SPECS[key]["default"]
	return result

func arena_size() -> Vector2:
	return Vector2(settingf("arena_width"), settingf("arena_height"))

func _normalize_value(spec: Dictionary, raw_value):
	var numeric := float(spec["default"])
	if raw_value is int or raw_value is float:
		numeric = float(raw_value)
	numeric = clampf(numeric, float(spec["min"]), float(spec["max"]))
	numeric = snappedf(numeric, float(spec["step"]))
	return int(round(numeric)) if String(spec["kind"]) == "int" else numeric
