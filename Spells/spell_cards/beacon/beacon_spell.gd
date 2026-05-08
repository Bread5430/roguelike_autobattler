extends Base_Spell

var _confirmed: Array[Vector2] = []


func handles_casting_input() -> bool:
	return true


func on_casting_click(world_pos: Vector2) -> Dictionary:
	_confirmed.append(world_pos)
	if _confirmed.size() < 3:
		return {"consume_spell": false, "exit_casting": false}
	var path := PackedVector2Array([_confirmed[0], _confirmed[1], _confirmed[2]])
	var ok := _try_commit(path)
	_confirmed.clear()
	clear_preview()
	return {"consume_spell": ok, "exit_casting": true}


func on_casting_cancel() -> void:
	_confirmed.clear()
	if battle_manager and battle_manager.beacon_controller:
		battle_manager.beacon_controller.clear_preview_line()


func preview(world_pos: Vector2) -> void:
	if battle_manager == null:
		return
	var bc: BeaconController = battle_manager.beacon_controller
	if bc == null:
		return
	if _confirmed.is_empty():
		# Do not draw a full line before the first click.
		bc.clear_preview_line()
		return
	bc.preview_path(_confirmed, world_pos)


func cast(_world_pos: Vector2) -> void:
	pass


func clear_preview() -> void:
	if battle_manager and battle_manager.beacon_controller:
		battle_manager.beacon_controller.clear_preview_line()


func _try_commit(path: PackedVector2Array) -> bool:
	var bc: BeaconController = battle_manager.beacon_controller
	var tc: Variant = battle_manager.tactical_cursor
	if tc == null or not tc.has_method("get_selected_unit"):
		return false
	var sel: Base_Unit = tc.get_selected_unit()
	if sel == null or not sel.faction or sel.curr_hp <= 0:
		return false
	var origin: Vector2 = path[0]
	var assign_r: float = bc.assign_radius
	if sel.global_position.distance_to(origin) > assign_r:
		return false
	var allies: Array = []
	var up = battle_manager.unit_parent
	for c in up.get_children():
		if not c is Base_Unit:
			continue
		var u: Base_Unit = c as Base_Unit
		if u.curr_hp <= 0:
			continue
		if u.faction != sel.faction:
			continue
		if u.global_position.distance_to(origin) <= assign_r:
			allies.append(u)
	if allies.is_empty():
		return false
	return bc.register_beacon(path, allies) >= 0
