## Draws a health bar above the unit; only visible after the unit has taken damage.
extends Node2D

const BAR_WIDTH := 24.0
const BAR_HEIGHT := 4.0
const Y_OFFSET := -14.0

var _unit: Base_Unit


func _ready() -> void:
	_unit = get_parent() as Base_Unit
	position = Vector2(0, Y_OFFSET)
	visible = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_unit):
		return
	if _unit.curr_hp < _unit.max_hp:
		visible = true
		queue_redraw()
	else:
		visible = false


func _draw() -> void:
	if not is_instance_valid(_unit) or _unit.max_hp <= 0:
		return
	var ratio := clampf(float(_unit.curr_hp) / float(_unit.max_hp), 0.0, 1.0)
	var half_w := BAR_WIDTH / 2.0
	# Background
	draw_rect(Rect2(-half_w, 0, BAR_WIDTH, BAR_HEIGHT), Color(0.2, 0.2, 0.2, 0.9))
	# Fill
	draw_rect(Rect2(-half_w, 0, BAR_WIDTH * ratio, BAR_HEIGHT), Color(0.2, 0.8, 0.2, 0.95))
