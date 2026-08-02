extends Base_Spell

var _confirmed: Array[Vector2] = []
var _pending_path: PackedVector2Array = PackedVector2Array()
var _preview_indicator: Node2D


func handles_casting_input() -> bool:
	return true


func on_casting_click(world_pos: Vector2) -> Dictionary:
	var bc: BeaconController = battle_manager.beacon_controller
	# Block confirming a segment that exceeds max length (first point has no prior segment).
	if not _confirmed.is_empty() and bc.is_segment_too_long(_confirmed[_confirmed.size() - 1], world_pos):
		return {"consume_spell": false, "exit_casting": false}
	_confirmed.append(world_pos)
	if _confirmed.size() < 3:
		return {"consume_spell": false, "exit_casting": false}
	var path = PackedVector2Array([_confirmed[0], _confirmed[1], _confirmed[2]])
	_confirmed.clear()
	if not _can_commit(path):
		_pending_path = PackedVector2Array()
		return {"consume_spell": false, "exit_casting": true}
	_pending_path = path
	return {"consume_spell": true, "exit_casting": true}


func on_casting_cancel() -> void:
	_confirmed.clear()
	_pending_path = PackedVector2Array()
	clear_preview()
	if battle_manager and battle_manager.beacon_controller:
		battle_manager.beacon_controller.clear_preview_line()


func preview(world_pos: Vector2) -> void:
	if battle_manager == null:
		return
	var bc: BeaconController = battle_manager.beacon_controller
	if bc == null:
		return
	if _confirmed.is_empty():
		# First click preview: show beacon assignment radius at cursor.
		_show_radius_preview(world_pos, bc.assign_radius)
		# Do not draw a full line before the first click.
		bc.clear_preview_line()
		return
	_hide_radius_preview()
	bc.preview_path(_confirmed, world_pos)


func cast(_world_pos: Vector2) -> void:
	if _pending_path.size() < 3:
		return
	_try_commit(_pending_path)
	_pending_path = PackedVector2Array()


func clear_preview() -> void:
	_hide_radius_preview()
	if battle_manager and battle_manager.beacon_controller:
		battle_manager.beacon_controller.clear_preview_line()


func lock_cast_indicator(_world_pos: Vector2) -> void:
	pass


func _show_radius_preview(world_pos: Vector2, radius: float) -> void:
	var unit_parent := battle_manager.get_node("Unit_Parent")
	if not is_instance_valid(_preview_indicator):
		_preview_indicator = _make_preview_node(radius)
		unit_parent.add_child(_preview_indicator)
	var circle := _preview_indicator as SpellPreviewCircle
	if circle:
		circle.radius = radius
	_preview_indicator.global_position = world_pos
	_preview_indicator.visible = true


func _hide_radius_preview() -> void:
	if is_instance_valid(_preview_indicator):
		_preview_indicator.visible = false
		_preview_indicator.queue_free()
	_preview_indicator = null


func _make_preview_node(radius: float) -> Node2D:
	var circle := SpellPreviewCircle.new()
	circle.name = "BeaconPreviewIndicator"
	circle.z_index = 100
	circle.radius = radius
	circle.fill_color = Color(0.35, 0.85, 1.0, 0.24)
	circle.stroke_color = Color(0.35, 0.85, 1.0, 0.9)
	return circle


func _can_commit(path: PackedVector2Array) -> bool:
	var bc: BeaconController = battle_manager.beacon_controller
	var tc: Variant = battle_manager.tactical_cursor
	var sel: Base_Unit = tc.get_selected_unit()
	if sel == null or not sel.faction or sel.curr_hp <= 0:
		return false
	var origin: Vector2 = path[0]
	var assign_r: float = bc.assign_radius
	if sel.global_position.distance_to(origin) > assign_r:
		return false
	var up = battle_manager.unit_parent
	for c in up.get_children():
		if not c is Base_Unit:
			continue
		var u: Base_Unit = c as Base_Unit
		if u.curr_hp <= 0:
			continue
		if u.is_spell_immune():
			continue
		if u.faction != sel.faction:
			continue
		if u.global_position.distance_to(origin) <= assign_r:
			return true
	return false


func _try_commit(path: PackedVector2Array) -> bool:
	if not _can_commit(path):
		return false
	var bc: BeaconController = battle_manager.beacon_controller
	var tc: Variant = battle_manager.tactical_cursor
	var sel: Base_Unit = tc.get_selected_unit()
	var origin: Vector2 = path[0]
	var assign_r: float = bc.assign_radius
	var beaconed_units: Array = []
	var up = battle_manager.unit_parent
	for c in up.get_children():
		if not c is Base_Unit:
			continue
		var u: Base_Unit = c as Base_Unit
		if u.curr_hp <= 0:
			continue
		if u.is_spell_immune():
			continue
		if u.faction != sel.faction:
			continue
		if u.global_position.distance_to(origin) <= assign_r:
			beaconed_units.append(u)
	if beaconed_units.is_empty():
		return false
	return bc.register_beacon(path, beaconed_units) >= 0
