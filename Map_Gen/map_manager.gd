extends Node2D

# 2D Map Graph Generator
# Generates a graph of connected battle nodes for campaign progression

@export_group("Map Generation")
@export var map_size := DisplayServer.window_get_size()
@export_subgroup("Grid")
@export var grid_columns := 5
@export var grid_rows := 4
@export_range(0.0, 1.0) var grid_cell_fill_chance := 0.9

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

# Visual colors
var NODE_COLORS = {
	"normal": Color.BLUE,
	"start": Color.GREEN,
	"end": Color.RED,
	"current": Color.YELLOW,
	"completed": Color.GRAY,
	"available": Color.CYAN
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
	
	# Make nodes connected to completed nodes available
	for completed_node in completed_nodes:
		for connected_node in completed_node.connections:
			if not connected_node.completed:
				connected_node.available = true

func complete_current_battle():
	current_node.completed = true
	completed_nodes.append(current_node)
	update_node_availability()

# =============================================================================
# PLAYER MOVEMENT
# =============================================================================

func _on_player_movement_finished():
	"""Called when player finishes moving to a node"""
	is_player_moving = false
	
	if pending_node and pending_node.available:
		# Player has reached the node, now update other nodes
		current_node = pending_node
		
		queue_redraw()
		
		# Update other nodes
		selected_node.emit(pending_node)
		pending_node = null
	else: 
		push_warning("Attempted to start battle at unavailable node")


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
	"""Draw all nodes with appropriate colors"""
	for node in nodes:
		var color = get_node_color(node)
		draw_circle(node.global_position, node_radius, color)
		
		# Draw border
		draw_arc(node.global_position, node_radius, 0, TAU, 32, Color.WHITE, 2.0)

func draw_node_labels_visual():
	"""Draw labels on nodes"""
	var font = ThemeDB.fallback_font
	var font_size = 12
	
	for node in nodes:
		var label = str(node.id)
		var text_size = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = node.global_position - text_size / 2
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func get_node_color(node: MapNode) -> Color:
	"""Get the appropriate color for a node based on its state"""
	if node.completed:
		return NODE_COLORS.completed
	elif node == current_node:
		return NODE_COLORS.current
	elif node.available:
		return NODE_COLORS.available
	elif node == start_node:
		return NODE_COLORS.start
	elif node == end_node:
		return NODE_COLORS.end
	else:
		return NODE_COLORS.normal

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
			if node.available:
				# Check if player needs to move first
				if player_sprite and is_player_moving == false:
					# Player needs to move to this node first
					pending_node = node
					move_player_to_node(node)
				elif current_node != node: # Handle revisiting current node case
					move_player_to_node(node)
				
			else:
				print("Node %d is available to visit" % node.id)
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
		"current_node_id": current_node.id if current_node else -1
	}
	
	for node in completed_nodes:
		state.completed_node_ids.append(node.id)
	
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
	
	# Update availability and player global_position
	update_node_availability()
	
	if current_node and player_sprite:
		if player_sprite.has_method("set_pos"):
			player_sprite.set_pos(current_node.global_position)
	
	queue_redraw()
