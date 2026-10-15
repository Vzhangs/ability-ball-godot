extends BallVisual

func trail_alpha() -> float:
	return 0.12

func draw_underlay(canvas: CanvasItem, _fighter, context: Dictionary) -> void:
	if ability == null or not ability.call("is_armed"):
		return
	var center: Vector2 = context["position"]
	var scale_factor: float = context["radius"] / module.radius
	var progress: float = ability.call("fuse_progress")
	canvas.draw_arc(center, module.settingf("blast_radius") * scale_factor, -PI * 0.5,
		-PI * 0.5 + TAU * maxf(0.001, progress), 64, Color(0.8, 1.0, 0.65, 0.3), 1.5, true)

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var progress: float = ability.call("fuse_progress") if ability != null else 0.0
	var flashing := progress > 0.0 and sin(progress * progress * 65.0) > 0.0
	var body: Color = fighter.color.lerp(Color.WHITE, 0.85 if flashing else 0.0)
	Surface.draw(canvas, center, radius, body, fighter.accent, Surface.Style.SOLID, context["elapsed"])
	var unit := radius / 5.0
	for y in range(-4, 5):
		for x in range(-4, 5):
			if Vector2(x, y).length() > 3.8 or (x * 7 + y * 13) % 5 != 0:
				continue
			canvas.draw_rect(Rect2(center + Vector2(x, y) * unit, Vector2.ONE * unit), body.lightened(0.2))
	canvas.draw_circle(center, radius, fighter.accent, false, 2.2)
	var face := ["1100011", "1100011", "0011100", "0111110", "0111110", "0100010"]
	for y in range(face.size()):
		for x in range(7):
			if face[y][x] == "1":
				canvas.draw_rect(Rect2(center + Vector2(x - 3.5, y - 3.4) * unit,
					Vector2.ONE * (unit + 0.2)), Color("142218"))
