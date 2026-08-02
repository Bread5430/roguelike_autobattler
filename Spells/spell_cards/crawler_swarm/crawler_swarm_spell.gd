extends Base_Spell
class_name CrawlerSwarmSpell

@export var radius : float = 150.0
@export var zone_duration : float = 10.0

var _preview_indicator : Node2D


func preview(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	if not is_instance_valid(_preview_indicator):
		_preview_indicator = SpellPreviewCircle.new()
		_preview_indicator.z_index = 100
		_preview_indicator.radius = radius
		_preview_indicator.fill_color = Color(0.45, 0.8, 0.3, 0.25)
		_preview_indicator.stroke_color = Color(0.35, 0.7, 0.2, 0.9)
		unit_parent.add_child(_preview_indicator)
	_preview_indicator.global_position = world_pos


func cast(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	var zone = CrawlerSwarmZone.new()
	zone.battle_manager = battle_manager
	zone.radius = radius
	zone.lifetime = zone_duration
	zone.position = world_pos
	unit_parent.add_child(zone)


func clear_preview() -> void:
	if is_instance_valid(_preview_indicator):
		_preview_indicator.queue_free()
	_preview_indicator = null
