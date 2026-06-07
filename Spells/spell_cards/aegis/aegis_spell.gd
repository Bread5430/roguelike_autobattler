extends Base_Spell
class_name AegisSpell

@export var radius: float = 150.0
@export var shield_duration: float = 1.0

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
	var def := StatusEffectLibrary.aegis()
	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var u: Base_Unit = child
		if not u.faction:
			continue
		if u.global_position.distance_to(world_pos) > radius:
			continue
		u.apply_status_effect(def, "aegis", 1, shield_duration)
	clear_preview()


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
	circle.fill_color = Color(0.3, 0.85, 1.0, 0.25)
	circle.stroke_color = Color(0.2, 0.7, 0.95, 0.9)
	return circle
