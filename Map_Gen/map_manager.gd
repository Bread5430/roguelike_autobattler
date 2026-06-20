extends Node2D

# 2D Map Graph Generator
# Generates a graph of connected battle nodes for campaign progression

@export_group("Map Generation")
@export var map_size := DisplayServer.window_get_size()
@export_subgroup("Grid")
@export var grid_columns := 5
@export var grid_rows := 4
@export_range(0.0, 1.0) var grid_cell_fill_chance := 0.9

@export_group("Special Node Distribution")
@export var random_event_node_count := 2
@export var repair_site_node_count := 1
@export var shop_node_count := 1

@export_group("Visual Settings")
@export var node_radius := 15.0
@export var draw_connections := true
@export var draw_node_labels := true
@export var highlight_path := true


@export_group("Player Movement")
@export var player_sprite: Node2D  # Reference to your player_location scene

# Map data structures
var nodes: Array[MapNode] = []
var connections: Array[MapConnection] = []
var start_node: MapNode
var end_node: MapNode
var current_node: MapNode
var completed_nodes: Array[MapNode] = []

# Player movement state
var is_player_moving := false
var pending_node: MapNode
var debug_teleport_on_click := false
var _debug_bypass_availability := false

const CONTENT_TYPE_COLORS := {
	MapNode.ContentType.BATTLE: Color(0.2, 0.45, 0.95),
	MapNode.ContentType.RANDOM_EVENT: Color(0.65, 0.25, 0.85),
	MapNode.ContentType.REPAIR_SITE: Color(0.95, 0.55, 0.15),
	MapNode.ContentType.SHOP: Color(0.95, 0.85, 0.2),
}

const CONTENT_TYPE_LABELS := {
	MapNode.ContentType.BATTLE: "B",
	MapNode.ContentType.RANDOM_EVENT: "?",
	MapNode.ContentType.REPAIR_SITE: "R",
	MapNode.ContentType.SHOP: "$",
}

# Signals
signal selected_node(node: MapNode)

######### MANAGER CODE ########

func _ready():
	# Connect player movement signal if player sprite exists
	if player_sprite and player_sprite.has_signal("done_moving"):
		player_sprite.done_moving.connect(_on_player_movement_finished)
	
	# global_position player at start node initially
	if start_node and player_sprite:
		if player_sprite.has_method("set_pos"):
			player_sprite.set_pos(start_node.global_position)

#func post_ready():
#	generate_map()

func _draw():
	draw_map()

func generate_map():
	"""Generate the complete map graph"""
	print("Generating map graph...")

	generate_nodes()
	connect_grid_neighbors()
	ensure_reachability_bridges()
	identify_start_end_nodes()
	assign_special_node_types()
	calculate_difficulty_progression()
	update_node_availability()
	
	print("Map generation complete. Nodes: %d, Connections: %d" % [nodes.size(), connections.size()])
	queue_redraw()

func generate_nodes():
	"""Place nodes on an N×M grid: each cell has a chance to spawn one node at a random point inside the cell."""
	nodes.clear()
	var cols := maxi(1, grid_columns)
	var rows := maxi(1, grid_rows)
	var cell_w := map_size.x / float(cols)
	var cell_h := map_size.y / float(rows)
	var next_id := 0
	for gy in range(rows):
		for gx in range(cols):
			if randf() > grid_cell_fill_chance:
				continue
			var min_x := gx * cell_w + node_radius
			var max_x := (gx + 1) * cell_w - node_radius
			var min_y := gy * cell_h + node_radius
			var max_y := (gy + 1) * cell_h - node_radius
			if max_x <= min_x or max_y <= min_y:
				continue
			var pos := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
			var node := MapNode.new(next_id, pos)
			node.grid_cell = Vector2i(gx, gy)
			nodes.append(node)
			next_id += 1

func connect_grid_neighbors():
	"""Connect every pair of nodes whose grid cells are within one step (8-neighborhood, Chebyshev distance 1)."""
	connections.clear()
	var cell_to_node: Dictionary = {}
	for node in nodes:
		cell_to_node[node.grid_cell] = node
	for node in nodes:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var neighbor_cell := node.grid_cell + Vector2i(dx, dy)
				if not cell_to_node.has(neighbor_cell):
					continue
				var other: MapNode = cell_to_node[neighbor_cell]
				if not node_is_connected(node, other):
					create_connection(node, other)

func _bfs_reachable_from(start: MapNode) -> Array[MapNode]:
	var visited: Array[MapNode] = []
	var queue: Array[MapNode] = [start]
	while not queue.is_empty():
		var n: MapNode = queue.pop_front()
		if n in visited:
			continue
		visited.append(n)
		for c in n.connections:
			if c not in visited:
				queue.append(c)
	return visited

func ensure_reachability_bridges():
	"""If the graph is disconnected, repeatedly connect an unreachable node to the closest reachable node."""
	if nodes.size() <= 1:
		return
	var visited := _bfs_reachable_from(nodes[0])
	while visited.size() < nodes.size():
		var best_u: MapNode = null
		var best_v: MapNode = null
		var best_d := INF
		for u in nodes:
			if u in visited:
				continue
			for v in visited:
				var d := u.global_position.distance_to(v.global_position)
				if d < best_d:
					best_d = d
					best_u = u
					best_v = v
		if best_u and best_v and not node_is_connected(best_u, best_v):
			create_connection(best_u, best_v)
			print("Connected unreachable node %d to closest reachable node %d" % [best_u.id, best_v.id])
		visited = _bfs_reachable_from(nodes[0])

func node_is_connected(node1: MapNode, node2: MapNode) -> bool:
	"""Check if two nodes are already connected"""
	return node2 in node1.connections

func create_connection(node1: MapNode, node2: MapNode):
	"""Create a bidirectional connection between two nodes"""
	node1.connections.append(node2)
	node2.connections.append(node1)
	connections.append(MapConnection.new(node1, node2))

func identify_start_end_nodes():
	"""Find leftmost and rightmost nodes as start and end"""
	if nodes.size() == 0:
		return
	
	# Find leftmost node (start)
	start_node = nodes[0]
	for node in nodes:
		if node.global_position.x < start_node.global_position.x:
			start_node = node
	
	# Find rightmost node (end)
	end_node = nodes[0]
	for node in nodes:
		if node.global_position.x > end_node.global_position.x:
			end_node = node
	
	# Set node types
	start_node.node_type = "start"
	start_node.completed = true
	completed_nodes.append(start_node)
	current_node = start_node
	
	end_node.node_type = "end"

func assign_special_node_types() -> void:
	"""After generation, all nodes are battles; convert some into special node types."""
	var eligible: Array[MapNode] = []
	for node in nodes:
		node.content_type = MapNode.ContentType.BATTLE
		if node != start_node and node != end_node:
			eligible.append(node)
	eligible.shuffle()

	var next_idx := 0
	next_idx = _assign_content_type_from_pool(eligible, next_idx, MapNode.ContentType.RANDOM_EVENT, random_event_node_count)
	next_idx = _assign_content_type_from_pool(eligible, next_idx, MapNode.ContentType.REPAIR_SITE, repair_site_node_count)
	_assign_content_type_from_pool(eligible, next_idx, MapNode.ContentType.SHOP, shop_node_count)

	print(
		"Special nodes assigned — events: %d, repair: %d, shop: %d, battle: %d"
		% [_count_nodes_with_content_type(MapNode.ContentType.RANDOM_EVENT),
		   _count_nodes_with_content_type(MapNode.ContentType.REPAIR_SITE),
		   _count_nodes_with_content_type(MapNode.ContentType.SHOP),
		   _count_nodes_with_content_type(MapNode.ContentType.BATTLE)]
	)

func _assign_content_type_from_pool(
	pool: Array[MapNode],
	start_idx: int,
	target_type: MapNode.ContentType,
	count: int
) -> int:
	var assigned := 0
	var idx := start_idx
	while assigned < count and idx < pool.size():
		pool[idx].content_type = target_type
		assigned += 1
		idx += 1
	return idx

func _count_nodes_with_content_type(target_type: MapNode.ContentType) -> int:
	var total := 0
	for node in nodes:
		if node.content_type == target_type:
			total += 1
	return total

func calculate_difficulty_progression():
	"""Calculate difficulty and stage for each node based on distance from start"""
	if not start_node:
		return
	
	# Use breadth-first search to assign stages based on distance from start
	var visited: Array[MapNode] = []
	var queue: Array = [{"node": start_node, "stage": 1}]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var node: MapNode = current.node
		var stage: int = current.stage
		
		if node in visited:
			continue
		
		visited.append(node)
		node.stage = stage
		
		# Assign difficulty based on stage
		if stage <= 3:
			node.difficulty = "light"
		elif stage <= 6:
			node.difficulty = "medium"
		else:
			node.difficulty = "heavy"
		
		# Add connected nodes to queue
		for connected_node in node.connections:
			if connected_node not in visited:
				queue.append({"node": connected_node, "stage": stage + 1})

func update_node_availability():
	"""Update which nodes are available for selection"""
	for node in nodes:
		node.available = false
	
	# Neighbors of completed nodes are reachable.
	for completed_node in completed_nodes:
		for connected_node in completed_node.connections:
			if not connected_node.completed:
				connected_node.available = true
	
	# Standing at an uncompleted node also exposes its neighbors (e.g. debug teleport).
	if current_node and current_node not in completed_nodes:
		for connected_node in current_node.connections:
			if not connected_node.completed:
				connected_node.available = true

func complete_current_battle():
	current_node.completed = true
	completed_nodes.append(current_node)
	update_node_availability()


func complete_map_node(node: MapNode) -> void:
	if node == null or node.completed:
		return
	node.completed = true
	if node not in completed_nodes:
		completed_nodes.append(node)
	update_node_availability()

# =============================================================================
# PLAYER MOVEMENT
# =============================================================================

func _on_player_movement_finished():
	"""Called when player finishes moving to a node"""
	is_player_moving = false
	
	if pending_node and (pending_node.available or _debug_bypass_availability):
		var was_debug_teleport := _debug_bypass_availability
		# Player has reached the node, now update other nodes
		current_node = pending_node
		_debug_bypass_availability = false
		
		if was_debug_teleport:
			update_node_availability()
		
		queue_redraw()
		
		# Update other nodes
		selected_node.emit(pending_node)
		pending_node = null
	else:
		_debug_bypass_availability = false
		pending_node = null
		push_warning("Attempted to start battle at unavailable node")


func enable_debug_teleport_on_click() -> void:
	"""Debug: next map node click moves the player there, ignoring availability."""
	debug_teleport_on_click = true


func move_player_to_node(target_node: MapNode):
	"""Move player sprite to specified node"""
	if not player_sprite:
		push_warning("No player sprite assigned")
		return
	
	if not player_sprite.has_method("move_to"):
		push_warning("Player sprite missing move_to method")
		return
	
	is_player_moving = true
	player_sprite.move_to(target_node.global_position)

# =============================================================================
# BATTLE INTEGRATION
# =============================================================================

func complete_node():
	"""Mark current node as completed and update availability"""
	if not current_node:
		push_warning("No node to complete")
		return
	
	print("Completed node %d" % current_node.id)
	
	current_node.completed = true
	completed_nodes.append(current_node)
	
	# Update node availability
	update_node_availability()
	
	current_node = null
	queue_redraw()


# =============================================================================
# VISUAL RENDERING
# =============================================================================

func draw_map():
	"""Draw the complete map graph"""
	if draw_connections:
		draw_connections_visual()
	
	draw_nodes_visual()
	
	if draw_node_labels:
		draw_node_labels_visual()

func draw_connections_visual():
	"""Draw lines between connected nodes"""
	for connection in connections:
		var color = Color.WHITE
		var width = 2.0
		
		# Highlight path to current node
		if highlight_path and current_node:
			if (connection.from_node.completed and connection.to_node == current_node) or \
			   (connection.to_node.completed and connection.from_node == current_node):
				color = Color.YELLOW
				width = 3.0
		
		draw_line(connection.from_node.global_position, connection.to_node.global_position, color, width)

func draw_nodes_visual():
	"""Draw all nodes with shape and color based on content type and state."""
	for node in nodes:
		var color := get_node_color(node)
		draw_node_shape(node, color)
		draw_node_border(node)

func draw_node_shape(node: MapNode, color: Color) -> void:
	var pos := node.global_position
	var r := node_radius
	match node.content_type:
		MapNode.ContentType.RANDOM_EVENT:
			draw_colored_polygon(
				PackedVector2Array([
					pos + Vector2(0, -r),
					pos + Vector2(r, 0),
					pos + Vector2(0, r),
					pos + Vector2(-r, 0),
				]),
				color
			)
		MapNode.ContentType.REPAIR_SITE:
			draw_circle(pos, r, color)
			var arm := r * 0.55
			var thickness := r * 0.22
			draw_rect(Rect2(pos.x - arm, pos.y - thickness * 0.5, arm * 2.0, thickness), Color.WHITE)
			draw_rect(Rect2(pos.x - thickness * 0.5, pos.y - arm, thickness, arm * 2.0), Color.WHITE)
		MapNode.ContentType.SHOP:
			draw_rect(Rect2(pos.x - r, pos.y - r, r * 2.0, r * 2.0), color)
		_:
			draw_circle(pos, r, color)

func draw_node_border(node: MapNode) -> void:
	var pos := node.global_position
	var r := node_radius
	var border_color := Color.WHITE
	var border_width := 2.0
	if node == current_node:
		border_color = Color.YELLOW
		border_width = 3.0
	elif node.available:
		border_color = Color.CYAN
		border_width = 2.5
	match node.content_type:
		MapNode.ContentType.RANDOM_EVENT:
			draw_polyline(
				PackedVector2Array([
					pos + Vector2(0, -r),
					pos + Vector2(r, 0),
					pos + Vector2(0, r),
					pos + Vector2(-r, 0),
					pos + Vector2(0, -r),
				]),
				border_color,
				border_width
			)
		MapNode.ContentType.SHOP:
			draw_rect(Rect2(pos.x - r, pos.y - r, r * 2.0, r * 2.0), border_color, false, border_width)
		_:
			draw_arc(pos, r, 0, TAU, 32, border_color, border_width)

func draw_node_labels_visual():
	"""Draw labels on nodes"""
	var font = ThemeDB.fallback_font
	var font_size = 12
	
	for node in nodes:
		var label = CONTENT_TYPE_LABELS.get(node.content_type, str(node.id))
		var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = node.global_position - text_size / 2
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func get_node_color(node: MapNode) -> Color:
	"""Get fill color from content type, modulated by path role and visit state."""
	if node == start_node:
		return Color.GREEN
	if node == end_node:
		return Color.RED

	var base_color: Color = CONTENT_TYPE_COLORS.get(node.content_type, Color.BLUE)
	if node.completed:
		return base_color.lerp(Color.GRAY, 0.65)
	if node == current_node:
		return base_color.lerp(Color.YELLOW, 0.45)
	if node.available:
		return base_color.lightened(0.15)
	return base_color.darkened(0.15)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_node_click(get_global_mouse_position())

func handle_node_click(click_global_position: Vector2):
	"""Handle clicking on nodes with player movement integration"""
	# Don't process clicks while player is moving
	if is_player_moving:
		return
	
	for node in nodes:
		if click_global_position.distance_to(node.global_position) <= node_radius:
			var can_visit := node.available or debug_teleport_on_click
			if can_visit:
				if debug_teleport_on_click:
					debug_teleport_on_click = false
					_debug_bypass_availability = true
				pending_node = node
				move_player_to_node(node)
			else:
				print("Node %d is not available to visit" % node.id)
			break

# =============================================================================
# PUBLIC INTERFACE
# =============================================================================

func get_camera_center_position() -> Vector2:
	return global_position

func regenerate_map():
	"""Regenerate the entire map"""
	completed_nodes.clear()
	current_node = null
	generate_map()
	
	# Reglobal_position player at start node
	if start_node and player_sprite:
		if player_sprite.has_method("set_pos"):
			player_sprite.set_pos(start_node.global_position)

func get_available_nodes() -> Array[MapNode]:
	"""Get all currently available nodes"""
	var available: Array[MapNode] = []
	for node in nodes:
		if node.available and not node.completed:
			available.append(node)
	return available

func get_map_progress() -> Dictionary:
	"""Get current map progress statistics"""
	return {
		"total_nodes": nodes.size(),
		"completed_nodes": completed_nodes.size(),
		"available_nodes": get_available_nodes().size(),
		"current_stage": current_node.stage if current_node else 0,
		"campaign_complete": end_node.completed if end_node else false
	}

func save_map_state() -> Dictionary:
	"""Save current map state for persistence"""
	var state = {
		"completed_node_ids": [],
		"current_node_id": current_node.id if current_node else -1,
		"node_content_types": {},
	}
	
	for node in completed_nodes:
		state.completed_node_ids.append(node.id)
	for node in nodes:
		state.node_content_types[node.id] = node.content_type
	
	return state

func load_map_state(state: Dictionary):
	"""Load map state from saved data"""
	completed_nodes.clear()
	
	# Mark completed nodes
	for node_id in state.get("completed_node_ids", []):
		for node in nodes:
			if node.id == node_id:
				node.completed = true
				completed_nodes.append(node)
				break
	
	# Set current node
	var current_id = state.get("current_node_id", -1)
	current_node = null
	for node in nodes:
		if node.id == current_id:
			current_node = node
			break

	var saved_content_types: Dictionary = state.get("node_content_types", {})
	for node in nodes:
		if saved_content_types.has(node.id):
			node.content_type = saved_content_types[node.id]
	
	# Update availability and player global_position
	update_node_availability()
	
	if current_node and player_sprite:
		if player_sprite.has_method("set_pos"):
			player_sprite.set_pos(current_node.global_position)
	
	queue_redraw()
