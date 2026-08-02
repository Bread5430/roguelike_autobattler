extends Base_Spell
class_name DotRampSpell

@export var radius: float = 140.0

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
	var def := StatusEffectLibrary.dot_damage_ramp()
	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var u: Base_Unit = child
		if u.global_position.distance_to(world_pos) <= radius:
			var sk = "dot_%d" % u.get_instance_id()
			apply_spell_status(u, def, sk, 1, def.default_duration)


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
	circle.fill_color = Color(1.0, 0.35, 0.15, 0.3)
	circle.stroke_color = Color(1.0, 0.25, 0.1, 0.9)
	return circle
