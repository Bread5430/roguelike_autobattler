extends Node
class_name ShopControl

const UNIT_BASE_PRICE := 100
const SPELL_BASE_PRICE := 75
const UNIT_COUNT := 5
const SPELL_COUNT := 4
const RELIC_COUNT := 3
const UNIT_SALE_INDEX := 4
const SPELL_SALE_INDEX := 3
const RELIC_SALE_INDEX := 2
const REFRESH_COST := 50

var _game_state: Node


func setup(game_state: Node) -> void:
	_game_state = game_state


func generate_stock() -> Dictionary:
	return {
		"units": _build_shop_row(get_unit_pool(), UNIT_COUNT, "unit", UNIT_BASE_PRICE, UNIT_SALE_INDEX),
		"spells": _build_shop_row(get_spell_pool(), SPELL_COUNT, "spell", SPELL_BASE_PRICE, SPELL_SALE_INDEX),
		"relics": _build_relic_row(),
	}


func refresh_stock(stock: Dictionary) -> Dictionary:
	if _game_state == null or not _game_state.spend_gold(REFRESH_COST):
		return stock
	var refreshed := stock.duplicate(true)
	refreshed["units"] = _refresh_shop_row(
		refreshed.get("units", []),
		get_unit_pool(),
		"unit",
		UNIT_BASE_PRICE,
		UNIT_SALE_INDEX
	)
	refreshed["spells"] = _refresh_shop_row(
		refreshed.get("spells", []),
		get_spell_pool(),
		"spell",
		SPELL_BASE_PRICE,
		SPELL_SALE_INDEX
	)
	# TODO: relic item pool + pricing when relics implemented.
	refreshed["relics"] = _build_relic_row()
	return refreshed


func get_item_price(slot_data: Dictionary) -> int:
	var base_price := int(slot_data.get("base_price", 0))
	if slot_data.get("on_sale", false):
		return int(floor(float(base_price) * 0.5))
	return base_price


func try_purchase(slot_data: Dictionary, inventory: Inventory) -> bool:
	if _game_state == null or inventory == null:
		return false
	var price := get_item_price(slot_data)
	if price <= 0:
		return false
	if not _game_state.spend_gold(price):
		return false
	var item_id := str(slot_data.get("item_id", ""))
	if item_id.is_empty():
		return false
	inventory.add_item(item_id, 1)
	return true


func process_scrap(item_id: String, inventory: Inventory) -> int:
	if _game_state == null or inventory == null:
		return 0
	var count := inventory.remove_all_of_item(item_id)
	if count <= 0:
		return 0
	var components := calculate_scrap_components(count, item_id)
	_game_state.add_components(components)
	return components


func calculate_scrap_components(count: int, _item_id: String) -> int:
	# TODO: multiply by item rarity when rarity exists.
	return count


func get_unit_pool() -> Array[String]:
	var pool: Array[String] = []
	for map_item in ITEM_NAME.unit_role_map:
		var item_id: String = map_item[1]
		var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
		if scene == null:
			continue
		var path := scene.resource_path
		if "Spells/" in path:
			continue
		var probe = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		if probe is Unit_Card and (probe as Unit_Card).enemy_formation_only:
			probe.queue_free()
			continue
		if probe:
			probe.queue_free()
		pool.append(item_id)
	return pool


func get_spell_pool() -> Array[String]:
	# TODO: add explicit CSV-defined shop pools when item data supports it.
	var pool: Array[String] = []
	for item_id in ITEM_NAME.name_obj_map:
		var scene: PackedScene = ITEM_NAME.name_obj_map[item_id]
		if scene == null:
			continue
		if "Spells/" in scene.resource_path:
			pool.append(item_id)
	return pool


func _build_shop_row(pool: Array[String], count: int, kind: String, base_price: int, sale_index: int) -> Array:
	var ids := _pick_random_unique_items(pool, count)
	var row: Array = []
	for i in ids.size():
		row.append({
			"kind": kind,
			"item_id": ids[i],
			"base_price": base_price,
			"on_sale": i == sale_index,
			"sold": false,
		})
	return row


func _build_relic_row() -> Array:
	# TODO: relic item pool + pricing when relics implemented.
	var row: Array = []
	for i in RELIC_COUNT:
		row.append({
			"kind": "relic",
			"item_id": "",
			"base_price": 0,
			"on_sale": i == RELIC_SALE_INDEX,
			"sold": false,
		})
	return row


func _refresh_shop_row(row: Array, pool: Array[String], kind: String, base_price: int, sale_index: int) -> Array:
	var refreshed: Array = []
	var used_ids: Array[String] = []
	for i in row.size():
		var entry: Dictionary = row[i]
		if entry.get("sold", false):
			refreshed.append(entry.duplicate(true))
			var sold_id := str(entry.get("item_id", ""))
			if not sold_id.is_empty():
				used_ids.append(sold_id)
			continue
		var available := pool.duplicate()
		for used_id in used_ids:
			available.erase(used_id)
		if available.is_empty():
			available = pool.duplicate()
		available.shuffle()
		var item_id := str(available[0]) if not available.is_empty() else str(entry.get("item_id", ""))
		used_ids.append(item_id)
		refreshed.append({
			"kind": kind,
			"item_id": item_id,
			"base_price": base_price,
			"on_sale": i == sale_index,
			"sold": false,
		})
	return refreshed


func _pick_random_unique_items(pool: Array[String], count: int) -> Array[String]:
	if pool.is_empty():
		return []
	var shuffled := pool.duplicate()
	shuffled.shuffle()
	var picked: Array[String] = []
	for i in mini(count, shuffled.size()):
		picked.append(shuffled[i])
	while picked.size() < count and not pool.is_empty():
		picked.append(pool[picked.size() % pool.size()])
	return picked
