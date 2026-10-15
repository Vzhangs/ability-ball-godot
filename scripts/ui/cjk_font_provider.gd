class_name CjkFontProvider
extends RefCounted

const FONT_FAMILIES := [
	"Hiragino Sans GB",
	"Arial Unicode MS",
	"Noto Sans CJK SC",
	"Noto Sans SC",
	"Source Han Sans SC",
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"WenQuanYi Micro Hei",
]

static var _ui_font: SystemFont

static func font() -> Font:
	if _ui_font == null:
		_ui_font = SystemFont.new()
		_ui_font.font_names = PackedStringArray(FONT_FAMILIES)
		_ui_font.allow_system_fallback = true
	return _ui_font

static func missing_characters(source: String) -> String:
	var active_font := font()
	var missing := ""
	var seen := {}
	for index in range(source.length()):
		var codepoint := source.unicode_at(index)
		if codepoint <= 0x20 or seen.has(codepoint):
			continue
		seen[codepoint] = true
		if not active_font.has_char(codepoint):
			missing += String.chr(codepoint)
	return missing

static func validation_source(modules: Array) -> String:
	var source := ""
	for module: BallModule in modules:
		source += module.display_name
		source += module.ability_description
	return source
