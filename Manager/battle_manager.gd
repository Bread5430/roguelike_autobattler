extends Control

@export_group("Battle Map Config")
@export var map_size : Vector2i
@export var tile_size : int
var tile_map_size : Vector2i 




@onready var unit_parent = $Unit_Parent
@onready var flow_gen = $FlowGen
@onready var target_man = $TargetManager
@onready var board_tiles = $BoardUI
@onready var enemy_spawner = $Enemy_Spawner
@onready var manager_timer = $Manager_Update
#@onready var viewport = $Viewport

var enemies_tiles : Array[Array]
var allies_tiles : Array[Array]

signal battle_ended(victory : bool)

func setup_battle(battle_params : Dictionary):
	"""Generate enemies for the current battle"""
	if battle_params.has("stage") and battle_params.has("difficulty"):
		enemy_spawner.get_enemy_spawns(
			battle_params["stage"],
			battle_params["difficulty"]
		)
	#else:

	
func clear_battlefield():
	"""Clear all units from the battlefield"""

	for child in unit_parent.get_children():
		child.queue_free()
		
	for x in tile_map_size.x:
		for y in tile_map_size.y:
			allies_tiles[x][y].clear()
			enemies_tiles[x][y].clear()

func start_battle():
	manager_timer.start()
	set_unit_start_stop(true)


func end_battle():
	manager_timer.stop()
	set_unit_start_stop(false)
	# TODO: Add way to calculate if the player won or lost
	battle_ended.emit(true)
	

func set_unit_start_stop(stopped : bool):
	for i in unit_parent.get_children():
		i.set_start_stop(stopped)

func check_only_faction_units_alive(faction : bool):
	for i in unit_parent.get_children():
		if i.faction != faction:
			return false
	return true 

# Triggers after both the manager and all its children have entered the scene
func _ready():
	# Initalize the 2D arrays for enemies and allies
	tile_map_size = map_size / tile_size
	for x in tile_map_size.x:
		allies_tiles.append([])
		enemies_tiles.append([])
		for y in tile_map_size.y:
			allies_tiles[x].append([])
			enemies_tiles[x].append([])
	
func post_ready():
	
	for node in get_children():
		if node.has_method("post_ready"):
			node.post_ready()
	
	flow_gen.init_fields()
	for node in unit_parent.get_children():
		node.post_ready()


func world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(pos / tile_size)

func grid_to_world(coord: Vector2i) -> Vector2:
	return coord * tile_size

func update_tiles():
	# Clear the allies and enemies tiles
	for x in tile_map_size.x:
		for y in tile_map_size.y:
			allies_tiles[x][y].clear()
			enemies_tiles[x][y].clear()
			
	for unit in unit_parent.get_children():
		# Convert position to tile position
		var tile = world_to_grid(unit.position)
		# If unit is an allied unit
		if unit.faction:
			allies_tiles[tile.x][tile.y].append(unit)
		else: # If unit is an enemy unit
			enemies_tiles[tile.x][tile.y].append(unit)
 
func add_unit_to_board(unit_ref : Item, start_position : Vector2, placement_vectors : Array, faction : bool) -> void:
	var unit_group : Array = []
	for unit_pos : Vector2 in placement_vectors:
		var this_inst = unit_ref.related_unit.instantiate()
		# This assumes the board tiles are square
		this_inst.position = unit_pos * board_tiles.cellHeight + start_position
		this_inst.faction = faction
		unit_parent.add_child(this_inst)
		unit_group.append(this_inst)
		this_inst.post_ready()
	
func remove_unit_from_board(top_corner: Vector2, size: Vector2) -> void:
	var rect := Rect2(top_corner, size)
	for u in unit_parent.get_children():
		if rect.has_point(u.position):
			u.queue_free()


func _on_manager_update_timeout():
	# Check if we can end the battle
	
	if check_only_faction_units_alive(false): # if only allied units alive at end - you win
		end_battle()
		return
	
	if check_only_faction_units_alive(true):  # if only enemy units alive at end - you lose
		end_battle()
		return
	
	update_tiles()
	
	# Calculate Border Tiles
	flow_gen.get_edge_positions(true)
	flow_gen.get_edge_positions(false)
	
	# Gen Flow
	flow_gen.calculate_flow_field(true)
	flow_gen.calculate_flow_field(false)
	
	# Reset targetting component
	target_man.reset_cache()
	
