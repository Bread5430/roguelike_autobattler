extends Base_Spell
class_name OrbitalStrikeSpell

@export var radius : float = 75.0
@export var warning_duration : float = 2.0
@export var damage : int = 100

var _preview_indicator : Node2D


func preview(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	if not is_instance_valid(_preview_indicator):
		_preview_indicator = SpellPreviewCircle.new()
		_preview_indicator.z_index = 100
		_preview_indicator.radius = radius
		_preview_indicator.fill_color = Color(1.0, 0.2, 0.1, 0.3)
		_preview_indicator.stroke_color = Color(1.0, 0.1, 0.05, 0.95)
		unit_parent.add_child(_preview_indicator)
	_preview_indicator.global_position = world_pos


func cast(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	var marker = OrbitalStrikeMarker.new()
	marker.battle_manager = battle_manager
	marker.radius = radius
	marker.lifetime = warning_duration
	marker.damage = damage
	marker.position = world_pos
	unit_parent.add_child(marker)


func clear_preview() -> void:
	if is_instance_valid(_preview_indicator):
		_preview_indicator.queue_free()
	_preview_indicator = null
