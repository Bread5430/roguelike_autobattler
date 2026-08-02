extends Base_Spell
class_name CircularAoESpell

@export var radius : float = 150.0
@export var damage : int = 25

var _preview_indicator : Node2D

func _get_unit_parent() -> Node:
	if not battle_manager:
		return null
	return battle_manager.get_node_or_null("Unit_Parent")

func preview(world_pos: Vector2) -> void:
	var unit_parent = _get_unit_parent()
	if not unit_parent:
		return
	if not is_instance_valid(_preview_indicator):
		_preview_indicator = _make_preview_node()
		unit_parent.add_child(_preview_indicator)
	_preview_indicator.global_position = world_pos
	_preview_indicator.visible = true

func cast(world_pos: Vector2) -> void:
	var unit_parent = _get_unit_parent()
	if not unit_parent:
		return
	for child in unit_parent.get_children():
		if child is Base_Unit:
			var dist = child.global_position.distance_to(world_pos)
			if dist <= radius:
				deal_spell_damage(child as Base_Unit, damage)

func clear_preview() -> void:
	if is_instance_valid(_preview_indicator):
		_preview_indicator.visible = false
		_preview_indicator.queue_free()
		_preview_indicator = null

func _make_preview_node() -> Node2D:
	var circle = SpellPreviewCircle.new()
	circle.name = "SpellPreviewIndicator"
	circle.z_index = 100
	circle.radius = radius
	return circle
