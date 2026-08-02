extends Base_Spell
class_name WormholeSpell

const VALID_COLOR := Color(0.2, 0.95, 0.35, 0.95)
const INVALID_COLOR := Color(0.95, 0.2, 0.15, 0.95)

@export var radius : float = 150.0
@export var max_range : float = 600.0

var _source_position : Vector2
var _pending_source : Vector2
var _pending_destination : Vector2
var _has_source : bool = false
var _source_indicator : SpellPreviewCircle
var _destination_indicator : SpellPreviewCircle
var _indicator_line : Line2D


func handles_casting_input() -> bool:
	return true


func on_casting_click(world_pos: Vector2) -> Dictionary:
	if not _has_source:
		_source_position = world_pos
		_has_source = true
		preview(world_pos)
		return {"consume_spell": false, "exit_casting": false}
	if _source_position.distance_to(world_pos) > max_range:
		return {"consume_spell": false, "exit_casting": false}
	_pending_source = _source_position
	_pending_destination = world_pos
	_update_destination_preview(world_pos)
	return {"consume_spell": true, "exit_casting": true}


func on_casting_cancel() -> void:
	_has_source = false
	clear_preview()


func preview(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	if not is_instance_valid(_source_indicator):
		_source_indicator = _make_circle(Color(0.25, 0.8, 1.0, 0.25), Color(0.2, 0.7, 1.0, 0.9))
		unit_parent.add_child(_source_indicator)
	if not _has_source:
		_source_indicator.global_position = world_pos
		return
	_source_indicator.global_position = _source_position
	_update_destination_preview(world_pos)


func _update_destination_preview(world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	var valid = _source_position.distance_to(world_pos) <= max_range
	var color = VALID_COLOR if valid else INVALID_COLOR
	if not is_instance_valid(_destination_indicator):
		_destination_indicator = _make_circle(Color(color.r, color.g, color.b, 0.22), color)
		unit_parent.add_child(_destination_indicator)
	if not is_instance_valid(_indicator_line):
		_indicator_line = Line2D.new()
		_indicator_line.width = 4.0
		_indicator_line.z_index = 100
		unit_parent.add_child(_indicator_line)
	_destination_indicator.global_position = world_pos
	_destination_indicator.stroke_color = color
	_destination_indicator.fill_color = Color(color.r, color.g, color.b, 0.22)
	_destination_indicator.queue_redraw()
	_indicator_line.points = PackedVector2Array([_source_position, world_pos])
	_indicator_line.default_color = color


func lock_cast_indicator(_world_pos: Vector2) -> void:
	pass


func cast(_world_pos: Vector2) -> void:
	var unit_parent = battle_manager.get_node_or_null("Unit_Parent") if battle_manager else null
	if unit_parent == null:
		return
	var offset = _pending_destination - _pending_source
	var units: Array[Base_Unit] = []
	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var unit: Base_Unit = child
		if not can_affect_unit(unit):
			continue
		if unit.global_position.distance_to(_pending_source) <= radius:
			units.append(unit)
	for unit in units:
		unit.global_position += offset
	battle_manager.update_tiles()


func clear_preview() -> void:
	for indicator in [_source_indicator, _destination_indicator, _indicator_line]:
		if is_instance_valid(indicator):
			indicator.queue_free()
	_source_indicator = null
	_destination_indicator = null
	_indicator_line = null


func _make_circle(fill: Color, stroke: Color) -> SpellPreviewCircle:
	var circle = SpellPreviewCircle.new()
	circle.radius = radius
	circle.fill_color = fill
	circle.stroke_color = stroke
	circle.z_index = 100
	return circle
