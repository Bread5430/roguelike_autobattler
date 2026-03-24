extends Control
@onready var post_ready_check = false

#### DEBUG VARS
@export var selector_rect_debug : bool = true
var selector_rect : Rect2

#### NODE REFERENCES
@export var battle_manager : Control
var inventory : Inventory
var unit_board : GridContainer
@onready var spell_bar : SpellBar = $SpellBar
@onready var end_prep : Button = $End_Prep
@onready var tactical_cursor = $TacticalCursor
@onready var item_details_card: ItemDetailsCard = $ItemDetailsCard
var item_details_builder := ItemDetailsBuilder.new()

#### CASTING MODE (battle)
var casting_mode : bool = false
var casting_slot : SpellBarSlot

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

## Items committed for the current battle so we can refund them when battle ends.
## - Units are inferred from unit_board_space_map (one entry per placed unit).
## - Spells are tracked because they can be cast/removed during battle.
var _committed_spell_item_names: Array[String] = []

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

	spell_bar.battle_manager = battle_manager
	inventory.inspect_requested.connect(_on_inventory_inspect_requested)
	spell_bar.spell_slot_clicked.connect(_on_spell_slot_clicked)
	spell_bar.spell_slot_right_clicked.connect(_on_spell_slot_right_clicked)
	if battle_manager.has_signal("unit_selected"):
		battle_manager.unit_selected.connect(_on_unit_selected)
	if battle_manager.has_signal("battle_ended"):
		battle_manager.battle_ended.connect(_on_battle_ended)

	# Propagate downwards
	for i in get_children():
		if i.has_method("post_ready"):
			i.post_ready()

func _draw():
	if selector_rect_debug:
		draw_rect(selector_rect, Color.RED, false)

func _process(_delta):
	if casting_mode:
		if casting_slot and is_instance_valid(casting_slot.spell_inst):
			casting_slot.spell_inst.preview(_get_world_mouse_position())
		queue_redraw()
	elif post_ready_check:
		check_cell()
		_update_tactical_cursor()
		queue_redraw()

## Casting mode only. Runs for every input so we always can confirm/cancel cast.
func _input(event: InputEvent):
	if not casting_mode:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	if event.is_action_pressed("leftClick"):
		if not is_mouse_over_ui_element(mouse_pos) and casting_slot and is_instance_valid(casting_slot.spell_inst):
			casting_slot.spell_inst.cast(_get_world_mouse_position())
			spell_bar.remove_spell_at(casting_slot)
		_exit_casting_mode()
		return
	if event.is_action_pressed("rightClick") or event.is_action_pressed("ui_cancel"):
		_exit_casting_mode()
		return

## Only runs when no Control has accepted the event (e.g. keyboard when no button focused).
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("rotatePlacement"):
		rotated_placement = !rotated_placement
		targetCell = null
		check_cell()
		accept_event()

## Placement and removal are handled by InputCoordinator via handle_game_area_click().
## This is no longer used for game-area clicks (root Gui uses MOUSE_FILTER_IGNORE).
func _gui_input(_event: InputEvent):
	pass

## Called by InputCoordinator for game-area clicks in BATTLE_PREPARATION.
## Uses transformed (camera) coordinates so placement works with pan/zoom.
func handle_game_area_click(event: InputEvent):
	if not deployment_mode or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	var vp := get_viewport()
	var world_pos : Vector2 = vp.get_canvas_transform().affine_inverse() * event.position
	# Left click on a placed unit: show unit stats panel (no placement).
	if mb.button_index == MOUSE_BUTTON_LEFT and battle_manager and tactical_cursor:
		var unit = battle_manager.get_unit_under_cursor(world_pos)
		if unit:
			tactical_cursor.set_selected_unit(unit)
			return
	var anchor_cell := _get_cell_at_world_position(world_pos)
	if not anchor_cell:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		targetCell = anchor_cell
		# If no unit is selected (or we just ran out), don't attempt placement math.
		if curr_unit_inst == null or curr_unit == null:
			if objectCells.size() > 0:
				_reset_highlight(objectCells)
			objectCells = [anchor_cell]
			anchor_cell.change_color(Color.YELLOW)
			isValid = false
			return
		objectCells = _get_object_cells_for_anchor(anchor_cell)
		isValid = _check_and_highlight_cells(objectCells)
		if isValid:
			_place_unit()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_tile_int := Vector2i(anchor_cell.board_position)
		var removed_unit_info = get_unit_at_tile(mouse_tile_int)
		if removed_unit_info:
			var top_corner = removed_unit_info[1]
			var size = removed_unit_info[2]
			var cells_to_reset := _get_cells_in_rect(top_corner, size)
			var item_inst = removed_unit_info[0].instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			item_inst.setup_unit()
			remove_from_board(top_corner, size)
			inventory.add_item(item_inst.item_name, 1)
			curr_unit = removed_unit_info[0]
			curr_unit_inst = item_inst
			_reset_highlight(cells_to_reset)

func toggle_inventory(can_use_inventory : bool):
	if can_use_inventory == true:
		inventory.can_open_inventory = true
		
	else:
		inventory.can_open_inventory = false
		inventory.toggle_window(false)

func check_cell():
	# Use world position so hover works with camera pan/zoom.
	var world_mouse := _get_world_mouse_position()
	curr_mouse_tile = (world_mouse - unit_board.global_position) / Vector2(unit_board.cellWidth, unit_board.cellHeight)
	var new_target := _get_cell_at_world_position(world_mouse)
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
	
	if slot.item_inst is Unit_Card:
		curr_unit = slot.item
		curr_unit_inst = slot.item_inst
	elif slot.item_inst is Spell_Card:
		# In deployment mode only: add spell to spell bar and consume one from inventory
		if deployment_mode:
			var added := spell_bar.add_spell(slot.item_inst as Spell_Card, slot.item_name)
			if added:
				_committed_spell_item_names.append(slot.item_name)
				slot.remove_item(1)
		# In other modes: do nothing when clicking a spell

func start_prep_phase():
	_clear_placement_grid()
	_committed_spell_item_names.clear()
	deployment_mode = true
	toggle_inventory(true)
	end_prep.show()
	end_prep.disabled = false
	spell_bar.show()
	

func _on_end_prep_pressed() -> void:
	deployment_mode = false
	end_prep.hide()
	end_prep.disabled = true
	toggle_inventory(false)
	preperation_ended.emit()

func _on_spell_slot_clicked(slot: SpellBarSlot) -> void:
	# In battle mode: enter casting mode (only if slot has a spell)
	if not deployment_mode and not slot.is_empty() and slot.spell_inst:
		casting_mode = true
		casting_slot = slot

func _on_spell_slot_right_clicked(slot: SpellBarSlot) -> void:
	# In deployment mode: return spell to inventory
	if deployment_mode and not slot.is_empty():
		inventory.add_item(slot.item_name, 1)
		# Remove one committed instance (if present) since it was un-equipped.
		_committed_spell_item_names.erase(slot.item_name)
		spell_bar.remove_spell_at(slot)

func _on_inventory_inspect_requested(item_inst: Item, item_name: String, source_global_pos: Vector2) -> void:
	if item_inst == null:
		return
	if item_details_card.visible:
		item_details_card.hide_details()
		return
	var payload := item_details_builder.build_payload(item_inst, item_name)
	item_details_card.show_details(payload, source_global_pos)

func _exit_casting_mode() -> void:
	if casting_slot and is_instance_valid(casting_slot.spell_inst):
		casting_slot.spell_inst.clear_preview()
	casting_mode = false
	casting_slot = null

## Convert viewport/screen mouse position to world position (accounts for camera pan and zoom).
func _get_world_mouse_position() -> Vector2:
	var vp := get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()

## Clear the placement grid and BoardSlot state so the next deployment starts fresh.
func _clear_placement_grid() -> void:
	for i in unit_board_width:
		for j in unit_board_height:
			unit_board_space_map[i][j] = null
	var default_slot_color := Color(0.5, 0.5, 0.5, 0.5)
	for cell in unit_board.get_children():
		if cell is BoardSlot:
			cell.full = false
			cell.change_color(default_slot_color)
	
#### Helper Methods
func _check_and_highlight_cells(cells: Array) -> bool:	
	if curr_unit_inst == null:
		# No selected unit (or ran out). Nothing to validate/place.
		return false
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

## Returns the BoardSlot at the given world position (transformed coords; works with pan/zoom).
func _get_cell_at_world_position(world_pos: Vector2) -> BoardSlot:
	var local := world_pos - unit_board.global_position
	var tile_x := int(local.x / unit_board.cellWidth)
	var tile_y := int(local.y / unit_board.cellHeight)
	if tile_x < 0 or tile_x >= unit_board_width or tile_y < 0 or tile_y >= unit_board_height:
		return null
	var idx := tile_x + tile_y * unit_board_width
	var children := unit_board.get_children()
	if idx >= children.size():
		return null
	var cell = children[idx]
	return cell as BoardSlot if cell is BoardSlot else null

func _reset_highlight(cells : Array):
	for cell: Control in cells:
		cell.change_color(Color(0.5, 0.5, 0.5, 0.5))

func _get_object_cells() -> Array:
	if targetCell:
		return _get_object_cells_for_anchor(targetCell)
	return []

## Returns cells that would be covered by placing current unit with top-left at anchor_cell.
## Uses world-space rect so it works with camera pan/zoom.
func _get_object_cells_for_anchor(anchor_cell: BoardSlot) -> Array:
	var cells: Array = []
	var unit_rect: Rect2
	if curr_unit_inst == null:
		unit_rect = Rect2(Vector2.ZERO, Vector2.ZERO)
	else:
		var origin := anchor_cell.global_position
		var cell_size := Vector2(unit_board.cellWidth, unit_board.cellHeight)
		if rotated_placement:
			unit_rect = Rect2(origin, curr_unit_inst.rotated_placement_size * cell_size)
		else:
			unit_rect = Rect2(origin, curr_unit_inst.placement_size * cell_size)
	if selector_rect_debug:
		selector_rect = unit_rect
	for cell in unit_board.get_children():
		if cell is Control and cell.get_global_rect().intersects(unit_rect):
			cells.append(cell)
	# Top-left first (for _place_unit which uses objectCells[0] as origin).
	cells.sort_custom(func(a, b): return _cell_order(a, b) < 0)
	return cells


func _cell_order(a: Control, b: Control) -> int:
	var pa := (a as BoardSlot).board_position
	var pb := (b as BoardSlot).board_position
	if pa.y != pb.y:
		return int(pa.y - pb.y)
	return int(pa.x - pb.x)

## Returns BoardSlots in the grid rect [top_corner, top_corner+size) (for reset after removal).
func _get_cells_in_rect(top_corner: Vector2i, size: Vector2) -> Array:
	var cells: Array = []
	for dx in int(size.x):
		for dy in int(size.y):
			var tx := top_corner.x + dx
			var ty := top_corner.y + dy
			if tx >= 0 and tx < unit_board_width and ty >= 0 and ty < unit_board_height:
				var idx := tx + ty * unit_board_width
				var children := unit_board.get_children()
				if idx < children.size():
					var c = children[idx]
					if c is BoardSlot:
						cells.append(c)
	return cells


func get_unit_at_tile(tile: Vector2i): # Returns PackedScene unit ref, left corner position, and placement vector
	if tile.x >= 0 and tile.x < unit_board_width and tile.y >= 0 and tile.y < unit_board_height:
		return unit_board_space_map[tile.x][tile.y]
	return null

func _update_tactical_cursor() -> void:
	if not battle_manager or not tactical_cursor:
		return
	# Selected unit panel only visible during battle; clear when on map.
	if not battle_manager.visible:
		tactical_cursor.set_selected_unit(null)


func _on_unit_selected(unit: Base_Unit) -> void:
	if tactical_cursor:
		tactical_cursor.set_selected_unit(unit)


func _on_battle_ended_clear_selection(_victory: bool) -> void:
	if tactical_cursor:
		tactical_cursor.set_selected_unit(null)

func _on_battle_ended(victory: bool) -> void:
	_refund_items_after_battle()
	_on_battle_ended_clear_selection(victory)

func _refund_items_after_battle() -> void:
	# Refund spells that were equipped for this battle (even if they were cast/removed during battle).
	if inventory and spell_bar:
		for item_name in _committed_spell_item_names:
			inventory.add_item(item_name, 1)
		_committed_spell_item_names.clear()
		for slot in spell_bar.slots:
			if slot and not slot.is_empty():
				spell_bar.remove_spell_at(slot)

	# Refund deployed units back to inventory and reset the placement grid.
	if inventory:
		var counts_by_scene: Dictionary = {} # PackedScene -> int
		for x in unit_board_width:
			for y in unit_board_height:
				var entry = unit_board_space_map[x][y]
				if entry == null:
					continue
				# entry = [unit_ref, top_corner, size]
				var unit_ref: PackedScene = entry[0]
				var top_corner: Vector2i = entry[1]
				if top_corner.x != x or top_corner.y != y:
					continue # only count once per placed unit
				counts_by_scene[unit_ref] = int(counts_by_scene.get(unit_ref, 0)) + 1

		for unit_ref in counts_by_scene.keys():
			var count := int(counts_by_scene[unit_ref])
			if count <= 0:
				continue
			var item_inst = (unit_ref as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			if item_inst and item_inst.has_method("setup_unit"):
				item_inst.setup_unit()
			if item_inst and "item_name" in item_inst:
				inventory.add_item(item_inst.item_name, count)
			if item_inst:
				item_inst.queue_free()

	_clear_placement_grid()
	deployment_mode = false
	_exit_casting_mode()

func is_mouse_over_ui_element(mouse_pos: Vector2) -> bool:
	"""
	This is needed because input will trigger before the "pressed" signal is preocessed
	Check if mouse is over interactive UI elements (not the board).
	Returns true if over UI, false if over board/game area.
	"""
	# Check inventory window
	if inventory and inventory.visible:
		var inv_rect = inventory.get_global_rect()
		if inv_rect.has_point(mouse_pos):
			return true
	
	# Check spell bar
	if spell_bar and spell_bar.visible:
		var spell_rect = spell_bar.get_global_rect()
		if spell_rect.has_point(mouse_pos):
			return true
	
	# Check end prep button
	if end_prep and end_prep.visible:
		var button_rect = end_prep.get_global_rect()
		if button_rect.has_point(mouse_pos):
			return true
	
	# Add other UI elements here as needed
	
	return false
