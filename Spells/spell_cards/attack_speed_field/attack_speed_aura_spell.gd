extends Base_Spell
class_name AttackSpeedAuraSpell

@export var radius: float = 180.0
@export var refresh_duration: float = 2.0

var _preview_indicator: Node2D


func _get_unit_parent() -> Node:
	if not battle_manager:
		return null
	return battle_manager.get_node_or_null("Unit_Parent")


func preview(world_pos: Vector2) -> void:
	var unit_parent := _get_unit_parent()
	if not unit_parent:
		return
	if not is_instance_valid(_preview_indicator):
		_preview_indicator = _make_preview_node()
		unit_parent.add_child(_preview_indicator)
	_preview_indicator.global_position = world_pos
	_preview_indicator.visible = true


func cast(world_pos: Vector2) -> void:
	var unit_parent := _get_unit_parent()
	if not unit_parent:
		return
	var aura := AttackSpeedAuraField.new()
	aura.battle_manager = battle_manager
	aura.radius = radius
	aura.refresh_duration = refresh_duration
	aura.global_position = world_pos
	unit_parent.add_child(aura)


func clear_preview() -> void:
	if is_instance_valid(_preview_indicator):
		_preview_indicator.visible = false
		_preview_indicator.queue_free()
		_preview_indicator = null


func _make_preview_node() -> Node2D:
	var circle := SpellPreviewCircle.new()
	circle.name = "SpellPreviewIndicator"
	circle.z_index = 100
	circle.radius = radius
	circle.fill_color = Color(0.25, 0.55, 1.0, 0.28)
	circle.stroke_color = Color(0.2, 0.45, 1.0, 0.85)
	return circle
