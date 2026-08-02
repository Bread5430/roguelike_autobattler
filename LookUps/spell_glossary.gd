extends Node

const CSV_PATH := "res://Data/spell_glossary.csv"

var entries : Dictionary = {}


func _ready() -> void:
	_load_csv()


func _load_csv() -> void:
	entries.clear()
	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open spell glossary: %s" % CSV_PATH)
		return
	if not file.eof_reached():
		file.get_csv_line()
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.is_empty():
			continue
		if line.size() < 5:
			push_warning("Spell glossary row too short (%d cols): %s" % [line.size(), line])
			continue
		var spell_id = str(line[0]).strip_edges()
		if spell_id.is_empty():
			continue
		entries[spell_id] = {
			"display_name": str(line[1]),
			"explanation_blurb": str(line[2]),
			"mana_cost": int(line[3]),
			"cooldown": int(line[4])
		}
	file.close()


func has_entry(spell_id: String) -> bool:
	return not spell_id.is_empty() and entries.has(spell_id)


func get_entry(spell_id: String) -> Dictionary:
	if has_entry(spell_id):
		return entries[spell_id].duplicate()
	return {}
