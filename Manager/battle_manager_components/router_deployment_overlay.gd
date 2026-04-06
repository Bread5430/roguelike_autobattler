extends Node2D

## Draws router exclusion disks in the same canvas space as the board (follows [Camera2D]), not the [CanvasLayer] GUI.

var _gui: Node


func set_gui(g: Node) -> void:
	_gui = g


func _process(_delta: float) -> void:
	if _gui != null and bool(_gui.deployment_mode):
		queue_redraw()


func _draw() -> void:
	if _gui == null or not _gui.has_method("paint_router_deployment_exclusions_on_canvas_item"):
		return
	_gui.paint_router_deployment_exclusions_on_canvas_item(self)
