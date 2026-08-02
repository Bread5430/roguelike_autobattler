extends Base_Spell
class_name GooSpell

@export var radius : float = 150.0
@export var field_duration : float = 10.0
@export var exit_grace : float = 0.5

var _preview_indicator : Node2D


func preview(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	if not is_instance_valid(_preview_indicator):
		_preview_indicator = SpellPreviewCircle.new()
		_preview_indicator.z_index = 100
		_preview_indicator.radius = radius
		_preview_indicator.fill_color = Color(0.45, 0.9, 0.35, 0.28)
		_preview_indicator.stroke_color = Color(0.35, 0.8, 0.25, 0.9)
		unit_parent.add_child(_preview_indicator)
	_preview_indicator.global_position = world_pos


func cast(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	var field = GooField.new()
	field.battle_manager = battle_manager
	field.radius = radius
	field.lifetime = field_duration
	field.refresh_duration = exit_grace
	unit_parent.add_child(field)
	field.global_position = world_pos


func clear_preview() -> void:
	if is_instance_valid(_preview_indicator):
		_preview_indicator.queue_free()
	_preview_indicator = null
