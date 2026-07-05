extends Node

const SAVE_PATH := "user://save_slot_0.json"

var pending_load: bool = false
var pending_new_run: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_run(data: Dictionary) -> void:
	# Partial run save: map state, gold, components, current state.
	# TODO: inventory, player health, scrap buffer, spell bar.
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_run() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: failed to open save file for reading")
		return {}
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}
