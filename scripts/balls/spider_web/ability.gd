extends BallAbility

const WebLineEntityScript := preload("res://scripts/balls/spider_web/web_line_entity.gd")

func automatic_activation_enabled() -> bool:
	return false

func after_wall_hit(
	battle,
	fighter,
	_opponent,
	side: int,
	contact_position: Vector2
) -> bool:
	if fighter.hp <= 0.0:
		return false
	battle.add_entity(WebLineEntityScript.new(side, contact_position, {
		"damage": settingf("web_damage"),
		"collision_half_width": settingf("web_collision_half_width"),
		"body_color": fighter.color,
		"accent_color": fighter.accent,
		"strand_end": fighter.pos,
	}))
	battle.spawn_ring(contact_position, fighter.accent, 2.0, 34.0, 0.24)
	battle.spawn_particles(contact_position, fighter.accent, 5, 82.0)
	battle.emit_combat_event("web_attach", 0.58)
	battle.record_stat("web_lines_created")
	return true
