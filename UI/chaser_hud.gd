extends PanelContainer
class_name ChaserHUD

@onready var _step_label: Label = $MarginContainer/VBoxContainer/StepLabel
@onready var _end_label: Label = $MarginContainer/VBoxContainer/EndLabel
@onready var _markers_row: HBoxContainer = $MarginContainer/VBoxContainer/MarkersRow


func update_from_state(state: Dictionary) -> void:
	if not is_node_ready():
		return
	var current_step: int = int(state.get("current_step", 0))
	var total_steps: int = maxi(1, int(state.get("total_steps", 1)))
	var end_x: float = float(state.get("end_front_x", 0.0))
	_step_label.text = "Chaser: Step %d / %d" % [current_step, total_steps]
	_end_label.text = "Final position: X=%d" % int(round(end_x))
	_rebuild_markers(current_step, total_steps)


func set_map_visible(show: bool) -> void:
	visible = show


func _rebuild_markers(current_step: int, total_steps: int) -> void:
	for child in _markers_row.get_children():
		child.queue_free()
	for step in range(1, total_steps + 1):
		var marker := Label.new()
		marker.text = str(step)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.custom_minimum_size = Vector2(18, 18)
		if step == current_step:
			marker.add_theme_color_override("font_color", Color.YELLOW)
		elif step < current_step:
			marker.add_theme_color_override("font_color", Color.GRAY)
		_markers_row.add_child(marker)
