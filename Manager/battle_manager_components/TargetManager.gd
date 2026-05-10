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
var perf_counters := {
	"queries": 0,
	"cache_hits": 0,
	"bfs_calls": 0,
	"closest_queries": 0,
	"closest_candidates_scanned": 0
}


func reset_cache():
	target_iter = (target_iter + 1) % 100
	cached_allies.clear()
	cached_enemies.clear()


func get_perf_counters() -> Dictionary:
	return perf_counters.duplicate()


func reset_perf_counters() -> void:
	for key in perf_counters.keys():
		perf_counters[key] = 0

# Use BFS to get the local tiles
func get_targets(faction: bool, location: Vector2, num_targets : int = 10, max_range : int = 500) -> Array:
	perf_counters["queries"] += 1
	var target_location : Vector2i = get_parent().world_to_grid(location)
	
	# Check if we have already seen this location
	if target_location in cached_enemies and faction == false:
		perf_counters["cache_hits"] += 1
		if num_targets > cached_enemies[target_location].size():
			num_targets = cached_enemies[target_location].size()
		return cached_enemies[target_location].slice(0, num_targets)
		
	if target_location in cached_allies and faction == true:
		perf_counters["cache_hits"] += 1
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
	perf_counters["bfs_calls"] += 1
		
	# If not seen yet do a BFS up to a max size
	var seen = {}
	var result : Array = []
	
	var curr_depth = 0
	var max_depth = max( int(max_range / get_parent().tile_size), 3) # Ensure a minimum depth is reached for future calcualtions
	
	# Convert location to a point on the grid
	var curr = [get_parent().world_to_grid(location)]
	var next = []
	
	# Search the 8 closest
	while (curr_depth < max_depth and curr):
		curr_depth += 1
		for i in curr:
			seen[i] = true
			for u in src_tiles[i.x][i.y]:
				if _is_living_target(u):
					result.append(u)

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


func get_closest_target(faction: bool, location: Vector2, max_range: int = 500) -> Base_Unit:
	var targets: Array = get_targets(faction, location, 3, max_range)
	perf_counters["closest_queries"] += 1
	var best: Base_Unit = null
	var best_dist_sq :float = INF
	for t in targets:
		if not _is_living_target(t):
			continue
		var d2 : float = (t.position - location).length_squared()
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best = t as Base_Unit
	perf_counters["closest_candidates_scanned"] += targets.size()
	return best


func get_closest_targets(faction: bool, location: Vector2, num_targets: int = 1, max_range: int = 500) -> Array:
	var targets: Array = get_targets(faction, location, num_targets, max_range)
	perf_counters["closest_queries"] += 1
	var scored: Array = []
	for t in targets:
		if not _is_living_target(t):
			continue
		scored.append({
			"target": t,
			"dist_sq": (t.position - location).length_squared()
		})
	perf_counters["closest_candidates_scanned"] += targets.size()
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dist_sq"] < b["dist_sq"]
	)
	var out: Array = []
	var take_n := mini(num_targets, scored.size())
	for i in take_n:
		out.append(scored[i]["target"])
	return out

func _is_living_target(u: Variant) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	if not u is Base_Unit:
		return false
	return u.curr_hp > 0
