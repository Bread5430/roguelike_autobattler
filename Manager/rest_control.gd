extends Node
class_name RestControl

const UPGRADE_COUNT := 4
const UPGRADE_SALE_INDEX := 3

@export var actions_per_visit := 3
@export var repair_cost := 2
@export var craft_cost := 3
@export var refresh_cost := 1
@export var upgrade_base_price := 4
@export var repair_heal_fraction := 0.2

var _game_state: Node


func setup(game_state: Node) -> void:
	_game_state = game_state


func generate_offers() -> Dictionary:
	return {
		"upgrades": _build_upgrade_row(),
		"actions_left": actions_per_visit,
	}


func get_component_price(slot_data: Dictionary) -> int:
	var base_price := int(slot_data.get("base_price", 0))
	if slot_data.get("on_sale", false):
		return int(floor(float(base_price) * 0.5))
	return base_price


func try_repair(state: Dictionary) -> bool:
	if not can_repair(state):
		return false
	if not _game_state.spend_components(repair_cost):
		return false
	var health_manager: PlayerHealthManager = _game_state.player_health
	if health_manager:
		health_manager.restore_health_fraction(repair_heal_fraction)
	state["actions_left"] = int(state.get("actions_left", 0)) - 1
	return true


func can_repair(state: Dictionary) -> bool:
	if _game_state == null:
		return false
	if int(state.get("actions_left", 0)) <= 0:
		return false
	if _game_state.run_components < repair_cost:
		return false
	var health_manager: PlayerHealthManager = _game_state.player_health
	if health_manager and health_manager.is_at_full_health():
		return false
	return true


func can_craft(state: Dictionary) -> bool:
	if _game_state == null:
		return false
	if int(state.get("actions_left", 0)) <= 0:
		return false
	return _game_state.run_components >= craft_cost


func can_refresh() -> bool:
	if _game_state == null:
		return false
	return _game_state.run_components >= refresh_cost


func try_craft_unit(item_id: String, inventory: Inventory, state: Dictionary) -> bool:
	if _game_state == null or inventory == null:
		return false
	if int(state.get("actions_left", 0)) <= 0:
		return false
	if not _is_unit_item(item_id):
		return false
	if not _game_state.spend_components(craft_cost):
		return false
	inventory.add_item(item_id, 1)
	state["actions_left"] = int(state.get("actions_left", 0)) - 1
	return true


func refresh_upgrades(state: Dictionary) -> Dictionary:
	if _game_state == null:
		return state
	if not _game_state.spend_components(refresh_cost):
		return state
	var refreshed := state.duplicate(true)
	refreshed["upgrades"] = _refresh_upgrade_row(refreshed.get("upgrades", []))
	return refreshed


func can_purchase_upgrade(slot_data: Dictionary, state: Dictionary) -> bool:
	if _game_state == null:
		return false
	if int(state.get("actions_left", 0)) <= 0:
		return false
	if slot_data.get("purchased", false):
		return false
	var base_id := str(slot_data.get("upgrade_id", ""))
	if base_id.is_empty() or UnitUpgradeRegistry.has_upgrade(base_id):
		return false
	if not UNIT_UPGRADES.has_entry(base_id):
		return false
	var price := get_component_price(slot_data)
	if price <= 0 or _game_state.run_components < price:
		return false
	return true


func try_finalize_upgrade(slot_data: Dictionary, path: String, state: Dictionary) -> bool:
	if _game_state == null:
		return false
	if int(state.get("actions_left", 0)) <= 0:
		return false
	if slot_data.get("purchased", false):
		return false
	var base_id := str(slot_data.get("upgrade_id", ""))
	if base_id.is_empty() or not UNIT_UPGRADES.has_entry(base_id):
		return false
	if UnitUpgradeRegistry.has_upgrade(base_id):
		return false
	if not UNIT_UPGRADES.is_valid_path(path):
		return false
	var price := get_component_price(slot_data)
	if price <= 0:
		return false
	if not _game_state.spend_components(price):
		return false
	UnitUpgradeRegistry.apply_path(base_id, path)
	state["actions_left"] = int(state.get("actions_left", 0)) - 1
	return true


func _build_upgrade_row() -> Array:
	var pool := _get_rest_upgrade_pool()
	var row: Array = []
	for i in UPGRADE_COUNT:
		var base_id := ""
		if not pool.is_empty():
			base_id = pool[i % pool.size()]
		row.append(_make_upgrade_slot(base_id, i == UPGRADE_SALE_INDEX))
	return row


func _refresh_upgrade_row(row: Array) -> Array:
	var pool := _get_rest_upgrade_pool()
	var pool_index := 0
	var refreshed: Array = []
	for i in row.size():
		var entry: Dictionary = row[i]
		if entry.get("purchased", false):
			refreshed.append(entry.duplicate(true))
			continue
		var base_id := ""
		if pool_index < pool.size():
			base_id = pool[pool_index]
			pool_index += 1
		refreshed.append(_make_upgrade_slot(base_id, i == UPGRADE_SALE_INDEX))
	return refreshed


func _make_upgrade_slot(base_id: String, on_sale: bool) -> Dictionary:
	return {
		"kind": "upgrade",
		"currency": "components",
		"upgrade_id": base_id,
		"item_id": base_id,
		"base_price": upgrade_base_price,
		"on_sale": on_sale,
		"purchased": false,
	}


func _get_rest_upgrade_pool() -> Array[String]:
	var pool: Array[String] = []
	for base_id in UnitUpgradeRegistry.get_upgradeable_pool():
		if _is_upgradable_card(base_id):
			pool.append(base_id)
	pool.shuffle()
	return pool


func _is_upgradable_card(item_id: String) -> bool:
	if not UNIT_UPGRADES.has_entry(item_id):
		return false
	var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
	if scene == null:
		return false
	var inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var ok := inst is Unit_Card and (inst as Unit_Card).is_upgradable
	if inst:
		inst.queue_free()
	return ok


func _is_unit_item(item_id: String) -> bool:
	var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
	if scene == null:
		return false
	if "Spells/" in scene.resource_path:
		return false
	var inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var is_unit := inst is Unit_Card
	if inst:
		inst.queue_free()
	return is_unit
