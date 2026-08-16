extends BallAbility

const FireZoneEntity := preload("res://scripts/balls/flame/fire_zone_entity.gd")

var _damage_timer := 0.0

func before_motion(_battle, _fighter, _opponent, _side: int, delta: float) -> void:
	_damage_timer = maxf(0.0, _damage_timer - delta)

func on_step(battle, fighter, opponent, side: int, delta: float) -> void:
	if int(battle.elapsed * 8.0) != int((battle.elapsed - delta) * 8.0):
		var zones: Array[BallEntity] = battle.entities(side, "flame_zone")
		if zones.size() >= 42:
			zones[0].removed = true
		battle.add_entity(FireZoneEntity.new(side, fighter.pos, 2.5, 28.0))
	if _damage_timer > 0.0:
		return
	var hit_something := false
	var hit_entities := {}
	for zone: BallEntity in battle.entities(side, "flame_zone"):
		if zone.pos.distance_to(opponent.pos) < zone.radius + opponent.radius:
			battle.damage(opponent, 3.4, fighter.accent, fighter, false)
			hit_something = true
		for entity: BallEntity in battle.damageable_entities_in_circle(side, zone.pos, zone.radius):
			var entity_id := entity.get_instance_id()
			if hit_entities.has(entity_id):
				continue
			hit_entities[entity_id] = true
			battle.damage_entity(entity, 3.4, fighter.accent, side, false)
			hit_something = true
	if hit_something:
		_damage_timer = 0.34
		battle.record_stat("burn_hits")

func activate(battle, fighter, opponent, side: int) -> void:
	battle.spawn_ring(fighter.pos, Color("ff7a24"), fighter.radius, 158.0, 0.72)
	battle.spawn_particles(fighter.pos, Color("ffbd35"), 24, 235.0)
	var hit_something := false
	if fighter.pos.distance_to(opponent.pos) < 195.0:
		battle.damage(opponent, 13.4, fighter.accent, fighter)
		hit_something = true
	for entity: BallEntity in battle.damageable_entities_in_circle(side, fighter.pos, 195.0):
		battle.damage_entity(entity, 13.4, fighter.accent, side)
		hit_something = true
	if hit_something:
		battle.record_stat("burn_hits")
