extends Node

## Autoload: random event definitions from [member EVENTS_CSV_PATH] and choice rows from [member CHOICES_CSV_PATH].

const EVENTS_CSV_PATH := "res://Data/random_events.csv"
const CHOICES_CSV_PATH := "res://Data/random_event_choices.csv"

var events: Dictionary = {} ## event_id -> Dictionary (column name -> string value)
var choices_by_event: Dictionary = {} ## event_id -> Array[Dictionary]


func _ready() -> void:
	_load_csvs()


func _load_csvs() -> void:
	events.clear()
	choices_by_event.clear()
	_load_events_csv()
	_load_choices_csv()


func _load_events_csv() -> void:
	var file := FileAccess.open(EVENTS_CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open random events data: %s" % EVENTS_CSV_PATH)
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
		var eid := str(row.get("event_id", "")).strip_edges()
		if eid.is_empty():
			continue
		events[eid] = row
	file.close()


func _load_choices_csv() -> void:
	var file := FileAccess.open(CHOICES_CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open random event choices data: %s" % CHOICES_CSV_PATH)
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
		var eid := str(row.get("event_id", "")).strip_edges()
		if eid.is_empty():
			continue
		if not choices_by_event.has(eid):
			choices_by_event[eid] = []
		choices_by_event[eid].append(row)
	file.close()


func has_event(event_id: String) -> bool:
	return event_id != "" and events.has(event_id)


func get_event(event_id: String) -> Dictionary:
	if has_event(event_id):
		return events[event_id].duplicate()
	return {}


func get_choices_for_event(event_id: String) -> Array:
	if choices_by_event.has(event_id):
		var out: Array = []
		for row in choices_by_event[event_id]:
			out.append((row as Dictionary).duplicate())
		return out
	return []


func get_all_event_ids() -> Array[String]:
	var ids: Array[String] = []
	for eid in events.keys():
		ids.append(str(eid))
	return ids
