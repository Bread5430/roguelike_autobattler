extends Node2D
class_name SpellPreviewCircle

@export var radius : float = 150.0
@export var fill_color : Color = Color(1, 0.3, 0.2, 0.35)
@export var stroke_color : Color = Color(1, 0.2, 0.1, 0.85)

func _draw():
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, fill_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, stroke_color)

func set_radius(r: float) -> void:
	radius = r
	queue_redraw()
