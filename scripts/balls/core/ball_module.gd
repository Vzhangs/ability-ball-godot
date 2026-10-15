class_name BallModule
extends RefCounted

var id := ""
var display_name := ""
var color := Color.WHITE
var accent := Color.WHITE
var title_color := Color.WHITE
var max_hp := 100.0
var speed := 180.0
var radius := 27.0
var cooldown := 4.0
var ability_description := ""
var sound_kind := "impact"
var sort_order := 0
var ability_script: Script
var visual_script: Script
var _audio_samples: Dictionary = {}
var _setting_specs := {}
var _setting_values := {}

func _init(config: Dictionary = {}, behavior: Script = null, visual: Script = null) -> void:
	if config.is_empty():
		return
	id = String(config.get("id", ""))
	display_name = String(config.get("name", ""))
	color = Color(String(config.get("color", "ffffff")))
	accent = Color(String(config.get("accent", "ffffff")))
	title_color = Color(String(config.get("title_color", config.get("color", "ffffff"))))
	max_hp = float(config.get("max_hp", 100.0))
	speed = float(config.get("speed", 180.0))
	radius = float(config.get("radius", 27.0))
	cooldown = float(config.get("cooldown", 4.0))
	ability_description = String(config.get("ability", ""))
	sound_kind = String(config.get("sound_kind", "impact"))
	sort_order = int(config.get("sort_order", 0))
	ability_script = behavior
	visual_script = visual
	var configured_audio_samples = config.get("audio_samples", {})
	if configured_audio_samples is Dictionary:
		for event_kind in configured_audio_samples:
			_audio_samples[String(event_kind)] = configured_audio_samples[event_kind]
	_register_setting("ability_description", {
		"label": "球简介", "group": "公开信息", "default": ability_description,
		"kind": "text", "multiline": true, "max_length": 4000, "order": 0,
		"tooltip": "面向观众说明能力规则、有效目标、结果和限制；不要写具体数值、配置原理或画面与声音表现。",
	})
	_register_setting("max_hp", {
		"label": "生命值", "group": "基础属性", "default": max_hp,
		"min": 1.0, "max": 10000.0, "step": 1.0, "kind": "float", "order": 10,
	})
	_register_setting("speed", {
		"label": "移动速度", "group": "基础属性", "default": speed,
		"min": 20.0, "max": 1000.0, "step": 1.0, "kind": "float", "order": 20,
	})
	_register_setting("radius", {
		"label": "本体半径", "group": "基础属性", "default": radius,
		"min": 8.0, "max": 80.0, "step": 1.0, "kind": "float", "order": 30,
	})
	_register_setting("cooldown", {
		"label": "技能冷却", "group": "基础属性", "default": cooldown,
		"min": 0.1, "max": 60.0, "step": 0.05, "kind": "float", "order": 40,
		"suffix": " 秒",
	})
	var tuning: Dictionary = config.get("tuning", {})
	for key in tuning:
		_register_setting(String(key), tuning[key])
	apply_settings({})

func create_ability():
	assert(ability_script != null and ability_script.can_instantiate(), "%s ability script cannot instantiate" % id)
	var ability = ability_script.new()
	ability.configure(self)
	return ability

func create_visual(runtime_ability: BallAbility = null):
	assert(visual_script != null and visual_script.can_instantiate(), "%s visual script cannot instantiate" % id)
	var visual = visual_script.new()
	visual.configure(self, runtime_ability)
	return visual

func fighter_spec() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"color": color,
		"accent": accent,
		"max_hp": max_hp,
		"speed": speed,
		"radius": radius,
		"cooldown": cooldown,
		"minimum_speed": speed,
		"maximum_speed": speed,
	}

func apply_settings(overrides: Dictionary) -> void:
	for key in _setting_specs:
		var spec: Dictionary = _setting_specs[key]
		_setting_values[key] = _normalize_setting_value(spec, overrides.get(key, spec["default"]))
	max_hp = settingf("max_hp")
	speed = settingf("speed")
	radius = settingf("radius")
	cooldown = settingf("cooldown")
	ability_description = sanitize_ability_text(String(setting("ability_description")))
	if not ability_text_is_public_safe(ability_description):
		ability_description = sanitize_ability_text(
			String(_setting_specs["ability_description"]["default"])
		).strip_edges()
	_setting_values["ability_description"] = ability_description

func setting(key: String):
	assert(_setting_values.has(key), "%s has no setting %s" % [id, key])
	return _setting_values[key]

func settingf(key: String) -> float:
	return float(setting(key))

func settingi(key: String) -> int:
	return int(setting(key))

func setting_specs() -> Dictionary:
	return _setting_specs.duplicate(true)

func ordered_setting_keys() -> Array[String]:
	var keys: Array[String] = []
	for key in _setting_specs:
		keys.append(String(key))
	keys.sort_custom(func(left: String, right: String) -> bool:
		var left_order := int(_setting_specs[left].get("order", 0))
		var right_order := int(_setting_specs[right].get("order", 0))
		return left_order < right_order if left_order != right_order else left < right
	)
	return keys

func settings_snapshot() -> Dictionary:
	return _setting_values.duplicate(true)

func default_settings_snapshot() -> Dictionary:
	var result := {}
	for key in _setting_specs:
		result[key] = _setting_specs[key]["default"]
	return result

func formatted_ability_description() -> String:
	var source := sanitize_ability_text(ability_description).strip_edges()
	if source.is_empty():
		return source
	if source.contains("\n"):
		return source
	var summary := ""
	var details: Array[String] = []
	for raw_sentence in source.split("。", false):
		for raw_clause in String(raw_sentence).split("；", false):
			var clause := String(raw_clause).strip_edges()
			if clause.is_empty():
				continue
			if summary.is_empty():
				summary = _complete_description_item(clause)
			else:
				details.append(_complete_description_item(clause))
	if summary.is_empty() or details.is_empty():
		return source
	var detail_lines := PackedStringArray()
	for detail in details:
		detail_lines.append("• %s" % detail)
	return "%s\n\n%s" % [summary, "\n".join(detail_lines)]

static func ability_text_looks_corrupted(text: String) -> bool:
	if sanitize_ability_text(text) != text:
		return true
	for marker in [String.chr(0xfffd), "Ã", "Â", "â€", "ðŸ", "ã€", "ï¼"]:
		if text.contains(marker):
			return true
	var latin_lead_count := 0
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if codepoint >= 0x80 and codepoint <= 0x9f:
			return true
		if codepoint in [0x00e5, 0x00e6, 0x00e7, 0x00e8, 0x00e9]:
			latin_lead_count += 1
	return latin_lead_count >= 2

static func ability_text_contains_tuning_details(text: String) -> bool:
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if codepoint >= 0x30 and codepoint <= 0x39:
			return true
	var chinese_value_pattern := RegEx.new()
	chinese_value_pattern.compile("[零一二三四五六七八九十百千万两半]+(秒|毫秒|点伤害|点生命|像素|度|倍|％|%)")
	if chinese_value_pattern.search(text) != null:
		return true
	for marker in [
		"冷却时间为", "伤害为", "速度为", "范围为", "概率为", "权重为",
		"倍率为", "生命为", "数量为", "半径为", "持续时间为", "间隔为",
	]:
		if text.contains(marker):
			return true
	return false

static func ability_text_contains_presentation_details(text: String) -> bool:
	for marker in [
		"特效", "画面", "视觉", "外观", "模型", "配色", "颜色", "图标", "文字提示",
		"招式名", "字幕", "粒子", "残影", "发光", "闪光", "描边", "透明度", "动画",
		"放大", "缩小", "语音", "音效", "声音", "鸣笛", "亮出", "显示在",
	]:
		if text.contains(marker):
			return true
	return false

static func ability_text_contains_internal_details(text: String) -> bool:
	for marker in [
		"可配置", "配置项", "配置页", "持久化", "实现原理", "内部判定", "开发术语",
		"参数面板", "Schema", "schema",
	]:
		if text.contains(marker):
			return true
	return false

static func ability_text_is_public_safe(text: String) -> bool:
	return not ability_text_looks_corrupted(text) \
		and not ability_text_contains_tuning_details(text) \
		and not ability_text_contains_presentation_details(text) \
		and not ability_text_contains_internal_details(text)

static func sanitize_ability_text(text: String) -> String:
	var sanitized := text
	# Public copy stays free of invisible layout controls; UI nodes own wrapping.
	for marker in [String.chr(0x200b), String.chr(0x2060), String.chr(0xfeff)]:
		sanitized = sanitized.replace(marker, "")
	return sanitized

static func _complete_description_item(text: String) -> String:
	var item := text.strip_edges()
	if item.ends_with("。") or item.ends_with("！") or item.ends_with("？"):
		return item
	return "%s。" % item

func audio_samples() -> Dictionary:
	return _audio_samples.duplicate()

func _register_setting(key: String, raw_spec) -> void:
	assert(not key.is_empty() and not _setting_specs.has(key), "%s has duplicate setting %s" % [id, key])
	assert(raw_spec is Dictionary, "%s setting %s must be a dictionary" % [id, key])
	var spec: Dictionary = (raw_spec as Dictionary).duplicate(true)
	assert(spec.has("label") and spec.has("default"), "%s setting %s needs label/default" % [id, key])
	spec["group"] = String(spec.get("group", "能力参数"))
	spec["kind"] = String(spec.get("kind", "float"))
	assert(String(spec["kind"]) in ["float", "int", "text"], "%s setting %s has unsupported kind" % [id, key])
	spec["order"] = int(spec.get("order", 1000))
	if String(spec["kind"]) == "text":
		spec["multiline"] = bool(spec.get("multiline", false))
		spec["max_length"] = maxi(1, int(spec.get("max_length", 1000)))
	else:
		spec["min"] = float(spec.get("min", 0.0))
		spec["max"] = float(spec.get("max", 10000.0))
		spec["step"] = maxf(0.0001, float(spec.get("step", 1.0)))
		assert(float(spec["max"]) >= float(spec["min"]), "%s setting %s has invalid range" % [id, key])
	spec["default"] = _normalize_setting_value(spec, spec["default"])
	_setting_specs[key] = spec

func _normalize_setting_value(spec: Dictionary, raw_value):
	if String(spec["kind"]) == "text":
		var fallback := sanitize_ability_text(String(spec.get("default", ""))).strip_edges()
		var text_value := String(raw_value).strip_edges() if raw_value is String else fallback
		text_value = sanitize_ability_text(text_value)
		text_value = text_value.left(int(spec["max_length"]))
		if text_value.is_empty() or ability_text_looks_corrupted(text_value):
			return fallback
		return text_value
	var numeric := float(spec["default"])
	if raw_value is int or raw_value is float:
		numeric = float(raw_value)
	numeric = clampf(numeric, float(spec["min"]), float(spec["max"]))
	numeric = snappedf(numeric, float(spec["step"]))
	if String(spec["kind"]) == "int":
		return int(round(numeric))
	return numeric

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("module id is empty")
	if display_name.is_empty():
		errors.append("%s display name is empty" % id)
	if max_hp <= 0.0 or speed <= 0.0 or radius <= 0.0 or cooldown <= 0.0:
		errors.append("%s has invalid positive numeric fields" % id)
	if ability_description.strip_edges().is_empty():
		errors.append("%s has no ability description" % id)
	elif ability_text_looks_corrupted(ability_description):
		errors.append("%s ability description contains probable mojibake" % id)
	elif ability_text_contains_tuning_details(ability_description):
		errors.append("%s ability description exposes tunable values" % id)
	elif ability_text_contains_presentation_details(ability_description):
		errors.append("%s ability description narrates visual or audio presentation" % id)
	elif ability_text_contains_internal_details(ability_description):
		errors.append("%s ability description exposes configuration or implementation details" % id)
	if ability_script == null or not ability_script.can_instantiate():
		errors.append("%s has no ability script" % id)
	elif not ability_script.new() is BallAbility:
		errors.append("%s ability script must extend BallAbility" % id)
	if visual_script == null or not visual_script.can_instantiate():
		errors.append("%s has no visual script" % id)
	elif not visual_script.new() is BallVisual:
		errors.append("%s visual script must extend BallVisual" % id)
	for event_kind in _audio_samples:
		if String(event_kind).is_empty():
			errors.append("%s has an empty audio event key" % id)
		elif not _audio_samples[event_kind] is Dictionary:
			errors.append("%s audio event %s must provide a sample specification" % [id, event_kind])
		else:
			var sample_spec: Dictionary = _audio_samples[event_kind]
			if not sample_spec.get("stream") is AudioStream:
				errors.append("%s audio event %s must provide an AudioStream" % [id, event_kind])
			var gain_db = sample_spec.get("gain_db")
			if not (gain_db is int or gain_db is float):
				errors.append("%s audio event %s must provide a numeric gain_db" % [id, event_kind])
			var looped = sample_spec.get("loop", false)
			if not looped is bool:
				errors.append("%s audio event %s loop flag must be boolean" % [id, event_kind])
	return errors
