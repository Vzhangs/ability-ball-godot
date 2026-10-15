extends RefCounted

const MATERIALS := ["wood", "stone", "iron", "gold", "diamond", "netherite"]
const SAMPLES := {
	"steve_wood_place": {"stream": preload("res://scripts/balls/steve/audio/wood_place.ogg"), "gain_db": -18.1},
	"steve_wood_break": {"stream": preload("res://scripts/balls/steve/audio/wood_break.ogg"), "gain_db": -14.0},
	"steve_wood_hit": {"stream": preload("res://scripts/balls/steve/audio/wood_hit.ogg"), "gain_db": -18.0},
	"steve_stone_place": {"stream": preload("res://scripts/balls/steve/audio/stone_place.ogg"), "gain_db": -15.9},
	"steve_stone_break": {"stream": preload("res://scripts/balls/steve/audio/stone_break.ogg"), "gain_db": -11.8},
	"steve_stone_hit": {"stream": preload("res://scripts/balls/steve/audio/stone_hit.ogg"), "gain_db": -19.0},
	"steve_netherite_place": {"stream": preload("res://scripts/balls/steve/audio/netherite_place.ogg"), "gain_db": -15.2},
	"steve_netherite_break": {"stream": preload("res://scripts/balls/steve/audio/netherite_break.ogg"), "gain_db": -14.3},
	"steve_netherite_hit": {"stream": preload("res://scripts/balls/steve/audio/netherite_hit.ogg"), "gain_db": -24.1},
	"steve_pickup": {"stream": preload("res://scripts/balls/steve/audio/pickup.ogg"), "gain_db": -20.8},
	"steve_upgrade": {"stream": preload("res://scripts/balls/steve/audio/upgrade.ogg"), "gain_db": -19.4},
	"steve_sword_light": {"stream": preload("res://scripts/balls/steve/audio/sword_light.ogg"), "gain_db": -14.7},
	"steve_sword_heavy": {"stream": preload("res://scripts/balls/steve/audio/sword_heavy.ogg"), "gain_db": -17.7},
	"steve_armor_wood": {"stream": preload("res://scripts/balls/steve/audio/armor_wood.ogg"), "gain_db": -12.2},
	"steve_armor_stone": {"stream": preload("res://scripts/balls/steve/audio/armor_stone.ogg"), "gain_db": -8.2},
	"steve_armor_iron": {"stream": preload("res://scripts/balls/steve/audio/armor_iron.ogg"), "gain_db": -11.7},
	"steve_armor_gold": {"stream": preload("res://scripts/balls/steve/audio/armor_gold.ogg"), "gain_db": -12.1},
	"steve_armor_diamond": {"stream": preload("res://scripts/balls/steve/audio/armor_diamond.ogg"), "gain_db": -8.2},
	"steve_armor_netherite": {"stream": preload("res://scripts/balls/steve/audio/armor_netherite.ogg"), "gain_db": -16.8},
}

static func block_event(action: String, tier: int) -> String:
	var material := "wood" if tier == 0 else ("netherite" if tier == 5 else "stone")
	return "steve_%s_%s" % [material, action]

static func armor_event(tier: int) -> String:
	return "steve_armor_" + MATERIALS[clampi(tier, 0, MATERIALS.size() - 1)]
