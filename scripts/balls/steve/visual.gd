extends BallVisual

const Art := preload("res://scripts/balls/steve/material_art.gd")

func draw_ball(canvas: CanvasItem, fighter, context: Dictionary) -> void:
	var center: Vector2 = context["position"]
	var radius: float = context["radius"]
	var sword := int(ability.call("sword_tier")) if ability != null else -1
	var armor := int(ability.call("armor_tier")) if ability != null else -1
	Surface.draw(canvas, center, radius, Color("20a9b2"), Color("a4e9e5"), Surface.Style.SOLID, context["elapsed"])
	canvas.draw_circle(center, radius, Color("a4e9e5"), false, maxf(1.1, radius * 0.075))
	canvas.draw_arc(center, radius * 0.80, 0.43, PI - 0.43, 12, Color("454796"), radius * 0.22, false)
	# Pixel face stays upright while the held weapon aims independently.
	var face := Rect2(center + Vector2(-0.64, -0.77) * radius, Vector2(1.28, 1.19) * radius)
	canvas.draw_rect(face, Color("573a2c"))
	canvas.draw_rect(Rect2(face.position + Vector2(0.11, 0.25) * radius, Vector2(1.06, 0.83) * radius), Color("bd8662"))
	canvas.draw_rect(Rect2(center + Vector2(-0.5, -0.42) * radius, Vector2(0.24, 0.14) * radius), Color("efeddb"))
	canvas.draw_rect(Rect2(center + Vector2(0.26, -0.42) * radius, Vector2(0.24, 0.14) * radius), Color("efeddb"))
	canvas.draw_rect(Rect2(center + Vector2(-0.37, -0.42) * radius, Vector2(0.11, 0.14) * radius), Color("4645a1"))
	canvas.draw_rect(Rect2(center + Vector2(0.26, -0.42) * radius, Vector2(0.11, 0.14) * radius), Color("4645a1"))
	canvas.draw_rect(Rect2(center + Vector2(-0.15, -0.17) * radius, Vector2(0.3, 0.18) * radius), Color("8c533c"))
	canvas.draw_rect(Rect2(center + Vector2(-0.4, 0.01) * radius, Vector2(0.8, 0.33) * radius), Color("553327"))
	canvas.draw_rect(Rect2(center + Vector2(-0.18, 0.01) * radius, Vector2(0.36, 0.12) * radius), Color("bc8362"))
	if armor >= 0:
		Art.draw_armor(canvas, center + Vector2(0, radius * 0.54), radius * 0.56, armor)
	if sword >= 0:
		var direction: Vector2 = ability.call("sword_direction")
		var scale := radius / maxf(0.001, module.radius)
		Art.draw_sword(canvas, center + direction * radius, direction, module.settingf("sword_length") * scale, module.settingf("sword_width") * scale, sword)
