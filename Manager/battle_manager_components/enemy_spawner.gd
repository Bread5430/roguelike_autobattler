
# Start with some objectives spread out throught the grid
# For objectives create 3 - 5 static buildings roughly evenly spread across the grid
# On top of that, add on a Pregenerated List of formations 
# Have small, meduim and large formations to represent different stages in the game
# As enemies get stronger, use random spawns to fill in gaps between stages
# Formations contain unit roles, spawn zones and positions
# Use N X N squares as spawn zones - this way can accomodate units of many different types


# Spawning Instructions
# pick random formation  - then pick random units to fill roles
# 2 Unit types per role - Units have multiple roles, choose based on 
# randomize between 30 and 60 % splits for unit types for each role - but try to keep units of a type together

extends Node

var bm

# Top/bottom number of rows that are treated as side slots for stuns/vulnerability.
const SIDE_ROWS : int = 3

# This should be set to size of player board + small buffer (1 or 2 cells)
# Need to ensure that player towers are physically close to enemy units to be threatened
@export var grid_size := Vector2i(20, 0) 



#var unit_bitstring_cache = {}
var recently_seen_units = {}
var used_tiles = {}

func get_enemy_spawns(stage: int, difficulty: String, modifiers: Dictionary = {}) -> Array:
	# Reset spawned tiles
	used_tiles = {}
	
	# Decay spawn probabilities - int rounds down so eventually goes back to zero prob of spawn
	for u in recently_seen_units.keys():
		recently_seen_units[u] = int(recently_seen_units[u]/2)
	
	var spawn_difficulty := difficulty
	if modifiers.get("is_blockade", false) or modifiers.get("is_chaser_pressured_exit", false):
		spawn_difficulty = "heavy"
	
	# Get a random formation
	if not FORMATION_MAP.LEVELS.has(spawn_difficulty):
		push_warning("Invalid difficulty: %s" % spawn_difficulty)
		return []
	var formation = FORMATION_MAP.random_formation(spawn_difficulty)
	
	# Start filling in the formation with spawns
	var all_spawn_positions: Array = []
	var seen_groups = {}
	
	for parsed in formation:
		var spawn_pos = spawn_single_formation_entry(parsed, seen_groups)
		if spawn_pos != null:
			all_spawn_positions.append(spawn_pos)
	
	if modifiers.get("is_blockade", false) or modifiers.get("is_chaser_pressured_exit", false):
		var bonus_formation = FORMATION_MAP.random_formation("light")
		for parsed in bonus_formation:
			var spawn_pos = spawn_single_formation_entry(parsed, seen_groups)
			if spawn_pos != null:
				all_spawn_positions.append(spawn_pos)
	
	return all_spawn_positions
	

func get_predef_objectives(current_stage: int, enemy_positions: Array, objective_count: int = 3) -> Array:
	var objectives = []
	for i in range(objective_count):
		var base = enemy_positions.pick_random()
		var offset = Vector2i(randi() % 3 - 1, randi() % 3 - 1)
		var obj_pos = base + offset
		obj_pos.x = clamp(obj_pos.x, 0, grid_size.x - 1)
		obj_pos.y = clamp(obj_pos.y, 0, grid_size.y - 1)
		objectives.append(obj_pos)
	return objectives


# Utility Functions

func get_unit_by_role_cached(code: int) -> Array:
	""" TODO: Performance test to see if caching actually makes a difference
	if code not in unit_bitstring_cache:
		unit_bitstring_cache[code] = ITEM_NAME.get_all_matching_roles(code)
		return unit_bitstring_cache[code]
	else:
		return unit_bitstring_cache[code]
	""" 
	return ITEM_NAME.get_all_matching_roles(code)


func weighted_random_selections(array: Array) -> PackedScene:
	if array.size() == 0:
		return null
	
	# Setup selection counts to match what has been previously seen
	var selection_counts = {}
	for item in array:
		if item in recently_seen_units:
			selection_counts[item] = recently_seen_units[item]
		else:
			selection_counts[item] = 0
	
	# Step 1: Compute weights (inverse of how often item has been selected)
	var weights = []
	var total_weight = 0
	for item in array:
		var count = selection_counts[item]
		var weight = 1.0 / (1 + count)  # Decaying weight
		weights.append(weight)
		total_weight += weight
	
	# Step 2: Normalize weights
	var cumulative = []
	var sum_so_far = 0.0
	for w in weights:
		sum_so_far += w / total_weight
		cumulative.append(sum_so_far)
	
	# Step 3: Select a random item based on cumulative distribution
	var r = randf()
	for idx in range(array.size()):
		if r <= cumulative[idx]:
			var selected_item = array[idx]
			if selected_item in recently_seen_units:
				recently_seen_units[selected_item] += 2
			else:
				recently_seen_units[selected_item] = 2
			return ITEM_NAME.item_lookup(selected_item)
			
	return null


func _exact_unit_id_from_parsed(parsed: Dictionary) -> String:
	var u = parsed.get("exact_unit", null)
	if u != null and str(u) != "":
		return str(u)
	var t = parsed.get("exact_type", null)
	if t != null and str(t) != "":
		return str(t)
	return ""


## Resolves which unit card scene to use for one formation row (shared group/role/exact logic).
func pick_unit_scene_for_entry(parsed: Dictionary, seen_groups: Dictionary) -> PackedScene:
	var role: int = int(parsed["role"])
	var unit_group: int = int(parsed["group"])
	var selected_unit_scene: PackedScene

	if unit_group in seen_groups:
		selected_unit_scene = seen_groups[unit_group]
	else:
		var unit_options := get_unit_by_role_cached(role)
		if unit_options.is_empty():
			push_warning("Unknown unit role: %s" % role)
			return null
		selected_unit_scene = weighted_random_selections(unit_options)
		if not selected_unit_scene:
			return null
		seen_groups[unit_group] = selected_unit_scene

	var exact_id := _exact_unit_id_from_parsed(parsed)
	if exact_id != "":
		var exact_scene := ITEM_NAME.item_lookup(exact_id)
		if exact_scene:
			selected_unit_scene = exact_scene
			seen_groups[unit_group] = selected_unit_scene
		else:
			push_warning("Unknown exact unit: %s" % exact_id)
			return null

	return selected_unit_scene


## Spawns one formation entry as enemies. Returns spawn grid position on success, or null.
## Formation CSV coords are authored on the player board; spawn mirrors X left-to-right
## onto the enemy side so player-left (backline) maps to enemy-right (backline).
## Side-row entries are also mirrored onto the player-side column at the same logical y.
func spawn_single_formation_entry(parsed: Dictionary, seen_groups: Dictionary) -> Variant:
	if parsed.is_empty():
		push_warning("Malformed Formation")
		return null

	var selected_unit_scene = pick_unit_scene_for_entry(parsed, seen_groups)
	if not selected_unit_scene:
		return null

	var unit_item_inst = selected_unit_scene.instantiate()
	if not unit_item_inst is Unit_Card:
		push_warning("Formation entry resolved to non-card scene: %s" % selected_unit_scene.resource_path)
		unit_item_inst.queue_free()
		return null
	unit_item_inst.setup_unit()

	var local_x = int(parsed["x"])
	var local_y = int(parsed["y"])
	var placement = unit_item_inst.get_placement(false)
	var placement_size : Vector2 = placement[0]
	var placement_vectors : Array = placement[1]
	var footprint_w : int = int(placement_size.x)
	var footprint_h : int = int(placement_size.y)

	var board = bm.get_node("BoardUI")
	var board_width : int = int(board.width)
	var board_height : int = int(board.height)

	# Player-board authorship → enemy-side L/R mirror of the footprint top-left.
	var mirrored_x : int = board_width - footprint_w - local_x
	var mirrored_vectors : Array = _mirror_placement_vectors_x(placement_vectors, float(footprint_w))

	# Side strips sit outside the main board (top y < 0, bottom y >= height, plus
	# legacy bottom band height-SIDE_ROWS..height-1).
	var in_top_side_band : bool = local_y < 0
	var in_bottom_side_band : bool = local_y >= board_height - SIDE_ROWS
	var is_side_band : bool = in_top_side_band or in_bottom_side_band

	var strip_local_y = 0
	if is_side_band:
		strip_local_y = _side_strip_local_y(local_y, board_height, in_top_side_band)
		if strip_local_y < 0 or strip_local_y + footprint_h > SIDE_ROWS:
			unit_item_inst.queue_free()
			return null

	var world_spawn_pos: Vector2
	var spawn_pos: Vector2i
	if is_side_band:
		world_spawn_pos = _side_strip_grid_to_world(
			mirrored_x, local_y, strip_local_y, in_bottom_side_band, board_height
		)
		if in_top_side_band:
			spawn_pos = Vector2i(mirrored_x, strip_local_y - SIDE_ROWS)
		else:
			spawn_pos = Vector2i(mirrored_x, board_height + strip_local_y)
	else:
		spawn_pos = Vector2i(mirrored_x, local_y) + grid_size
		world_spawn_pos = _board_grid_to_world(spawn_pos)

	bm.add_unit_to_board(unit_item_inst, world_spawn_pos, mirrored_vectors, false)
	_register_enemy_pack_points(world_spawn_pos, placement_size, unit_item_inst.num_units > 1)

	if is_side_band:
		# Mirror copy on the player-side column at the same logical strip y (unflipped
		# player x — this is the authored left-side counterpart).
		var mirror_world = _board_grid_to_world(Vector2i(local_x, spawn_pos.y))
		bm.add_unit_to_board(unit_item_inst, mirror_world, placement_vectors, false)
		_register_enemy_pack_points(mirror_world, placement_size, unit_item_inst.num_units > 1)

	unit_item_inst.queue_free()
	return spawn_pos


## Flip placement centers horizontally within a footprint of width `footprint_w`.
func _mirror_placement_vectors_x(vectors: Array, footprint_w: float) -> Array:
	var out: Array = []
	for v in vectors:
		var p : Vector2 = v
		out.append(Vector2(footprint_w - p.x, p.y))
	return out


## Maps authored formation y into 0..SIDE_ROWS-1 within the matching side strip.
func _side_strip_local_y(local_y: int, board_height: int, in_top: bool) -> int:
	if in_top:
		return local_y + SIDE_ROWS
	if local_y >= board_height:
		return local_y - board_height
	return local_y - (board_height - SIDE_ROWS)


## World origin for a cell inside SideStripTop / SideStripBottom.
## Editor-authored strip coords (y < 0 or y >= board height) use the strip's own
## X origin. Legacy bottom-band rows keep the normal enemy X offset (grid_size).
func _side_strip_grid_to_world(local_x: int, local_y: int, strip_local_y: int, bottom: bool, board_height: int) -> Vector2:
	var strip = bm.side_strip_bottom_tiles if bottom else bm.side_strip_top_tiles
	if strip == null:
		return _board_grid_to_world(Vector2i(local_x, strip_local_y))
	var cell_w = int(strip.cellWidth)
	var cell_h = int(strip.cellHeight)
	var world_y = strip.global_position.y + strip_local_y * cell_h
	var world_x: float
	if not bottom or local_y >= board_height or local_y < 0:
		world_x = strip.global_position.x + local_x * cell_w
	else:
		var board = bm.get_node("BoardUI")
		world_x = board.global_position.x + (local_x + grid_size.x) * int(board.cellWidth)
	return Vector2(world_x, world_y)


func _register_enemy_pack_points(anchor: Vector2, footprint_size: Vector2, is_multi: bool) -> void:
	if bm == null or not bm.placement_indicators:
		return
	var board = bm.get_node("BoardUI")
	var cell = Vector2(board.cellWidth, board.cellHeight)
	bm.placement_indicators.register_enemy_pack(anchor, footprint_size, cell, is_multi)


## Enemy formations are authored in BoardUI tile coordinates.
## Use board cell size, not BattleManager.tile_size, to avoid oversized spacing.
## board.global_position already carries BoardUI's start_offset (see BoardUI.gd),
## so enemies spawn with the same 1x1 tile offset from 0 as the player board.
func _board_grid_to_world(coord: Vector2i) -> Vector2:
	var board = bm.get_node("BoardUI")
	return board.global_position + Vector2(coord.x * int(board.cellWidth), coord.y * int(board.cellHeight))


## Dev / console: spawn an arbitrary formation list (e.g. from FORMATION_MAP.formation_lookup).
func spawn_formation_rows(rows: Array) -> int:
	if bm and bm.placement_indicators:
		bm.placement_indicators.clear_enemy_packs()
	var seen_groups := {}
	var n := 0
	for parsed in rows:
		if spawn_single_formation_entry(parsed, seen_groups) != null:
			n += 1
	return n


func post_ready():
	bm = get_parent()


# Test support variables
var test_formation_override: Array = []
var test_mode: bool = false

func set_test_formation(formation: Array):
	"""Override formation data for testing purposes"""
	test_formation_override = formation
	test_mode = true

func clear_test_mode():
	"""Return to normal formation selection"""
	test_formation_override.clear()
	test_mode = false



# Modify your get_enemy_spawns function to use test data when available
# Replace this section in your existing get_enemy_spawns function:

# Debug method to expose selection information
func get_last_selections() -> Dictionary:
	"""Get information about the last spawn selections for testing"""
	return recently_seen_units.duplicate()

func get_spawn_statistics() -> Dictionary:
	"""Get statistics about spawning for analysis"""
	return {
		"recently_seen_units": recently_seen_units.duplicate(),
		"used_tiles": used_tiles.duplicate(),
		"test_mode": test_mode
	}
