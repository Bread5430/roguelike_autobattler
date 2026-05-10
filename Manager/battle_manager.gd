extends Control

@export_group("Battle Map Config")
@export var map_size : Vector2i
@export var tile_size : int
@export var debug_target_perf: bool = false
var tile_map_size : Vector2i 



@onready var unit_parent = $Unit_Parent
@onready var flow_gen = $FlowGen
@onready var target_man = $TargetManager
@onready var board_tiles = $BoardUI
@onready var enemy_spawner = $Enemy_Spawner
@onready var manager_timer = $Manager_Update
@onready var flow_visualizer = $flow_visualizer
@onready var spell_manager = $Spell_Manager
@onready var proj_pool = $Proj_Pool
@onready var beacon_controller: BeaconController = $BeaconController
#@onready var viewport = $Viewport

## Set by GUI for beacon spell validation (selected ally near path start).
var tactical_cursor: Node = null

var enemies_tiles : Array[Array]
var allies_tiles : Array[Array]

signal battle_ended(victory : bool)
signal unit_selected(unit: Base_Unit)

const UNIT_PICK_RADIUS := 20.0

func setup_battle(battle_params : Dictionary):
	"""Generate enemies for the current battle"""
	if battle_params.has("stage") and battle_params.has("difficulty"):
		enemy_spawner.get_enemy_spawns(
			battle_params["stage"],
			battle_params["difficulty"]
		)
	#else:
	
	board_tiles.visible = true

	
func clear_battlefield():
	"""Clear all units from the battlefield and return active projectiles so they don't linger."""
	if proj_pool and proj_pool.has_method("return_all_active"):
		proj_pool.return_all_active()
	if beacon_controller:
		beacon_controller.clear_all()
	for child in unit_parent.get_children():
		child.queue_free()
	_clear_unit_tile_grids()

func start_battle():
	manager_timer.start()
	flow_visualizer.redraw_timer.start()
	board_tiles.visible = false
	set_unit_start_stop(true)


func end_battle():
	manager_timer.stop()
	flow_visualizer.redraw_timer.stop()
	set_unit_start_stop(false)
	if beacon_controller:
		beacon_controller.clear_all()
	# TODO: Add way to calculate if the player won or lost
	battle_ended.emit(true)
	

func set_unit_start_stop(stopped : bool):
	for i in unit_parent.get_children():
		if i is Base_Unit:
			i.set_start_stop(stopped)

func check_only_faction_units_alive(faction : bool):
	for i in unit_parent.get_children():
		if i is Base_Unit and i.faction != faction:
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
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
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

# Clear the allies and enemies tiles
func _clear_unit_tile_grids():
	for x in tile_map_size.x:
		for y in tile_map_size.y:
			allies_tiles[x][y].clear()
			enemies_tiles[x][y].clear()

func update_tiles():
	_clear_unit_tile_grids()
			
	for unit in unit_parent.get_children():
		if not unit is Base_Unit:
			continue
		# Convert position to tile position
		var tile = world_to_grid(unit.position)
		# If unit is an allied unit
		if unit.faction:
			allies_tiles[tile.x][tile.y].append(unit)
		else: # If unit is an enemy unit
			enemies_tiles[tile.x][tile.y].append(unit)
 
func add_unit_to_board(unit_ref : Item, start_position : Vector2, placement_vectors : Array, faction : bool) -> void:
	#var unit_group : Array = []
	for unit_pos : Vector2 in placement_vectors:
		var this_inst = unit_ref.related_unit.instantiate()
		# This assumes the board tiles are square
		this_inst.position = unit_pos * board_tiles.cellHeight + start_position
		this_inst.faction = faction
		unit_parent.add_child(this_inst)
		#unit_group.append(this_inst)
		this_inst.post_ready()
	
func remove_unit_from_board(top_corner: Vector2i, size: Vector2) -> void:
	for u in unit_parent.get_children():
		if not u is Base_Unit:
			continue
		var unit_pos := (u as Base_Unit).position
		var unit_tile := Vector2i(
			int(unit_pos.x / board_tiles.cellHeight),
			int(unit_pos.y / board_tiles.cellHeight)
		)
		var in_x := unit_tile.x >= top_corner.x and unit_tile.x < top_corner.x + int(size.x)
		var in_y := unit_tile.y >= top_corner.y and unit_tile.y < top_corner.y + int(size.y)
		if in_x and in_y:
			u.queue_free()


## Called by InputCoordinator for game-area clicks in BATTLE_ACTIVE.
## Converts event position to world (camera transform) and finds unit under cursor.
func handle_unit_click(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var vp := get_viewport()
	var world_pos : Vector2 = vp.get_canvas_transform().affine_inverse() * event.position
	var unit := get_unit_under_cursor(world_pos)
	if unit:
		unit_selected.emit(unit)

## Returns the unit under the given world position (only used on click).
func get_unit_under_cursor(world_pos: Vector2) -> Base_Unit:
	var best_unit: Base_Unit = null
	var best_dist := INF
	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var u := child as Base_Unit
		var d := world_pos.distance_to(u.global_position)
		if d <= UNIT_PICK_RADIUS and d < best_dist:
			best_dist = d
			best_unit = u
	return best_unit

func get_spell_modification(location : Vector2, modifiable_attributes : Dictionary):
	spell_manager.spell_modification(location, modifiable_attributes)

func _on_manager_update_timeout():
	# Check if we can end the battle
	
	if check_only_faction_units_alive(false): # if only allied units alive at end - you win
		end_battle()
		return
	
	if check_only_faction_units_alive(true):  # if only enemy units alive at end - you lose
		# TODO: make the player lose the game
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
	if debug_target_perf and target_man.has_method("get_perf_counters"):
		var counters: Dictionary = target_man.get_perf_counters()
		print("Target perf tick:", counters)
		if target_man.has_method("reset_perf_counters"):
			target_man.reset_perf_counters()
	
