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
	if _game_state == null:
		return false
	if int(state.get("actions_left", 0)) <= 0:
		return false
	if not _game_state.spend_components(repair_cost):
		return false
	var health_manager: PlayerHealthManager = _game_state.player_health
	if health_manager:
		health_manager.restore_health_fraction(repair_heal_fraction)
	state["actions_left"] = int(state.get("actions_left", 0)) - 1
	return true


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


func try_purchase_upgrade(slot_data: Dictionary, state: Dictionary) -> bool:
	# TODO: apply real unit upgrade when upgrade system exists.
	if _game_state == null:
		return false
	if int(state.get("actions_left", 0)) <= 0:
		return false
	if slot_data.get("purchased", false):
		return false
	var price := get_component_price(slot_data)
	if price <= 0:
		return false
	if not _game_state.spend_components(price):
		return false
	state["actions_left"] = int(state.get("actions_left", 0)) - 1
	return true


func _build_upgrade_row() -> Array:
	var row: Array = []
	for i in UPGRADE_COUNT:
		row.append({
			"kind": "upgrade",
			"currency": "components",
			"upgrade_id": "",
			"base_price": upgrade_base_price,
			"on_sale": i == UPGRADE_SALE_INDEX,
			"purchased": false,
		})
	return row


func _refresh_upgrade_row(row: Array) -> Array:
	var refreshed: Array = []
	for i in row.size():
		var entry: Dictionary = row[i]
		if entry.get("purchased", false):
			refreshed.append(entry.duplicate(true))
			continue
		refreshed.append({
			"kind": "upgrade",
			"currency": "components",
			"upgrade_id": "",
			"base_price": upgrade_base_price,
			"on_sale": i == UPGRADE_SALE_INDEX,
			"purchased": false,
		})
	return refreshed


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
