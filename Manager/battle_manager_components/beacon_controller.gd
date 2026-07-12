extends Node2D
class_name BeaconController

## World-space radius: enemies inside suppress beacon steering (units use normal combat movement).
@export var panic_radius: float = 50.0
## Default radius from path start used when registering affected allies (spell may override via argument).
@export var assign_radius: float = 120.0
@export var waypoint_arrive_distance: float = 36.0
## Max world-space length for a single path segment (start→waypoint or waypoint→end).
@export var max_segment_length: float = 400.0

const _PREVIEW_COLOR_VALID = Color(0.35, 0.85, 1.0, 0.92)
const _PREVIEW_COLOR_INVALID = Color(0.95, 0.25, 0.2, 0.95)

var battle_manager: Node
var target_man: Node

var _next_beacon_id: int = 1
## beacon_id -> { "path": PackedVector2Array, "units": Array[Base_Unit] }
var _beacons: Dictionary = {}
## unit Object instance_id -> beacon_id
var _unit_to_beacon: Dictionary = {}
## unit instance_id -> current target waypoint index in path (>= 1)
var _unit_waypoint_idx: Dictionary = {}
## unit instance_id -> original world-space offset from path[0] at beacon assignment time
var _unit_offset_from_origin: Dictionary = {}
var _panic_cache_by_uid: Dictionary = {}
var _panic_cache_target_iter: int = -1
var _steer_cache_by_uid: Dictionary = {}
var _steer_cache_frame: int = -1
var _preview_line: Line2D = null


func post_ready() -> void:
	battle_manager = get_parent()
	target_man = battle_manager.target_man

func clear_all() -> void:
	for beacon_id in _beacons.keys():
		_remove_beacon(beacon_id)
	_panic_cache_by_uid.clear()
	_panic_cache_target_iter = -1
	_steer_cache_by_uid.clear()
	_steer_cache_frame = -1
	clear_preview_line()


func is_segment_too_long(from_world: Vector2, to_world: Vector2) -> bool:
	return from_world.distance_to(to_world) > max_segment_length


func preview_path(points_world: Array[Vector2], hover_world: Vector2) -> void:
	if not is_instance_valid(_preview_line):
		_preview_line = Line2D.new()
		_preview_line.width = 5.0
		_preview_line.default_color = _PREVIEW_COLOR_VALID
		_preview_line.z_index = 100
		add_child(_preview_line)
	var pts: PackedVector2Array = PackedVector2Array()
	for p in points_world:
		pts.append(self.to_local(p))
	pts.append(self.to_local(hover_world))
	_preview_line.points = pts
	var segment_invalid = false
	if not points_world.is_empty():
		segment_invalid = is_segment_too_long(points_world[points_world.size() - 1], hover_world)
	_preview_line.default_color = _PREVIEW_COLOR_INVALID if segment_invalid else _PREVIEW_COLOR_VALID


func clear_preview_line() -> void:
	if is_instance_valid(_preview_line):
		_preview_line.queue_free()
	_preview_line = null


func unit_has_beacon(unit: Base_Unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return _unit_to_beacon.has(unit.get_instance_id())


func get_path_for_unit(unit: Base_Unit) -> PackedVector2Array:
	var bid: Variant = _unit_to_beacon.get(unit.get_instance_id(), -1)
	if bid == -1:
		return PackedVector2Array()
	var entry: Dictionary = _beacons.get(bid, {})
	return entry.get("path", PackedVector2Array())


func is_enemy_within_panic_radius(unit: Base_Unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var uid := unit.get_instance_id()
	var iter: int = int(target_man.target_iter)
	if iter != _panic_cache_target_iter:
		_panic_cache_target_iter = iter
		_panic_cache_by_uid.clear()
	elif _panic_cache_by_uid.has(uid):
		return bool(_panic_cache_by_uid[uid])
	var nearby_target = target_man.get_closest_target(!unit.faction, unit.position, maxi(int(panic_radius), 1))
	var has_enemy: bool = nearby_target != null
	_panic_cache_by_uid[uid] = has_enemy
	return has_enemy


func compute_steering(unit: Base_Unit) -> Vector2:
	if unit == null or not is_instance_valid(unit):
		return Vector2.ZERO
	
	# Do not recalculate the steering vector too often
	var frame: int = Engine.get_physics_frames()
	if frame != _steer_cache_frame:
		_steer_cache_frame = frame
		_steer_cache_by_uid.clear()
	var uid := unit.get_instance_id()
	if _steer_cache_by_uid.has(uid):
		return _steer_cache_by_uid[uid]
	
	var path := get_path_for_unit(unit)
	if path.size() < 2:
		_steer_cache_by_uid[uid] = Vector2.ZERO
		return Vector2.ZERO

	var wp_idx: int = int(_unit_waypoint_idx.get(uid, 1))
	wp_idx = clampi(wp_idx, 1, path.size() - 1)
	var offset: Vector2 = _unit_offset_from_origin.get(uid, Vector2.ZERO)
	var arrive_margin_sq := waypoint_arrive_distance * waypoint_arrive_distance

	while true:
		var target_point: Vector2 = path[wp_idx] + offset
		var to_goal: Vector2 = target_point - unit.global_position
		if to_goal.length_squared() > arrive_margin_sq:
			var move_dir := to_goal.normalized()
			_steer_cache_by_uid[uid] = move_dir
			return move_dir
		elif wp_idx >= path.size() - 1:
			# Final waypoint reached: release beacon assignment for this unit.
			remove_unit_beacon(unit)
			_steer_cache_by_uid[uid] = Vector2.ZERO
			return Vector2.ZERO
		wp_idx += 1
		_unit_waypoint_idx[uid] = wp_idx
	return Vector2.ZERO


## Returns beacon id, or -1 if nothing was registered.
func register_beacon(path: PackedVector2Array, units: Array, panic_r: float = -1.0) -> int:
	if path.size() < 2 or units.is_empty():
		return -1
	if panic_r > 0.0:
		panic_radius = panic_r
	var beacon_id := _next_beacon_id
	_next_beacon_id += 1

	var path_copy := PackedVector2Array(path)
	var owned_units: Array[Base_Unit] = []
	for u in units:
		if not u is Base_Unit:
			continue
		var bu: Base_Unit = u as Base_Unit
		if not is_instance_valid(bu) or bu.curr_hp <= 0:
			continue
		owned_units.append(bu)

	if owned_units.is_empty():
		return -1

	var def := StatusEffectLibrary.beacon_following()
	var stack_key := str(beacon_id)
	var origin: Vector2 = path_copy[0]
	for bu in owned_units:
		remove_unit_beacon(bu)
	for bu in owned_units:
		bu.apply_status_effect(def, stack_key, 1, def.default_duration)
		var uid := bu.get_instance_id()
		_unit_to_beacon[uid] = beacon_id
		_unit_waypoint_idx[uid] = 1
		_unit_offset_from_origin[uid] = bu.global_position - origin

	_beacons[beacon_id] = {"path": path_copy, "units": owned_units}
	_steer_cache_by_uid.clear()
	return beacon_id


## Drop one unit from its current beacon without touching other units on the same route.
func remove_unit_beacon(unit: Base_Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var uid := unit.get_instance_id()
	var bid: Variant = _unit_to_beacon.get(uid, -1)
	if bid == -1:
		return
	var beacon_id := int(bid)
	var entry: Variant = _beacons.get(beacon_id)
	if entry == null:
		_unit_to_beacon.erase(uid)
		_unit_waypoint_idx.erase(uid)
		_unit_offset_from_origin.erase(uid)
		return
	unit.remove_status_effect(&"beacon_following", str(beacon_id))
	_unit_to_beacon.erase(uid)
	_unit_waypoint_idx.erase(uid)
	_unit_offset_from_origin.erase(uid)
	var arr: Array = entry["units"]
	arr.erase(unit)
	if arr.is_empty():
		_beacons.erase(beacon_id)
	_steer_cache_by_uid.erase(uid)


func _remove_beacon(beacon_id: int) -> void:
	var entry: Variant = _beacons.get(beacon_id)
	if entry == null:
		return
	var units: Array = entry["units"].duplicate()
	var stack_key := str(beacon_id)
	for u in units:
		if is_instance_valid(u) and u is Base_Unit:
			(u as Base_Unit).remove_status_effect(&"beacon_following", stack_key)
			_unit_to_beacon.erase((u as Base_Unit).get_instance_id())
			_unit_waypoint_idx.erase((u as Base_Unit).get_instance_id())
			_unit_offset_from_origin.erase((u as Base_Unit).get_instance_id())
	_beacons.erase(beacon_id)
	_steer_cache_by_uid.clear()
