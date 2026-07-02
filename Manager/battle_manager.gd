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
signal factory_destroyed
signal friendly_unit_died(unit: Base_Unit)

const UNIT_PICK_RADIUS := 20.0
const FACTORY_UNIT_SCENE := preload("res://Units/unit_scenes/factory_unit/factory_unit.tscn")

var player_health: PlayerHealthManager
var _factory_spawned: bool = false
var _factory_destroyed_handled: bool = false

func setup_battle(battle_params : Dictionary):
	"""Generate enemies for the current battle"""
	if battle_params.has("stage") and battle_params.has("difficulty"):
		var modifiers := {
			"is_blockade": battle_params.get("is_blockade", false),
			"is_chaser_pressured_exit": battle_params.get("is_chaser_pressured_exit", false),
		}
		enemy_spawner.get_enemy_spawns(
			battle_params["stage"],
			battle_params["difficulty"],
			modifiers
		)
	#else:
	
	board_tiles.visible = true

	
func clear_battlefield():
	"""Clear all units from the battlefield and return active projectiles so they don't linger."""
	proj_pool.return_all_active()
	beacon_controller.clear_all()
	for child in unit_parent.get_children():
		child.queue_free()
	_clear_unit_tile_grids()
	_factory_spawned = false
	_factory_destroyed_handled = false

func start_battle():
	manager_timer.start()
	flow_visualizer.redraw_timer.start()
	board_tiles.visible = false
	set_unit_start_stop(true)


func end_battle(victory: bool = true) -> void:
	manager_timer.stop()
	flow_visualizer.redraw_timer.stop()
	set_unit_start_stop(false)
	beacon_controller.clear_all()
	battle_ended.emit(victory)
	

func set_unit_start_stop(stopped : bool):
	for i in unit_parent.get_children():
		if i is Base_Unit:
			i.set_start_stop(stopped)


func _physics_process(_delta: float) -> void:
	if not manager_timer.is_stopped():
		target_man.advance_snapshot_refresh(target_man.snapshot_cells_per_tick)

func check_only_faction_units_alive(faction : bool):
	for i in unit_parent.get_children():
		if i is Base_Unit and i.faction != faction:
			return false
	return true


func _living_units_for_faction(faction: bool, exclude_factory: bool = false) -> Array:
	var out: Array = []
	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var u: Base_Unit = child
		if u.faction != faction or u.curr_hp <= 0:
			continue
		if exclude_factory and u is FactoryUnit:
			continue
		out.append(u)
	return out


func _is_factory_alive() -> bool:
	for u in _living_units_for_faction(true, false):
		if u is FactoryUnit:
			return true
	return false


func _get_factory_spawn_position() -> Vector2:
	var center := Vector2(
		float(board_tiles.width) * board_tiles.cellWidth * 0.5,
		float(board_tiles.height) * board_tiles.cellHeight * 0.5
	)
	return board_tiles.global_position + center


func _try_spawn_factory() -> void:
	if _factory_spawned or player_health == null:
		return
	_factory_spawned = true
	var factory := FACTORY_UNIT_SCENE.instantiate() as FactoryUnit
	if factory == null:
		return
	factory.faction = true
	factory.initial_health_fraction = player_health.get_health_fraction()
	factory.player_health_manager = player_health
	factory.position = _get_factory_spawn_position()
	unit_parent.add_child(factory)
	factory.post_ready()
	factory.set_start_stop(true)
	player_health.sync_from_unit_hp(factory.curr_hp, factory.max_hp)
	if factory.curr_hp <= 0:
		_handle_factory_destroyed()


func _handle_factory_destroyed() -> void:
	if _factory_destroyed_handled:
		return
	_factory_destroyed_handled = true
	manager_timer.stop()
	flow_visualizer.redraw_timer.stop()
	set_unit_start_stop(true)
	factory_destroyed.emit()

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
	var gsm := get_parent()
	if gsm != null and gsm.has_node("PlayerHealthManager"):
		player_health = gsm.get_node("PlayerHealthManager") as PlayerHealthManager
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
		if this_inst is Base_Unit and faction:
			var ally := this_inst as Base_Unit
			if not ally.died.is_connected(_on_ally_unit_died):
				ally.died.connect(_on_ally_unit_died)
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
	var world_pos : Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
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


func _on_ally_unit_died(unit: Base_Unit) -> void:
	if unit is FactoryUnit:
		return
	friendly_unit_died.emit(unit)


func _on_manager_update_timeout():
	if _living_units_for_faction(false).is_empty():
		end_battle(true)
		return

	var living_non_factory_allies := _living_units_for_faction(true, true)
	if living_non_factory_allies.is_empty() and not _living_units_for_faction(false).is_empty():
		if not _factory_spawned:
			_try_spawn_factory()
			return
		if not _is_factory_alive():
			_handle_factory_destroyed()
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
	
