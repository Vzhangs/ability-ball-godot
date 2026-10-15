extends Control

const GlassShader := preload("res://scripts/ui/hud_glass.gdshader")
var panes: Array[ColorRect] = []
var glass_material := ShaderMaterial.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass_material.shader = GlassShader

func update_bars(bounds: Array) -> void:
	while panes.size() < bounds.size():
		var pane := ColorRect.new()
		pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pane.material = glass_material
		add_child(pane)
		panes.append(pane)
	for index in range(panes.size()):
		panes[index].visible = index < bounds.size()
		if index < bounds.size():
			panes[index].position = bounds[index].position
			panes[index].size = bounds[index].size
