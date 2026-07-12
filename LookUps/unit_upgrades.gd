extends Node

## Autoload: upgrade path labels, blurbs, and sprite paths keyed by base unit card item id.

const CSV_PATH := "res://Data/unit_upgrades.csv"
const PATH_A := "path_a"
const PATH_B := "path_b"

var entries: Dictionary = {}


func _ready() -> void:
	_load_csv()


func _load_csv() -> void:
	entries.clear()
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open unit upgrades CSV: %s" % CSV_PATH)
		return
	if not file.eof_reached():
		file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty():
			continue
		if line.size() < 7:
			push_warning("Unit upgrade row too short (%d cols): %s" % [line.size(), line])
			continue
		var base_id := str(line[0]).strip_edges()
		if base_id.is_empty():
			continue
		entries[base_id] = {
			"path_a_label": str(line[1]),
			"path_b_label": str(line[2]),
			"path_a_sprite": str(line[3]),
			"path_b_sprite": str(line[4]),
			"path_a_blurb": str(line[5]),
			"path_b_blurb": str(line[6]),
		}
	file.close()


func has_entry(base_id: String) -> bool:
	return base_id != "" and entries.has(base_id)


func get_all_base_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in entries.keys():
		ids.append(str(key))
	return ids


func get_labels(base_id: String) -> Dictionary:
	if not has_entry(base_id):
		return {}
	var e: Dictionary = entries[base_id]
	return {
		PATH_A: str(e.get("path_a_label", "Path A")),
		PATH_B: str(e.get("path_b_label", "Path B")),
	}


func get_blurb(base_id: String, path: String) -> String:
	if not has_entry(base_id):
		return ""
	var e: Dictionary = entries[base_id]
	match path:
		PATH_A:
			return str(e.get("path_a_blurb", ""))
		PATH_B:
			return str(e.get("path_b_blurb", ""))
		_:
			return ""


func get_card_sprite_path(base_id: String, path: String) -> String:
	if not has_entry(base_id):
		return ""
	var e: Dictionary = entries[base_id]
	match path:
		PATH_A:
			return str(e.get("path_a_sprite", ""))
		PATH_B:
			return str(e.get("path_b_sprite", ""))
		_:
			return ""


## Slug derived from a path's label, used to build the AnimatedSprite2D animation
## names for an upgraded unit (e.g. "Berserker Line" -> "berserker_line", so the
## FSM plays "walk_berserker_line" / "die_berserker_line"). Empty when unknown.
func get_animation_key(base_id: String, path: String) -> String:
	var label := str(get_labels(base_id).get(path, "")).strip_edges()
	if label.is_empty():
		return ""
	return label.to_lower().replace(" ", "_")


func is_valid_path(path: String) -> bool:
	return path == PATH_A or path == PATH_B
