extends Node

## Run-persistent mapping: base unit card item id -> chosen upgrade path (path_a / path_b).

var _choices: Dictionary = {} ## String base_item_id -> String path


func has_upgrade(base_id: String) -> bool:
	return _choices.has(base_id)


func get_upgrade_path(base_id: String) -> String:
	return str(_choices.get(base_id, ""))


func apply_path(base_id: String, path: String) -> void:
	if base_id.is_empty() or not UNIT_UPGRADES.is_valid_path(path):
		return
	_choices[base_id] = path


func reset_for_new_campaign() -> void:
	_choices.clear()


func get_upgradeable_pool() -> Array[String]:
	var pool: Array[String] = []
	for base_id in UNIT_UPGRADES.get_all_base_ids():
		if has_upgrade(base_id):
			continue
		pool.append(base_id)
	return pool
