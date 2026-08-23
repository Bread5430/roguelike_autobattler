extends "res://Utilities/Entity_Components/targetting_cmp.gd"

## Prefer player routers (static + placed) for movement and attack until none remain.

const ROUTER_GLOSSARY_IDS: Array[String] = ["static_router_unit", "router_unit"]

var _player_routers: Array = []


func post_ready() -> void:
	super.post_ready()
	_cache_player_routers()


func get_target() -> Base_Unit:
	var router = _get_closest_living_router()
	if router != null:
		return router
	return super.get_target()


func get_N_targets(num_targets: int) -> Array:
	var living = _get_living_routers()
	if living.is_empty():
		return super.get_N_targets(num_targets)
	living.sort_custom(_sort_by_distance_to_self)
	if living.size() <= num_targets:
		return living
	return living.slice(0, num_targets)


func get_flow_field() -> Vector2:
	var router = _get_closest_living_router()
	if router != null:
		var to_router: Vector2 = router.position - unit.position
		if to_router.length_squared() > 0.0001:
			flow_vec = to_router.normalized()
		else:
			flow_vec = Vector2.ZERO
		return flow_vec
	return super.get_flow_field()


func get_dir_target() -> Vector2:
	var router = _get_closest_living_router()
	if router != null:
		var to_router: Vector2 = router.position - unit.position
		if to_router.length_squared() > 0.0001:
			return to_router.normalized()
		return flow_vec
	return super.get_dir_target()


func _cache_player_routers() -> void:
	_player_routers.clear()
	if unit == null:
		return
	var unit_parent = unit.get_parent()
	if unit_parent == null:
		return
	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var other: Base_Unit = child
		if other.faction == unit.faction:
			continue
		if not ROUTER_GLOSSARY_IDS.has(other.unit_glossary_id):
			continue
		_player_routers.append(other)


func _get_living_routers() -> Array:
	if _player_routers.is_empty():
		_cache_player_routers()
	var living: Array = []
	for r in _player_routers:
		if _is_valid_target(r):
			living.append(r)
	return living


func _get_closest_living_router() -> Base_Unit:
	var living = _get_living_routers()
	if living.is_empty():
		return null
	var best: Base_Unit = null
	var best_d2: float = INF
	for r in living:
		var d2: float = unit.position.distance_squared_to(r.position)
		if d2 < best_d2:
			best_d2 = d2
			best = r
	return best


func _sort_by_distance_to_self(a: Base_Unit, b: Base_Unit) -> bool:
	return unit.position.distance_squared_to(a.position) < unit.position.distance_squared_to(b.position)
