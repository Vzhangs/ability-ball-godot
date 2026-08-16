extends BallAbility

const FireZoneEntity := preload("res://scripts/balls/flame/fire_zone_entity.gd")

var _damage_timer := 0.0

func before_motion(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_damage_timer = maxf(0.0, _damage_timer - delta)

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	var spawn_rate := settingf("trail_spawn_rate")
	if int(battle.elapsed * spawn_rate) != int((battle.elapsed - delta) * spawn_rate):
		var zones: Array[BallEntity] = battle.entities(side, "flame_zone")
		if zones.size() >= settingi("max_fire_zones"):
			zones[0].removed = true
		battle.add_entity(FireZoneEntity.new(side, fighter.pos, {
			"duration": settingf("fire_zone_duration"),
			"radius": settingf("fire_zone_radius"),
			"absorption_radius_cap": settingf("fire_zone_absorption_radius_cap"),
			"absorption_radius_ratio": settingf("fire_zone_absorption_radius_ratio"),
		}))
	if _damage_timer > 0.0:
		return
	var hit_something := false
	var burn_damage := settingf("burn_damage")
	var hit_entities := {}
	for zone: BallEntity in battle.entities(side, "flame_zone"):
		if zone.pos.distance_to(opponent.pos) < zone.radius + opponent.radius:
			battle.damage(opponent, burn_damage, fighter.accent, fighter, false)
			hit_something = true
		for entity: BallEntity in battle.damageable_entities_in_circle(side, zone.pos, zone.radius):
			var entity_id := entity.get_instance_id()
			if hit_entities.has(entity_id):
				continue
			hit_entities[entity_id] = true
			battle.damage_entity(entity, burn_damage, fighter.accent, side, false)
			hit_something = true
	if hit_something:
		_damage_timer = settingf("burn_tick_interval")
		battle.record_stat("burn_hits")

func activate(battle, fighter, opponent, side: int) -> void:
	var burst_radius := settingf("burst_radius")
	var burst_damage := settingf("burst_damage")
	battle.spawn_ring(fighter.pos, Color("ff7a24"), fighter.radius, 158.0, 0.72)
	battle.spawn_particles(fighter.pos, Color("ffbd35"), 24, 235.0)
	var hit_something := false
	if fighter.pos.distance_to(opponent.pos) < burst_radius:
		battle.damage(opponent, burst_damage, fighter.accent, fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, burst_radius):
		battle.damage_entity(entity, burst_damage, fighter.accent, side)
		hit_something = true
	if hit_something:
		battle.record_stat("burn_hits")
