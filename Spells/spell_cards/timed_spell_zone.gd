extends Node2D
class_name TimedSpellZone

@export var radius : float = 150.0
@export var lifetime : float = 10.0
@export var fill_color : Color = Color(1.0, 1.0, 1.0, 0.2)
@export var outline_color : Color = Color(1.0, 1.0, 1.0, 0.75)

var battle_manager : Node
var elapsed : float = 0.0


func _ready() -> void:
	z_index = -10
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, outline_color, 2.0, true)


func get_unit_parent() -> Node:
	if battle_manager == null:
		return null
	return battle_manager.get_node_or_null("Unit_Parent")
