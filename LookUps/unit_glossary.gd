extends Node

## Autoload: loads [member CSV_PATH] into [member entries] for unit stats and glossary text.

const CSV_PATH := "res://Data/units_glossary.csv"

var entries: Dictionary = {}


func _ready() -> void:
	_load_csv()


func _load_csv() -> void:
	entries.clear()
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open units glossary: %s" % CSV_PATH)
		return
	if not file.eof_reached():
		file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty():
			continue
		if line.size() < 7:
			push_warning("Glossary row too short (%d cols): %s" % [line.size(), line])
			continue
		var unit_id := str(line[0]).strip_edges()
		if unit_id.is_empty():
			continue
		entries[unit_id] = {
			"display_name": str(line[1]),
			"max_hp": int(line[2]),
			"movement_speed": int(line[3]),
			"damage": int(line[4]),
			"scrap_cost": int(line[5]),
			"explanation_blurb": str(line[6])
		}
	file.close()


func has_entry(unit_id: String) -> bool:
	return unit_id != "" and entries.has(unit_id)


func get_entry(unit_id: String) -> Dictionary:
	if has_entry(unit_id):
		return entries[unit_id].duplicate()
	return {}


func get_scrap_cost(unit_id: String) -> int:
	if has_entry(unit_id):
		return int(entries[unit_id].get("scrap_cost", 0))
	return 0
