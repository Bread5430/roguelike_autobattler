extends Node
class_name QuestControl

const CHOICE_ACCEPT := "quest_accept"
const CHOICE_DECLINE := "quest_decline"

var _game_state: Node
var _preview_marks: Array[Dictionary] = []
var _preview_quest_id: String = ""
var _active_quest_ids: Dictionary = {} ## quest_id -> true


func setup(game_state: Node) -> void:
	_game_state = game_state


func reset_run_state() -> void:
	_clear_preview_without_map()
	_active_quest_ids.clear()
	var map = _get_map()
	if map == null:
		return
	for node in map.nodes:
		if node is MapNode and not (node as MapNode).special_mark.is_empty():
			_clear_mark_on_node(node as MapNode)


func can_place_quest(quest_id: String, origin: MapNode) -> bool:
	return not _select_target_nodes(quest_id, origin).is_empty()


func preview_quest(quest_id: String, origin: MapNode) -> Array[Dictionary]:
	revert_preview()
	var selected = _select_target_nodes(quest_id, origin)
	if selected.is_empty():
		return []
	_preview_quest_id = quest_id
	_preview_marks.clear()
	for draft in selected:
		_preview_marks.append(draft)
		_apply_mark_to_node(draft, true)
	_queue_map_redraw()
	return _preview_marks.duplicate(true)


func commit_preview() -> bool:
	if _preview_quest_id.is_empty() or _preview_marks.is_empty():
		return false
	for draft in _preview_marks:
		var node: MapNode = draft.get("node")
		if node == null:
			continue
		_apply_mark_to_node(draft, false)
	_active_quest_ids[_preview_quest_id] = true
	_preview_quest_id = ""
	_preview_marks.clear()
	_queue_map_redraw()
	return true


func revert_preview() -> void:
	for draft in _preview_marks:
		var node: MapNode = draft.get("node")
		if node == null:
			continue
		_clear_mark_on_node(node)
	_clear_preview_without_map()
	_queue_map_redraw()


func get_mark(node: MapNode) -> Dictionary:
	if node == null:
		return {}
	return node.special_mark.duplicate(true)


func has_mark(node: MapNode) -> bool:
	return node != null and not node.special_mark.is_empty()


func is_preview_mark(node: MapNode) -> bool:
	if not has_mark(node):
		return false
	return bool(node.special_mark.get("is_preview", false))


func should_trigger_after_battle(node: MapNode) -> bool:
	if not has_mark(node):
		return false
	if bool(node.special_mark.get("is_preview", false)):
		return false
	if node.content_type == MapNode.ContentType.BATTLE or node.content_type == MapNode.ContentType.BLOCKADE:
		return true
	return str(node.special_mark.get("trigger_mode", "")) == "after_battle"


func should_trigger_on_visit(node: MapNode) -> bool:
	if not has_mark(node):
		return false
	if bool(node.special_mark.get("is_preview", false)):
		return false
	if node.content_type == MapNode.ContentType.BATTLE or node.content_type == MapNode.ContentType.BLOCKADE:
		return false
	return str(node.special_mark.get("trigger_mode", "")) == "on_visit"


func build_encounter_payload(node: MapNode) -> Dictionary:
	var mark = get_mark(node)
	if mark.is_empty():
		return {}
	var encounter_id = str(mark.get("encounter_id", ""))
	if encounter_id.is_empty():
		return {}
	var event_row = RANDOM_EVENT_DATA.get_event(encounter_id)
	if event_row.is_empty():
		return {}
	var payload = {
		"event_id": encounter_id,
		"title": str(event_row.get("title", "")),
		"flavor_text": str(event_row.get("flavor_text", "")),
		"image_path": str(event_row.get("image_path", "")),
		"choices": [],
		"is_quest_encounter": true,
		"quest_node_id": node.id,
	}
	var inventory = _get_inventory()
	var random_event_control = _get_random_event_control()
	for choice_row in RANDOM_EVENT_DATA.get_choices_for_event(encounter_id):
		if random_event_control:
			payload["choices"].append(random_event_control.build_choice_payload(choice_row, inventory))
		else:
			payload["choices"].append({
				"choice_id": str(choice_row.get("choice_id", "collect")),
				"label": str(choice_row.get("label", "Collect")),
				"cost_kind": "none",
				"cost_amount": 0,
				"reward_kind": str(choice_row.get("reward_kind", "none")),
				"reward_amount": int(choice_row.get("reward_amount", "0")),
				"enabled": true,
			})
	return payload


func complete_mark(node: MapNode) -> void:
	if not has_mark(node):
		return
	var mark = get_mark(node)
	var quest_id = str(mark.get("quest_id", ""))
	var slot_id = int(mark.get("slot_id", 0))
	var exclusive = RANDOM_EVENT_DATA.is_quest_exclusive(quest_id)
	_clear_mark_on_node(node)
	if exclusive and not quest_id.is_empty():
		_clear_sibling_marks(quest_id, node.id)
	try_spawn_followup_marks(quest_id, slot_id)
	_queue_map_redraw()


## Stub: future quests may spawn additional tied special nodes after a mark completes.
func try_spawn_followup_marks(_quest_id: String, _completed_slot_id: int) -> void:
	pass


func build_quest_accept_decline_choices() -> Array:
	return [
		{
			"choice_id": CHOICE_ACCEPT,
			"label": "Accept",
			"cost_kind": "none",
			"cost_amount": 0,
			"cost_filter": "",
			"reward_kind": "none",
			"reward_amount": 0,
			"reward_item_id": "",
			"reward_pool": "",
			"enabled": true,
		},
		{
			"choice_id": CHOICE_DECLINE,
			"label": "Decline",
			"cost_kind": "none",
			"cost_amount": 0,
			"cost_filter": "",
			"reward_kind": "none",
			"reward_amount": 0,
			"reward_item_id": "",
			"reward_pool": "",
			"enabled": true,
		},
	]


func resolve_quest_choice(choice_id: String) -> bool:
	if choice_id == CHOICE_ACCEPT:
		return commit_preview()
	if choice_id == CHOICE_DECLINE:
		revert_preview()
		return true
	return false


func serialize_marks() -> Dictionary:
	var out: Dictionary = {}
	var map = _get_map()
	if map == null:
		return out
	for node in map.nodes:
		if not (node is MapNode):
			continue
		var mn: MapNode = node
		if mn.special_mark.is_empty():
			continue
		if bool(mn.special_mark.get("is_preview", false)):
			continue
		out[mn.id] = mn.special_mark.duplicate(true)
	return out


func apply_serialized_marks(marks_by_node_id: Dictionary) -> void:
	var map = _get_map()
	if map == null:
		return
	_active_quest_ids.clear()
	for node in map.nodes:
		if node is MapNode:
			(node as MapNode).special_mark = {}
	for key in marks_by_node_id.keys():
		var node_id = int(key)
		var mark_data = marks_by_node_id[key]
		if not mark_data is Dictionary:
			continue
		var node = map.get_node_by_id(node_id)
		if node == null:
			continue
		node.special_mark = (mark_data as Dictionary).duplicate(true)
		node.special_mark["is_preview"] = false
		var quest_id = str(node.special_mark.get("quest_id", ""))
		if not quest_id.is_empty():
			_active_quest_ids[quest_id] = true
		var difficulty_override = str(node.special_mark.get("difficulty_override", ""))
		if not difficulty_override.is_empty():
			if not node.special_mark.has("original_difficulty"):
				node.special_mark["original_difficulty"] = node.difficulty
			node.difficulty = difficulty_override
	_queue_map_redraw()


func sync_active_quests_from_map() -> void:
	_active_quest_ids.clear()
	var map = _get_map()
	if map == null:
		return
	for node in map.nodes:
		if not (node is MapNode):
			continue
		var mn: MapNode = node
		if mn.special_mark.is_empty():
			continue
		var quest_id = str(mn.special_mark.get("quest_id", ""))
		if not quest_id.is_empty():
			_active_quest_ids[quest_id] = true


func _select_target_nodes(quest_id: String, origin: MapNode) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var def = RANDOM_EVENT_DATA.get_quest_def(quest_id)
	var targets = RANDOM_EVENT_DATA.get_quest_targets(quest_id)
	if def.is_empty() or targets.is_empty():
		return result
	var map = _get_map()
	if map == null:
		return result
	var max_targets = clampi(int(def.get("max_targets", str(targets.size()))), 1, 3)
	var sorted_targets: Array = targets.duplicate()
	sorted_targets.sort_custom(func(a, b): return int(a.get("slot_id", "0")) < int(b.get("slot_id", "0")))
	var chosen_nodes: Array[MapNode] = []
	for i in range(mini(max_targets, sorted_targets.size())):
		var target_row: Dictionary = sorted_targets[i]
		var candidate = _pick_candidate_for_slot(map, origin, target_row, chosen_nodes)
		if candidate == null:
			return []
		chosen_nodes.append(candidate)
		result.append(_make_mark_draft(quest_id, target_row, candidate))
	return result


func _pick_candidate_for_slot(
	map: Node,
	origin: MapNode,
	target_row: Dictionary,
	already_chosen: Array[MapNode]
) -> MapNode:
	var content_filter = str(target_row.get("target_content", "any"))
	var min_separation = int(target_row.get("min_separation", "0"))
	var candidates: Array[MapNode] = []
	for node in map.nodes:
		if not (node is MapNode):
			continue
		var mn: MapNode = node
		if not _is_valid_candidate(map, mn, origin, content_filter):
			continue
		if already_chosen.has(mn):
			continue
		var ok_separation = true
		for chosen in already_chosen:
			if map.graph_distance(mn, chosen) < min_separation:
				ok_separation = false
				break
		if not ok_separation:
			continue
		candidates.append(mn)
	if candidates.is_empty():
		return null
	candidates.shuffle()
	return candidates[0]


func _is_valid_candidate(map: Node, node: MapNode, origin: MapNode, content_filter: String) -> bool:
	if node == null or node.completed:
		return false
	if origin != null and node.id == origin.id:
		return false
	if node.node_type == "start" or node.node_type == "end":
		return false
	if map.start_node == node or map.end_node == node:
		return false
	if not node.special_mark.is_empty():
		return false
	# Never assign new special encounters onto already-blockaded nodes.
	# Marks already placed may still be blockaded later; see should_trigger_*.
	if _is_node_blockaded(node):
		return false
	return _content_matches_filter(node.content_type, content_filter)


func _is_node_blockaded(node: MapNode) -> bool:
	if node == null:
		return false
	if node.content_type == MapNode.ContentType.BLOCKADE:
		return true
	return node.chaser_blockaded


func _content_matches_filter(content_type: int, content_filter: String) -> bool:
	match content_filter:
		"any":
			return true
		"battle":
			return content_type == MapNode.ContentType.BATTLE
		"shop":
			return content_type == MapNode.ContentType.SHOP
		"repair":
			return content_type == MapNode.ContentType.REPAIR_SITE
		"event":
			return content_type == MapNode.ContentType.RANDOM_EVENT
		_:
			return false


func _make_mark_draft(quest_id: String, target_row: Dictionary, node: MapNode) -> Dictionary:
	return {
		"node": node,
		"quest_id": quest_id,
		"slot_id": int(target_row.get("slot_id", "0")),
		"encounter_id": str(target_row.get("encounter_id", "")),
		"map_label": str(target_row.get("map_label", "")),
		"difficulty_override": str(target_row.get("difficulty_override", "")),
		"trigger_mode": str(target_row.get("trigger_mode", "on_visit")),
		"original_difficulty": node.difficulty,
	}


func _apply_mark_to_node(draft: Dictionary, is_preview: bool) -> void:
	var node: MapNode = draft.get("node")
	if node == null:
		return
	var mark = {
		"quest_id": str(draft.get("quest_id", "")),
		"slot_id": int(draft.get("slot_id", 0)),
		"encounter_id": str(draft.get("encounter_id", "")),
		"map_label": str(draft.get("map_label", "")),
		"difficulty_override": str(draft.get("difficulty_override", "")),
		"trigger_mode": str(draft.get("trigger_mode", "on_visit")),
		"original_difficulty": str(draft.get("original_difficulty", node.difficulty)),
		"is_preview": is_preview,
	}
	node.special_mark = mark
	var difficulty_override = str(mark.get("difficulty_override", ""))
	if not difficulty_override.is_empty():
		node.difficulty = difficulty_override


func _clear_mark_on_node(node: MapNode) -> void:
	if node == null:
		return
	var mark = node.special_mark
	if not mark.is_empty():
		var original = str(mark.get("original_difficulty", ""))
		if not original.is_empty():
			node.difficulty = original
	node.special_mark = {}


func _clear_sibling_marks(quest_id: String, except_node_id: int) -> void:
	var map = _get_map()
	if map == null:
		return
	for node in map.nodes:
		if not (node is MapNode):
			continue
		var mn: MapNode = node
		if mn.id == except_node_id:
			continue
		if mn.special_mark.is_empty():
			continue
		if str(mn.special_mark.get("quest_id", "")) != quest_id:
			continue
		_clear_mark_on_node(mn)


func _clear_preview_without_map() -> void:
	_preview_marks.clear()
	_preview_quest_id = ""


func _get_map() -> Node:
	if _game_state == null:
		return null
	return _game_state.map_generator


func _get_random_event_control() -> RandomEventControl:
	if _game_state == null:
		return null
	return _game_state.random_event_control as RandomEventControl


func _get_inventory() -> Inventory:
	if _game_state == null or _game_state.gui == null:
		return null
	return _game_state.gui.inventory


func _queue_map_redraw() -> void:
	var map = _get_map()
	if map:
		map.queue_redraw()
