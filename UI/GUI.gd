extends Control
@onready var post_ready_check = false

#### DEBUG VARS
@export var selector_rect_debug : bool = true
var selector_rect : Rect2

#### NODE REFERENCES
@export var battle_manager : Control
var inventory : Inventory
var unit_board : GridContainer
@onready var spell_bar : GridContainer = $SpellBar
@onready var end_prep : Button = $End_Prep


#### UNIT PLACEMENT VARS
var unit_board_height : int
var unit_board_width : int

var unit_board_space_map : Array[Array] = [] # Stores references to units on the board for removal

#### Store these state variables in globals since they are required by the input events

# Variables related to unit placement when in deployment stage
var deployment_mode : bool = false
var targetCell
var objectCells = []
var curr_unit : PackedScene
var curr_unit_inst : Item
var curr_inv_slot : InventorySlot
var curr_mouse_tile : Vector2
var isValid = false
var rotated_placement : bool = false

signal preperation_ended

func post_ready():
	inventory = get_node("Inventory")
	unit_board = battle_manager.get_node("BoardUI")
	unit_board_height = unit_board.height
	unit_board_width = unit_board.width
	
	# Initialize empty grid
	for i in unit_board_width:
		unit_board_space_map.append([])
		#vector_size_map.append([])
		for j in unit_board_height:
			unit_board_space_map[i].append(null)

	# Needed to prevent process from running too soon
	post_ready_check = true
	
	# Propagate downwards
	for i in get_children():
		if i.has_method("post_ready"):
			i.post_ready()

func _draw():
	if selector_rect_debug:
		draw_rect(selector_rect, Color.RED, false)

func _process(_delta):
	if post_ready_check:
		check_cell()
		queue_redraw()


func _input(_event: InputEvent):
	# Allow placement only if we are currently in deployment mode
	if Input.is_action_just_pressed("leftClick") and deployment_mode:
		if curr_unit and isValid:
			_place_unit()
	elif Input.is_action_just_pressed("rightClick") and deployment_mode:

		var mouse_tile_int = Vector2i(objectCells[0].board_position)
		var removed_unit_info = get_unit_at_tile(mouse_tile_int)
		if removed_unit_info:
			# Create an instance of the unit for access/use
			var item_inst = removed_unit_info[0].instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			item_inst.setup_unit()
			
			# Update other other nodes about removal
			remove_from_board(removed_unit_info[1], removed_unit_info[2])
			inventory.add_item(item_inst.item_name, 1)
			
			# Set next unit to be placed to be the removed one
			curr_unit = removed_unit_info[0]
			curr_unit_inst = item_inst
			
		_reset_highlight(objectCells)


	elif Input.is_action_just_pressed("rotatePlacement"):
		rotated_placement = !rotated_placement
		
		# Force cell check to be recomputed
		targetCell = null
		check_cell()
	

func toggle_inventory(can_use_inventory : bool):
	if can_use_inventory == true:
		inventory.can_open_inventory = true
		
	else:
		inventory.can_open_inventory = false
		inventory.toggle_window(false)

func check_cell():
	
	#var mouse_pos = get_viewport().get_mouse_position()
	var mouse_pos = Vector2(DisplayServer.mouse_get_position()) - unit_board.global_position
	curr_mouse_tile = mouse_pos / Vector2(unit_board.cellWidth, unit_board.cellHeight)
	
	var new_target = _get_target_cell()
	if new_target and new_target != targetCell:
		targetCell = new_target
		if curr_unit_inst:
			curr_unit_inst.global_position = targetCell.global_position + curr_unit_inst.texture.get_size() * curr_unit_inst.scale / 2
			if objectCells.size() > 0:
				_reset_highlight(objectCells)
			objectCells = _get_object_cells()
			isValid = _check_and_highlight_cells(objectCells)
		else:
			if objectCells.size() > 0:
				_reset_highlight(objectCells)
			objectCells = [new_target]
			new_target.change_color(Color.YELLOW)


func remove_from_board(top_corner: Vector2i, size: Vector2) -> void:

	for x in size.x:
		for y in size.y:
			unit_board_space_map[top_corner.x + x][top_corner.y + y] = null

	# Reset cells' full flag
	for cell in _get_object_cells():
		cell.full = false

	battle_manager.remove_unit_from_board(top_corner, size)

### Internode Communication Methods
func set_current_item(slot : InventorySlot):
	curr_inv_slot = slot
	
	curr_unit = slot.item
	curr_unit_inst = slot.item_inst

func start_prep_phase():
	deployment_mode = true
	toggle_inventory(true)
	end_prep.show()
	end_prep.disabled = false
	spell_bar.show()
	

func _on_end_prep_pressed() -> void:
	# Assuming we are entering the battle phase
	deployment_mode = false
	end_prep.hide()
	end_prep.disabled = true
	toggle_inventory(false)
	preperation_ended.emit()
	
	
#### Helper Methods
func _check_and_highlight_cells(cells: Array) -> bool:	
	var valid = true

	# cell count check - prevents placing units on the edges of the board
	var expected_count = int(curr_unit_inst.placement_size.x) * int(curr_unit_inst.placement_size.y)
	if expected_count != cells.size():
		valid = false

	for cell in cells:
		if cell.full:
			cell.change_color(Color.RED)
			valid = false
		else:
			cell.change_color(Color.GREEN)

	return valid

func _place_unit():
	for cell in objectCells:
		cell.full = true
	
	var grid_pos : Vector2 = objectCells[0].board_position

	if rotated_placement:
		place_on_board(grid_pos, curr_unit_inst.rotated_placement_size, curr_unit)
		battle_manager.add_unit_to_board(curr_unit_inst, objectCells[0].position, curr_unit_inst.rotated_vectors, true)
	else:
		place_on_board(grid_pos, curr_unit_inst.placement_size, curr_unit)
		battle_manager.add_unit_to_board(curr_unit_inst, objectCells[0].position, curr_unit_inst.placement_vectors, true)

	_reset_highlight(objectCells)

	# Allow the player to keep placing this unit as long as there still are cards left
	if curr_inv_slot.remove_item(1) == false:
		curr_unit = null
		curr_unit_inst = null
		if selector_rect_debug:
			selector_rect = Rect2(0,0,0,0)
		
		objectCells.clear()
	else:
		# Visually mark that you cannot keep placing here
		_check_and_highlight_cells(objectCells)
		
	isValid = false

# Placement logic using logical grid
func check_unit_space_availability(top_corner: Vector2, size: Vector2) -> bool:
	for x in size.x:
		for y in size.y:
			if unit_board_space_map[top_corner.x + x][top_corner.y + y] != null:
				return false
	return true

func place_on_board(top_corner: Vector2, size: Vector2, unit_ref: PackedScene) -> void:
	for x in size.x:
		for y in size.y:
			unit_board_space_map[top_corner.x + x][top_corner.y + y] = [unit_ref,top_corner, size]

func _get_target_cell():
	for cell: Control in unit_board.get_children():
		if cell.mouse_over == true:
			return cell
	return null

func _reset_highlight(cells : Array):
	for cell: Control in cells:
		cell.change_color(Color(0.5, 0.5, 0.5, 0.5))

func _get_object_cells() -> Array:
	var cells = []
	# Size the rectangle to be a bit smaller than 
	var unit_rect : Rect2
	if curr_unit_inst == null:
		unit_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
	else:
		if rotated_placement:
			unit_rect = Rect2(curr_unit_inst.global_position - Vector2(unit_board.cellWidth / 2, unit_board.cellHeight / 2), \
				curr_unit_inst.rotated_placement_size * Vector2(unit_board.cellWidth, unit_board.cellHeight) - Vector2(unit_board.cellWidth / 2, unit_board.cellHeight / 2))
		else:
			unit_rect = Rect2(curr_unit_inst.global_position - Vector2(unit_board.cellWidth / 2, unit_board.cellHeight / 2), \
				curr_unit_inst.placement_size * Vector2(unit_board.cellWidth, unit_board.cellHeight) - Vector2(unit_board.cellWidth / 2, unit_board.cellHeight / 2))
			
	# Store for debugging
	if selector_rect_debug:
		selector_rect = unit_rect
		
	for cell: Control in unit_board.get_children():
		if cell.get_global_rect().intersects(unit_rect):
			cells.append(cell)
	return cells


func get_unit_at_tile(tile: Vector2i): # Returns PackedScene unit ref, left corner position, and placement vector
	if tile.x >= 0 and tile.x < unit_board_width and tile.y >= 0 and tile.y < unit_board_height:
		return unit_board_space_map[tile.x][tile.y]
	return null
