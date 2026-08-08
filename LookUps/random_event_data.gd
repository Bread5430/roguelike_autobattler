extends Node

## Autoload: random event definitions from [member EVENTS_CSV_PATH] and choice rows from [member CHOICES_CSV_PATH].
## Also loads quest defs/targets from [member QUEST_DEFS_CSV_PATH] and [member QUEST_TARGETS_CSV_PATH].

const EVENTS_CSV_PATH := "res://Data/random_events.csv"
const CHOICES_CSV_PATH := "res://Data/random_event_choices.csv"
const QUEST_DEFS_CSV_PATH := "res://Data/quest_defs.csv"
const QUEST_TARGETS_CSV_PATH := "res://Data/quest_targets.csv"

var events: Dictionary = {} ## event_id -> Dictionary (column name -> string value)
var choices_by_event: Dictionary = {} ## event_id -> Array[Dictionary]
var quest_defs: Dictionary = {} ## quest_id -> Dictionary
var quest_targets_by_quest: Dictionary = {} ## quest_id -> Array[Dictionary]


func _ready() -> void:
	_load_csvs()


func _load_csvs() -> void:
	events.clear()
	choices_by_event.clear()
	quest_defs.clear()
	quest_targets_by_quest.clear()
	_load_events_csv()
	_load_choices_csv()
	_load_quest_defs_csv()
	_load_quest_targets_csv()


func _load_events_csv() -> void:
	var file = FileAccess.open(EVENTS_CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open random events data: %s" % EVENTS_CSV_PATH)
		return
	if file.eof_reached():
		file.close()
		return
	var headers = file.get_csv_line()
	if headers.is_empty():
		file.close()
		return
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(mini(headers.size(), line.size())):
			var col = str(headers[i]).strip_edges()
			row[col] = str(line[i]).strip_edges()
		var eid = str(row.get("event_id", "")).strip_edges()
		if eid.is_empty():
			continue
		if not row.has("event_type") or str(row.get("event_type", "")).is_empty():
			row["event_type"] = "exchange"
		events[eid] = row
	file.close()


func _load_choices_csv() -> void:
	var file = FileAccess.open(CHOICES_CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open random event choices data: %s" % CHOICES_CSV_PATH)
		return
	if file.eof_reached():
		file.close()
		return
	var headers = file.get_csv_line()
	if headers.is_empty():
		file.close()
		return
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(mini(headers.size(), line.size())):
			var col = str(headers[i]).strip_edges()
			row[col] = str(line[i]).strip_edges()
		var eid = str(row.get("event_id", "")).strip_edges()
		if eid.is_empty():
			continue
		if not choices_by_event.has(eid):
			choices_by_event[eid] = []
		choices_by_event[eid].append(row)
	file.close()


func _load_quest_defs_csv() -> void:
	var file = FileAccess.open(QUEST_DEFS_CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open quest defs data: %s" % QUEST_DEFS_CSV_PATH)
		return
	if file.eof_reached():
		file.close()
		return
	var headers = file.get_csv_line()
	if headers.is_empty():
		file.close()
		return
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(mini(headers.size(), line.size())):
			var col = str(headers[i]).strip_edges()
			row[col] = str(line[i]).strip_edges()
		var qid = str(row.get("quest_id", "")).strip_edges()
		if qid.is_empty():
			continue
		quest_defs[qid] = row
	file.close()


func _load_quest_targets_csv() -> void:
	var file = FileAccess.open(QUEST_TARGETS_CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open quest targets data: %s" % QUEST_TARGETS_CSV_PATH)
		return
	if file.eof_reached():
		file.close()
		return
	var headers = file.get_csv_line()
	if headers.is_empty():
		file.close()
		return
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.is_empty():
			continue
		var row: Dictionary = {}
		for i in range(mini(headers.size(), line.size())):
			var col = str(headers[i]).strip_edges()
			row[col] = str(line[i]).strip_edges()
		var qid = str(row.get("quest_id", "")).strip_edges()
		if qid.is_empty():
			continue
		if not quest_targets_by_quest.has(qid):
			quest_targets_by_quest[qid] = []
		quest_targets_by_quest[qid].append(row)
	file.close()


func has_event(event_id: String) -> bool:
	return event_id != "" and events.has(event_id)


func get_event(event_id: String) -> Dictionary:
	if has_event(event_id):
		return events[event_id].duplicate()
	return {}


func get_event_type(event_id: String) -> String:
	var row = get_event(event_id)
	if row.is_empty():
		return ""
	return str(row.get("event_type", "exchange"))


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


func has_quest(quest_id: String) -> bool:
	return quest_id != "" and quest_defs.has(quest_id)


func get_quest_def(quest_id: String) -> Dictionary:
	if has_quest(quest_id):
		return quest_defs[quest_id].duplicate()
	return {}


func get_quest_targets(quest_id: String) -> Array:
	if quest_targets_by_quest.has(quest_id):
		var out: Array = []
		for row in quest_targets_by_quest[quest_id]:
			out.append((row as Dictionary).duplicate())
		return out
	return []


func is_quest_exclusive(quest_id: String) -> bool:
	var def = get_quest_def(quest_id)
	return str(def.get("exclusive_on_complete", "false")).to_lower() == "true"
