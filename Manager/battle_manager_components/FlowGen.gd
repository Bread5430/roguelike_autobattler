extends Node

const DIRECTIONS = [
	Vector2.UP,
	Vector2.DOWN,
	Vector2.LEFT,
	Vector2.RIGHT
]


var friendly_flow = []
var enemy_flow = []
var friendly_border_tiles = []
var enemy_border_tiles = []

# Find all edges 
# Use the positions of the first units hit to create a border that we want to flow towards
# Calculate a flow field for the 10 tiles around this border

# Set up flow field size and fill then with zero vectors
func init_fields():
	var field_size = get_parent().tile_map_size
	for r in range(field_size.x):
		friendly_flow.append([])
		enemy_flow.append([])
		for c in range(field_size.y):  
			friendly_flow[r].append(Vector2.ZERO)
			enemy_flow[r].append(Vector2.ZERO)
			

func get_edge_positions(faction : bool) -> void:
	var matrix
	
	if faction:
		matrix = get_parent().allies_tiles
	else:
		matrix = get_parent().enemies_tiles
		
	
	var rows = get_parent().tile_map_size.x
	var cols = get_parent().tile_map_size.y

	var border_tiles = []
	for r in range(rows):
		for c in range(cols):
			if matrix[r][c].size() > 0:
				var edge_tile = false
				# Check 4-directional neighbors
				for dir in DIRECTIONS:
					var nr = r + dir.x
					var nc = c + dir.y
					# Check if this tile is one edge of map
					if nr < 0 or nr >= rows or nc < 0 or nc >= cols or matrix[nr][nc].is_empty():
						edge_tile = true
						break  # Guarenteed to be edge if on edge of map
						# Or if near empty tile 
				
				if edge_tile:
					border_tiles.append(Vector2(r, c))

	if faction:
		friendly_border_tiles = border_tiles
	else:
		enemy_border_tiles = border_tiles

func calculate_flow_field(faction: bool) -> void:
	var curr_flow_field
	var border_tiles
	
	if faction:
		curr_flow_field = friendly_flow
		border_tiles = friendly_border_tiles
	else:
		curr_flow_field = enemy_flow
		border_tiles = enemy_border_tiles
	
	if border_tiles.is_empty():
		push_warning("No border tiles found for faction: %s" % faction)
		return	
	
	var rows = get_parent().tile_map_size.x
	var cols = get_parent().tile_map_size.y
	
	# For each tile, find closest border and create normalized direction vector
	for r in range(rows):
		for c in range(cols):
			var current_pos = Vector2(r, c)
			var min_dist_squared: float = INF
			var closest_border: Vector2 = Vector2.ZERO
			var is_border = false
			
			# Check if current tile IS a border tile
			for border in border_tiles:
				if border.x == r and border.y == c:
					is_border = true
					break
			
			# Border tiles have zero flow (they're the destination)
			if is_border:
				curr_flow_field[r][c] = Vector2.ZERO
				continue
			
			# Find closest border tile
			for border in border_tiles:
				var dist_squared = current_pos.distance_squared_to(border)
				
				if dist_squared < min_dist_squared:
					min_dist_squared = dist_squared
					closest_border = border
			
			# Calculate direction vector and NORMALIZE it
			var direction = closest_border - current_pos
			
			if direction.length() > 0:
				curr_flow_field[r][c] = direction.normalized()
			else:
				curr_flow_field[r][c] = Vector2.ZERO
				
	if faction:
		friendly_flow = curr_flow_field
	else:
		enemy_flow = curr_flow_field

func get_flow(faction : bool, position : Vector2) -> Vector2:
	var target_location = get_parent().world_to_grid(position)
	
	# Check if we have already seen this location
	if faction:
		return friendly_flow[target_location.x][target_location.y]
	else:
		return enemy_flow[target_location.x][target_location.y]
