extends Node

##### External references
var unit
var target_manager
var flow_field
var battle_manager

###### Internal variables
var curr_targets: Array = []
var flow_vec: Vector2

var curr_target_iter: int = -1
var target_idx: int = 0
var _cached_beacon_move_vec: Vector2 = Vector2.ZERO
var _cached_beacon_eval_frame: int = -1

## Ask for extra candidates so we can skip dead units and still have alternates before the next manager tick.
const _MIN_TARGET_FETCH := 5


# Used for multitarget attacks - returns a list of N valid targets
func get_N_targets(num_targets: int) -> Array:
	_sync_targets_from_manager_if_needed(num_targets)
	if curr_targets.is_empty():
		return []
	var kept: Array = []
	for t in curr_targets:
		if _is_valid_target(t):
			kept.append(t)
	curr_targets = kept

	if curr_targets.size() < num_targets:
		return curr_targets
	else:
		return curr_targets.slice(0,num_targets)


# Used for single target attacks - returns a single valid target
func get_target() -> Base_Unit:
	_sync_targets_from_manager_if_needed(1)
	if _get_non_null_idx():
		return curr_targets[target_idx] as Base_Unit
	return null


func get_flow_field() -> Vector2:
	flow_vec = flow_field.get_flow(!unit.faction, unit.position)
	return flow_vec

func get_dir_target() -> Vector2:
	if _get_non_null_idx():
		return (curr_targets[target_idx].position - unit.position).normalized()
	return flow_vec

func in_same_tile() -> bool:
	if _get_non_null_idx():
		# use larger than the size of a tile to prevent getting stuck at edges
		return (curr_targets[target_idx].position - unit.position).length_squared() < (target_manager.get_parent().tile_size * 1.5) ** 2
	return false


## Compute per-physics frame once; FSMs may read in both logic and transition.
func begin_physics_tick() -> void:
	var f := Engine.get_physics_frames()
	if f == _cached_beacon_eval_frame:
		return
	_cached_beacon_eval_frame = f
	_cached_beacon_move_vec = _compute_beacon_move_vec()


func get_cached_beacon_move_vec() -> Vector2:
	return _cached_beacon_move_vec


func has_beacon_assignment() -> bool:
	return battle_manager.beacon_controller.unit_has_beacon(unit)


## Backward-compatible API: now returns cached value for this physics frame.
func try_beacon_move_vec() -> Vector2:
	begin_physics_tick()
	return _cached_beacon_move_vec


func _compute_beacon_move_vec() -> Vector2:
	if unit.is_movement_restricted():
		return Vector2.ZERO
	var bm: Node = battle_manager
	if bm == null:
		return Vector2.ZERO
	var bc: BeaconController = bm.beacon_controller
	if bc == null or not bc.unit_has_beacon(unit):
		return Vector2.ZERO
	if bc.is_enemy_within_panic_radius(unit):
		return Vector2.ZERO
	return bc.compute_steering(unit)


####### Helper functions

func post_ready() -> void:
	unit = get_parent()
	target_manager = get_tree().get_nodes_in_group("TARGETMANAGER")[0]
	flow_field = get_tree().get_nodes_in_group("FLOWGEN")[0]
	battle_manager = get_tree().get_nodes_in_group("BATTLEMANAGER")[0]


func _sync_targets_from_manager_if_needed(num_targets: int) -> void:
	if target_manager.target_iter == curr_target_iter:
		return
	curr_target_iter = target_manager.target_iter
	var fetch_n: int = maxi(num_targets * 3, _MIN_TARGET_FETCH)
	curr_targets = target_manager.get_closest_targets(!unit.faction, unit.position, fetch_n)
	target_idx = 0



func _get_non_null_idx() -> bool:
	while target_idx < curr_targets.size():
		if _is_valid_target(curr_targets[target_idx]):
			return true
		target_idx += 1
	return false


func _is_valid_target(t: Variant) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if not t is Base_Unit:
		return false
	return t.curr_hp > 0
