extends Node

const DIRECTIONS = [
	Vector2i(1,0),
	Vector2i(0,1),
	Vector2i(1,1),
	Vector2i(-1,0),
	Vector2i(0,-1),
	Vector2i(-1,-1),
	Vector2i(1,-1),
	Vector2i(-1,1)
]

var cached_enemies = {}
var cached_allies = {}
var target_iter = 0


func reset_cache():
	target_iter = (target_iter + 1) % 100
	cached_allies.clear()
	cached_enemies.clear()

# Use BFS to get the local tiles
func get_targets(faction: bool, location: Vector2, num_targets : int = 10, max_range : int = 500) -> Array:
	var target_location : Vector2i = get_parent().world_to_grid(location)
	
	# Check if we have already seen this location
	if target_location in cached_enemies and faction == false:
		cached_enemies[target_location] = _remove_nulls(cached_enemies[target_location])
		if num_targets > cached_enemies[target_location].size():
			num_targets = cached_enemies[target_location].size()
		return cached_enemies[target_location].slice(0, num_targets)
		
	if target_location in cached_allies and faction == true:
		cached_allies[target_location] = _remove_nulls(cached_allies[target_location])
		if num_targets > cached_allies[target_location].size():
			num_targets = cached_allies[target_location].size()
		return cached_allies[target_location].slice(0, num_targets)
	
	
	# Add different things to results based on what faction is being targetted
	# True means targetting allies
	var src_tiles
	if faction:
		src_tiles =  get_parent().allies_tiles
	else: # False is targetting enemies
		src_tiles = get_parent().enemies_tiles
		
	# If not seen yet do a BFS up to a max size
	var seen = {}
	var result : Array = []
	
	var curr_depth = 0
	var max_depth = max( int(max_range / get_parent().tile_size), 5) # Ensure a minimum depth is reached for future calcualtions
	
	# Convert location to a point on the grid
	var curr = [get_parent().world_to_grid(location)]
	var next = []
	
	# Search the 8 closest
	while (curr_depth < max_depth and curr):
		curr_depth += 1
		for i in curr:
			seen[i] = true
			result += src_tiles[i.x][i.y]

			for dir in DIRECTIONS:
				var next_loc = Vector2i(i + dir)
				if next_loc not in seen and \
				next_loc.x > 0 and next_loc.x < get_parent().tile_map_size.x - 1 and \
				next_loc.y > 0 and next_loc.y < get_parent().tile_map_size.y - 1:
					next.append(next_loc)
		
		curr = next
		next = []
		
	# Insert this item into cache
	if faction:
		cached_allies[target_location] = result
	else:
		cached_enemies[target_location] = result
	
	# Ensure that we only send a valid number of enemies - need to handle this on the unit end as well
	if num_targets > result.size():
		num_targets = result.size()
		
	return result.slice(0, num_targets)

func _remove_nulls(array : Array) -> Array:
	var new_array = []
	for i in array:
		if i != null:
			new_array.append(i)
	return new_array
