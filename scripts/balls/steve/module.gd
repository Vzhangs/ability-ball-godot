extends BallModule

const AbilityScript := preload("res://scripts/balls/steve/ability.gd")
const VisualScript := preload("res://scripts/balls/steve/visual.gd")
const Art := preload("res://scripts/balls/steve/material_art.gd")
const Audio := preload("res://scripts/balls/steve/audio_catalog.gd")

func _init() -> void:
	var tuning := {
		"block_radius": _spec("方块半边长", 16.0, 6.0, 60.0, 1.0, 110, "方块"),
		"maximum_blocks": _spec("在场方块上限", 48, 1, 1000, 1, 120, "方块"),
		"block_pickup_delay": _spec("放置后拾取保护时间", 1.0, 0.1, 10.0, 0.1, 125, "方块"),
		"block_collision_wear": _spec("每次受撞耐久损耗", 1.0, 0.0, 1000.0, 0.5, 130, "方块"),
		"contact_release_margin": _spec("脱离接触的额外距离", 1.0, 0.1, 10.0, 0.1, 140, "碰撞"),
		"first_sword_probability": _spec("首次取装为剑的概率", 0.5, 0.0, 1.0, 0.05, 150, "装备"),
		"sword_length": _spec("剑身长度", 42.0, 8.0, 200.0, 1.0, 160, "装备"),
		"sword_width": _spec("剑身宽度", 10.0, 2.0, 40.0, 1.0, 170, "装备"),
		"block_growth_duration": _spec("方块生成动画时长", 0.32, 0.05, 3.0, 0.01, 410, "视觉表现"),
		"cast_icon_duration": _spec("放置与取装标识时长", 0.48, 0.1, 3.0, 0.02, 420, "视觉表现"),
	}
	var sword_damage := [3.0, 5.0, 7.0, 9.0, 12.0, 16.0]
	var armor_reduction := [8.0, 16.0, 24.0, 32.0, 40.0, 48.0]
	var spawn_weights := [40.0, 25.0, 16.0, 10.0, 6.0, 3.0]
	for tier in range(Art.IDS.size()):
		var prefix: String = Art.IDS[tier]
		var material_name: String = Art.NAMES[tier]
		tuning[prefix + "_spawn_weight"] = _spec(material_name + "方块出现权重", spawn_weights[tier], 0.0, 1000.0, 1.0, 180 + tier, "方块概率")
		tuning[prefix + "_block_durability"] = _spec(material_name + "方块耐久", float(tier + 1), 1.0, 1000.0, 1.0, 210 + tier * 3, "材质成长")
		tuning[prefix + "_sword_damage"] = _spec(material_name + "剑伤害", sword_damage[tier], 0.0, 1000.0, 0.5, 211 + tier * 3, "材质成长")
		var armor_spec := _spec(material_name + "盔甲减伤", armor_reduction[tier], 0.0, 95.0, 1.0, 212 + tier * 3, "材质成长")
		armor_spec["suffix"] = "%"
		tuning[prefix + "_armor_reduction"] = armor_spec
	super({
		"id": "steve", "name": "史蒂夫球",
		"color": "20a9b2", "accent": "82e9df", "title_color": "72e6d8",
		"max_hp": 100.0, "speed": 190.0, "radius": 28.0, "cooldown": 4.0,
		"sound_kind": "", "sort_order": 260,
		"audio_samples": Audio.SAMPLES,
		"ability": "史蒂夫会沿途放置资源方块，材质从木头、石头、铁、金、钻石、下界合金中随机产生，高级材质更稀有。刚放下的方块不能立即拾取，保护结束后完全离开并再碰到自己放置的方块，就能取走装备，方块随即消失，不需要先将它打碎。靠墙或落点被占用时会等待可放置的空位。\n\n• 首次取装随机获得剑或盔甲；只持有其中一种时补齐另一种，两种都有后交替尝试升级。装备只升不降，低级材料不会替换高级装备，但取装仍会消耗方块。\n• 剑会伤害接触到的敌方主球和附属单位，持续贴着剑不会反复受伤；盔甲降低受到的伤害，材质越高级，攻防能力越强。\n• 敌方单位碰到方块会被弹开，并损耗方块耐久；攻击也能破坏方块。方块属于有耐久的地形，不提供可抽取的生命。方块不会主动伤人，被夺取或吞噬后也无法再为原主人提供装备。",
		"tuning": tuning,
	}, AbilityScript, VisualScript)

func _spec(label: String, value, minimum, maximum, step_value, order: int, group: String) -> Dictionary:
	return {"label": label, "default": value, "min": minimum, "max": maximum, "step": step_value,
		"kind": "int" if value is int else "float", "order": order, "group": group}
