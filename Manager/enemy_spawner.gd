
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

@export var grid_size := Vector2i(8, 8)


#var unit_bitstring_cache = {}
var recently_seen_units = {}
var used_tiles = {}

func get_enemy_spawns(stage: int, difficulty: String) -> Array:
	# Reset spawned tiles
	used_tiles = {}
	
	# Decay spawn probabilities - int rounds down so eventually goes back to zero prob of spawn
	for u in recently_seen_units.keys():
		recently_seen_units[u] = int(recently_seen_units[u]/2)
	
	# Get a random formation
	if not FORMATION_MAP.LEVELS.has(difficulty):
		push_warning("Invalid difficulty: %s" % difficulty)
		return []
	var formation = FORMATION_MAP.random_formation(difficulty)
	
	# Start filling in the formation with spawns
	var all_spawn_positions: Array = []
	var seen_groups = {}
	
	for spawn_str in formation:
		# Parse the formation string to determine what to spawn
		var parsed := parse_spawn_string(spawn_str)
		if parsed.is_empty():
			push_warning("Malformed Spawn String %s" % spawn_str)
			continue
			
		var spawn_pos := Vector2i(parsed["x"], parsed["y"]) + grid_size
		var size := Vector2i(parsed["w"], parsed["h"])
		var role: int = parsed["role"]
		var unit_group: int = parsed["group"]
		var selected_unit_scene: PackedScene
		
		# Check if we already have a unit selected for this group
		if unit_group in seen_groups:
			selected_unit_scene = seen_groups[unit_group]
		else: # If not - randomly select a new unit for this group
			var unit_options := get_unit_by_role_cached(role)
			if not unit_options:
				push_warning("Unknown unit role: %s" % role)
				continue
			selected_unit_scene = weighted_random_selections(unit_options)
			seen_groups[unit_group] = selected_unit_scene
		
		# Check if we have an exact type specified
		if parsed.has("exact_type"):
			# Override with the exact unit type if specified
			selected_unit_scene = ITEM_NAME.item_lookup(parsed["exact_type"])
			if not selected_unit_scene:
				push_warning("Unknown exact unit type: %s" % parsed["exact_type"])
				continue
		
		# Get the Item instance to determine placement vectors
		var unit_item_inst = selected_unit_scene.instantiate()
		if not unit_item_inst.has_method("get_placement_vectors"):
			push_warning("Unit doesn't have placement vectors method")
			unit_item_inst.queue_free()
			continue
		
		# Calculate world position for spawning
		var world_spawn_pos = bm.grid_to_world(spawn_pos)
		
		# Generate placement vectors based on the spawn area size
		var placement_vectors = unit_item_inst.placement_vectors
		
		# Use battle manager's add_unit_to_board function
		bm.add_unit_to_board(unit_item_inst, world_spawn_pos, placement_vectors)
		
		# Clean up the temporary instance
		unit_item_inst.queue_free()
		
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

func parse_spawn_string(s: String) -> Dictionary:
	var regex = RegEx.new()
	# Updated regex to include optional string parameter at the end
	# The string can contain any characters except closing bracket
	regex.compile(r"\[(\d+),(\d+),(\d+),(\d+),(\d+),(\d+)(?:,([^\]]+))?\]")

	var result = regex.search(s)
	if result:
		var parsed_data = {
			"x": result.get_string(1).to_int(),
			"y": result.get_string(2).to_int(),
			"w": result.get_string(3).to_int(),
			"h": result.get_string(4).to_int(),
			"role": result.get_string(5).to_int(),
			"group": result.get_string(6).to_int(),
		}
		
		# Add optional string parameter if present
		if result.get_string(7) != "":
			parsed_data["exact_type"] = result.get_string(7)
		
		return parsed_data
		
	return {}


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
