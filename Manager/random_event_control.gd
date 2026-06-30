extends Node
class_name RandomEventControl

var _game_state: Node
var _shop_control: ShopControl


func setup(game_state: Node) -> void:
	_game_state = game_state
	if game_state != null and game_state.has_node("ShopControl"):
		_shop_control = game_state.get_node("ShopControl") as ShopControl


func build_event_payload(node: MapNode) -> Dictionary:
	var event_id := _pick_weighted_event_id(node.stage if node else 1)
	var event_row := RANDOM_EVENT_DATA.get_event(event_id)
	if event_row.is_empty():
		push_warning("RandomEventControl: no event data for '%s'" % event_id)
		return {}
	var payload := {
		"event_id": event_id,
		"title": str(event_row.get("title", "")),
		"flavor_text": str(event_row.get("flavor_text", "")),
		"image_path": str(event_row.get("image_path", "")),
		"choices": [],
	}
	var inventory: Inventory = _get_inventory()
	for choice_row in RANDOM_EVENT_DATA.get_choices_for_event(event_id):
		payload["choices"].append(_build_choice_payload(choice_row, inventory))
	return payload


func try_resolve_choice(payload: Dictionary, choice_id: String, inventory: Inventory) -> bool:
	if payload.is_empty():
		return false
	var choice := _find_choice(payload, choice_id)
	if choice.is_empty():
		return false
	if not bool(choice.get("enabled", false)):
		return false
	if not _apply_cost(choice, inventory):
		return false
	_apply_reward(choice, inventory)
	return true


func has_neutral_leave_choice(payload: Dictionary) -> bool:
	for choice in payload.get("choices", []):
		if not choice is Dictionary:
			continue
		var cost_kind := str(choice.get("cost_kind", ""))
		var reward_kind := str(choice.get("reward_kind", ""))
		if cost_kind == "none" and reward_kind == "none":
			return true
	return false


func refresh_choice_enabled_flags(payload: Dictionary, inventory: Inventory) -> Dictionary:
	var refreshed := payload.duplicate(true)
	var choices: Array = []
	for choice in refreshed.get("choices", []):
		if not choice is Dictionary:
			continue
		var c: Dictionary = (choice as Dictionary).duplicate(true)
		c["enabled"] = _is_choice_affordable(c, inventory)
		choices.append(c)
	refreshed["choices"] = choices
	return refreshed


func _pick_weighted_event_id(stage: int) -> String:
	var eligible: Array[Dictionary] = []
	for eid in RANDOM_EVENT_DATA.get_all_event_ids():
		var row := RANDOM_EVENT_DATA.get_event(eid)
		var min_stage := int(row.get("min_stage", "1"))
		if stage < min_stage:
			continue
		var weight := maxi(1, int(row.get("weight", "1")))
		eligible.append({"event_id": eid, "weight": weight})
	if eligible.is_empty():
		var fallback := RANDOM_EVENT_DATA.get_all_event_ids()
		if fallback.is_empty():
			return ""
		return fallback[0]
	var total_weight := 0
	for entry in eligible:
		total_weight += int(entry.get("weight", 1))
	var roll := randi_range(1, total_weight)
	var cumulative := 0
	for entry in eligible:
		cumulative += int(entry.get("weight", 1))
		if roll <= cumulative:
			return str(entry.get("event_id", ""))
	return str(eligible[0].get("event_id", ""))


func _build_choice_payload(choice_row: Dictionary, inventory: Inventory) -> Dictionary:
	var choice := {
		"choice_id": str(choice_row.get("choice_id", "")),
		"label": str(choice_row.get("label", "")),
		"cost_kind": str(choice_row.get("cost_kind", "none")),
		"cost_amount": int(choice_row.get("cost_amount", "0")),
		"cost_filter": str(choice_row.get("cost_filter", "")),
		"reward_kind": str(choice_row.get("reward_kind", "none")),
		"reward_amount": int(choice_row.get("reward_amount", "0")),
		"reward_item_id": str(choice_row.get("reward_item_id", "")),
		"reward_pool": str(choice_row.get("reward_pool", "")),
	}
	choice["enabled"] = _is_choice_affordable(choice, inventory)
	return choice


func _find_choice(payload: Dictionary, choice_id: String) -> Dictionary:
	for choice in payload.get("choices", []):
		if choice is Dictionary and str(choice.get("choice_id", "")) == choice_id:
			return choice
	return {}


func _is_choice_affordable(choice: Dictionary, inventory: Inventory) -> bool:
	var cost_kind := str(choice.get("cost_kind", "none"))
	var cost_amount := int(choice.get("cost_amount", 0))
	match cost_kind:
		"none":
			return true
		"gold":
			return _game_state != null and _game_state.run_gold >= cost_amount
		"components":
			return _game_state != null and _game_state.run_components >= cost_amount
		"health":
			return _can_afford_health_cost(cost_amount)
		"inventory_random":
			var filter := str(choice.get("cost_filter", "any"))
			return inventory != null and not inventory.get_owned_item_ids(filter).is_empty()
		_:
			push_warning("RandomEventControl: unknown cost_kind '%s'" % cost_kind)
			return false


func _can_afford_health_cost(cost_amount: int) -> bool:
	if _game_state == null or _game_state.player_health == null:
		return false
	var health_manager: PlayerHealthManager = _game_state.player_health
	var damage := int(round(float(health_manager.max_health) * float(cost_amount) / 100.0))
	return health_manager.curr_health > damage


func _apply_cost(choice: Dictionary, inventory: Inventory) -> bool:
	var cost_kind := str(choice.get("cost_kind", "none"))
	var cost_amount := int(choice.get("cost_amount", 0))
	match cost_kind:
		"none":
			return true
		"gold":
			return _game_state != null and _game_state.spend_gold(cost_amount)
		"components":
			return _game_state != null and _game_state.spend_components(cost_amount)
		"health":
			return _spend_health_fraction(cost_amount)
		"inventory_random":
			return _remove_random_inventory_item(inventory, str(choice.get("cost_filter", "any")), cost_amount)
		_:
			return false


func _apply_reward(choice: Dictionary, inventory: Inventory) -> void:
	var reward_kind := str(choice.get("reward_kind", "none"))
	var reward_amount := int(choice.get("reward_amount", 0))
	match reward_kind:
		"none":
			pass
		"gold":
			if _game_state:
				_game_state.add_gold(reward_amount)
		"components":
			if _game_state:
				_game_state.add_components(reward_amount)
		"health":
			if _game_state and _game_state.player_health:
				_game_state.player_health.restore_health_fraction(float(reward_amount) / 100.0)
		"item":
			var item_id := str(choice.get("reward_item_id", ""))
			if inventory != null and not item_id.is_empty():
				inventory.add_item(item_id, maxi(1, reward_amount))
		"item_random":
			var pool_tag := str(choice.get("reward_pool", ""))
			var item_id := _resolve_random_reward(pool_tag)
			if inventory != null and not item_id.is_empty():
				inventory.add_item(item_id, 1)
		_:
			push_warning("RandomEventControl: unknown reward_kind '%s'" % reward_kind)


func _spend_health_fraction(cost_amount: int) -> bool:
	if _game_state == null or _game_state.player_health == null:
		return false
	var health_manager: PlayerHealthManager = _game_state.player_health
	var damage := int(round(float(health_manager.max_health) * float(cost_amount) / 100.0))
	if damage <= 0:
		return true
	if health_manager.curr_health <= damage:
		return false
	health_manager.apply_damage(damage)
	return true


func _remove_random_inventory_item(inventory: Inventory, filter: String, count: int) -> bool:
	if inventory == null:
		return false
	var owned := inventory.get_owned_item_ids(filter)
	if owned.is_empty():
		return false
	var item_id := owned[randi() % owned.size()]
	return inventory.remove_item(item_id, maxi(1, count))


func _resolve_random_reward(pool_tag: String) -> String:
	var pool: Array[String] = []
	match pool_tag:
		"shop_units":
			if _shop_control:
				pool = _shop_control.get_unit_pool()
		"shop_spells":
			if _shop_control:
				pool = _shop_control.get_spell_pool()
		_:
			push_warning("RandomEventControl: unknown reward_pool '%s'" % pool_tag)
	if pool.is_empty():
		return ""
	pool.shuffle()
	return pool[0]


func _get_inventory() -> Inventory:
	if _game_state == null or _game_state.gui == null:
		return null
	return _game_state.gui.inventory
