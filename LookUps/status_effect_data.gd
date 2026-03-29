extends Node

## Autoload: shared status effect data from [member CSV_PATH] ([code]display_name[/code], [code]icon_path[/code], [code]default_duration[/code], [code]max_stacks[/code]).
## Per-effect mechanics and numeric tunables stay on scripted [StatusEffectDef] subclasses ([annotation @export]).

const CSV_PATH := "res://Data/status_effects.csv"

var entries: Dictionary = {} ## effect_id -> Dictionary (column name -> string value)


func _ready() -> void:
	_load_csv()


func _load_csv() -> void:
	entries.clear()
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open status effects data: %s" % CSV_PATH)
		return
	if file.eof_reached():
		file.close()
		return
	var headers := file.get_csv_line()
	if headers.is_empty():
		file.close()
		return
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(mini(headers.size(), line.size())):
			var col := str(headers[i]).strip_edges()
			row[col] = str(line[i]).strip_edges()
		var eid := str(row.get("effect_id", "")).strip_edges()
		if eid.is_empty():
			continue
		entries[eid] = row
	file.close()


func has_entry(effect_id: String) -> bool:
	return effect_id != "" and entries.has(effect_id)


func get_entry(effect_id: String) -> Dictionary:
	if has_entry(effect_id):
		return entries[effect_id].duplicate()
	return {}


func get_display_name(effect_id: StringName) -> String:
	var row := get_entry(str(effect_id))
	var dn := str(row.get("display_name", "")).strip_edges()
	if dn != "":
		return dn
	return str(effect_id)
