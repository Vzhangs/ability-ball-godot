extends RefCounted

const Glow := preload("res://scripts/balls/core/combat_glow.gd")

var _halos := MultiMesh.new()
var _streaks := MultiMesh.new()
var _cores := MultiMesh.new()

func _init(capacity: int) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	for batch in [_halos, _streaks, _cores]:
		batch.transform_format = MultiMesh.TRANSFORM_2D
		batch.use_colors = true
		batch.mesh = quad
		batch.instance_count = capacity
		batch.visible_instance_count = 0

func draw(canvas: CanvasItem, particles: Array[Dictionary], origin: Vector2, scale_factor: float) -> void:
	var count := mini(particles.size(), _halos.instance_count)
	for batch in [_halos, _streaks, _cores]:
		batch.visible_instance_count = count
	if count == 0:
		return
	for index in range(count):
		var particle := particles[index]
		var life := clampf(float(particle.ttl) / float(particle.duration), 0.0, 1.0)
		var color: Color = particle.color
		var center: Vector2 = origin + Vector2(particle.pos) * scale_factor
		var radius := maxf(0.35, float(particle.size) * scale_factor * (0.35 + life * 0.65))
		var velocity: Vector2 = particle.velocity
		var direction := velocity.normalized() if velocity.length_squared() > 0.01 else Vector2.RIGHT
		var tail := minf(velocity.length(), 240.0) * scale_factor * 0.055
		_set_particle(_halos, index, center, direction, Vector2.ONE * radius * 4.0, Color(color, color.a * life * 0.28))
		_set_particle(_streaks, index, center - direction * tail * 0.3, direction, Vector2(radius * 1.3 + tail * 0.6, radius * 0.85), Color(color, color.a * life))
		_set_particle(_cores, index, center, direction, Vector2.ONE * radius * 0.72, Color(color.lerp(Color.WHITE, 0.80), color.a * life))
	# Three instanced submissions regardless of particle count; buffers are reused.
	canvas.draw_multimesh(_halos, Glow.texture())
	canvas.draw_multimesh(_streaks, Glow.texture())
	canvas.draw_multimesh(_cores, Glow.texture())

func _set_particle(batch: MultiMesh, index: int, center: Vector2, direction: Vector2, extent: Vector2, color: Color) -> void:
	batch.set_instance_transform_2d(index, Transform2D(direction * extent.x, direction.orthogonal() * extent.y, center))
	batch.set_instance_color(index, color)
