extends Node
class_name UnitPlacement

## Owns the deployment board grid, unit placement/removal, static routers, scrap
## spend/refund on placement, and formation-editor board operations.
## The GUI keeps ownership of phase state (deployment_mode), spells, and UI routing,
## and delegates board interactions here.

## Item id (Data/items.csv) for the unremovable static routers spawned on the player board at battle start.
const STATIC_ROUTER_CARD_ID := "static_router_card"
const SIDE_ROWS : int = 3

# References resolved by the GUI in setup().
var gui  # GUI root (Control with the GUI.gd script); untyped for dynamic property access.
var battle_manager: Control
var unit_board: GridContainer
var side_strip_top_board: GridContainer
var side_strip_bottom_board: GridContainer
var inventory: Inventory
var gsm
var enemy_spawner: Node

# Board grid state.
var unit_board_width : int
var unit_board_height : int
var unit_board_space_map : Array[Array] = [] # Stores references to units on the board for removal

## Deployment-only: world-space centers and radii for placed router cards (logical exclusion, not grid-derived).
var _placed_router_exclusions: Array[Dictionary] = []
## Board tiles occupied by unremovable static routers (Vector2i -> true); kept out of the space map so they can't be removed/refunded.
var _static_router_tiles: Dictionary = {}
## Formation-editor save support: each static router anchor { "top_left": Vector2i, "size": Vector2, "scene": PackedScene }.
var _static_router_placements: Array = []

# Current placement selection / preview state.
var targetCell
var objectCells = []
var curr_unit : PackedScene
var curr_unit_inst : Item
var curr_inv_slot : InventorySlot
var curr_mouse_tile : Vector2
var isValid = false
var rotated_placement : bool = false

## Cached attack preview stats for the currently selected unit card.
var _cached_stats_card_id: String = ""
var _cached_is_melee: bool = true
var _cached_attack_range: float = 0.0


func setup(p_gui, p_battle_manager: Control, p_unit_board: GridContainer, p_inventory: Inventory, p_gsm, p_enemy_spawner: Node) -> void:
	gui = p_gui
	battle_manager = p_battle_manager
	unit_board = p_unit_board
	side_strip_top_board = battle_manager.get_node_or_null("SideStripTop") as GridContainer
	side_strip_bottom_board = battle_manager.get_node_or_null("SideStripBottom") as GridContainer
	inventory = p_inventory
	gsm = p_gsm
	enemy_spawner = p_enemy_spawner


func init_grid() -> void:
	unit_board_height = unit_board.height
	unit_board_width = unit_board.width
	unit_board_space_map.clear()
	# Space map covers main board y 0..height-1 plus side strips at
	# y -SIDE_ROWS..-1 (top) and y height..height+SIDE_ROWS-1 (bottom).
	# Index with _space_map_y(logical_y).
	var map_height = unit_board_height + 2 * SIDE_ROWS
	for i in unit_board_width:
		unit_board_space_map.append([])
		for j in map_height:
			unit_board_space_map[i].append(null)


## Convert logical board y (may be negative for the top strip) to space-map index.
func _space_map_y(logical_y: int) -> int:
	return logical_y + SIDE_ROWS


func _is_valid_logical_tile(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= unit_board_width:
		return false
	if tile.y < -SIDE_ROWS or tile.y >= unit_board_height + SIDE_ROWS:
		return false
	return true


# =============================================================================
# DEPLOYMENT LIFECYCLE
# =============================================================================

func begin_deployment() -> void:
	clear_placement_grid()
	_spawn_static_routers()
	_clear_placement_indicators_preview()


## Re-run normal static router spawn (after clearing the board in formation editor).
func respawn_static_routers() -> void:
	_spawn_static_routers()


func reset_current_selection() -> void:
	curr_unit = null
	curr_unit_inst = null
	objectCells.clear()
	_clear_placement_stat_cache()
	_clear_placement_indicators_preview()


func set_current_unit(slot: InventorySlot) -> void:
	curr_inv_slot = slot
	curr_unit = slot.item
	curr_unit_inst = slot.item_inst
	_refresh_placement_stat_cache()
	# Force hover recompute so indicators appear immediately on card select.
	targetCell = null
	process_hover()


func handle_rotate() -> void:
	rotated_placement = !rotated_placement
	targetCell = null
	process_hover()


# =============================================================================
# HOVER PREVIEW
# =============================================================================

func process_hover() -> void:
	# Use world position so hover works with camera pan/zoom.
	var world_mouse = _get_world_mouse_position()
	curr_mouse_tile = (world_mouse - unit_board.global_position) / Vector2(unit_board.cellWidth, unit_board.cellHeight)
	var new_target = _get_cell_at_world_position(world_mouse)
	if new_target == null:
		targetCell = null
		_clear_preview_highlight()
		return
	if new_target and new_target != targetCell:
		targetCell = new_target
		if objectCells.size() > 0:
			_reset_highlight(objectCells)
		if curr_unit_inst:
			curr_unit_inst.global_position = targetCell.global_position + curr_unit_inst.texture.get_size() * curr_unit_inst.scale / 2
			objectCells = _get_object_cells()
			isValid = _check_and_highlight_cells(objectCells)
			_update_placement_indicators_preview()
		else:
			objectCells = [new_target]
			new_target.change_color(Color.YELLOW)
			_clear_placement_indicators_preview()


func _clear_preview_highlight() -> void:
	if objectCells.size() > 0:
		_reset_highlight(objectCells)
	objectCells.clear()
	isValid = false
	_clear_placement_indicators_preview()


# =============================================================================
# BOARD CLICK (placement / removal)
# =============================================================================

## Called by the GUI for game-area clicks in deployment (after it handles unit selection).
## world_pos is in transformed (camera) coordinates so placement works with pan/zoom.
func handle_board_click(mb: InputEventMouseButton, world_pos: Vector2) -> void:
	var anchor_cell = _get_cell_at_world_position(world_pos)
	if not anchor_cell:
		_clear_preview_highlight()
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		# Fast cursor movement + click can bypass the hover-frame update, leaving
		# previous preview colors behind. Clear old preview before recomputing.
		if objectCells.size() > 0:
			_reset_highlight(objectCells)
		targetCell = anchor_cell
		# If no unit is selected (or we just ran out), don't attempt placement math.
		if curr_unit_inst == null or curr_unit == null:
			objectCells = [anchor_cell]
			anchor_cell.change_color(Color.YELLOW)
			isValid = false
			_clear_placement_indicators_preview()
			return
		objectCells = _get_object_cells_for_anchor(anchor_cell)
		isValid = _check_and_highlight_cells(objectCells)
		if isValid:
			_place_unit()
		else:
			_update_placement_indicators_preview()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_tile_int = Vector2i(anchor_cell.board_position)
		# Static routers are permanent fixtures and cannot be removed.
		if _static_router_tiles.has(mouse_tile_int):
			return
		var removed_unit_info = get_unit_at_tile(mouse_tile_int)
		if removed_unit_info:
			var top_corner = removed_unit_info[1]
			var size = removed_unit_info[2]
			var top_i = Vector2i(int(top_corner.x), int(top_corner.y))
			var cells_to_reset = _get_cells_in_rect(top_i, size)
			var item_inst = removed_unit_info[0].instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			item_inst.setup_unit()
			remove_from_board(top_i, size)
			if item_inst is Unit_Card:
				_refund_scrap_for_card(item_inst as Unit_Card)
			inventory.add_item(item_inst.item_name, 1)
			curr_unit = removed_unit_info[0]
			curr_unit_inst = item_inst

			# Force a placement validity recalculation with this new unit
			_reset_highlight(cells_to_reset)
			isValid = _check_and_highlight_cells(objectCells)


func remove_from_board(top_corner: Vector2i, size: Vector2) -> void:
	_remove_placed_router_exclusion_if_matches(top_corner, size)
	for x in size.x:
		for y in size.y:
			var lx = top_corner.x + int(x)
			var ly = top_corner.y + int(y)
			if _is_valid_logical_tile(Vector2i(lx, ly)):
				unit_board_space_map[lx][_space_map_y(ly)] = null

	var reset_cells = _get_cells_in_rect(top_corner, size)
	for cell in reset_cells:
		cell.full = false

	battle_manager.remove_unit_from_board(top_corner, size)


func _remove_placed_router_exclusion_if_matches(top_corner: Vector2i, size: Vector2) -> void:
	var i = _placed_router_exclusions.size() - 1
	while i >= 0:
		var z: Dictionary = _placed_router_exclusions[i]
		if z["top_corner"] == top_corner and z["size"] == size:
			_placed_router_exclusions.remove_at(i)
			return
		i -= 1


# =============================================================================
# STATIC ROUTERS
# =============================================================================

## Spawn the two unremovable static routers on the player's board at battle start.
## Centered horizontally; first ~1/4 down and second ~3/4 down the vertical.
func _spawn_static_routers() -> void:
	_static_router_tiles.clear()
	_static_router_placements.clear()
	var scene: PackedScene = ITEM_NAME.item_lookup(STATIC_ROUTER_CARD_ID)
	if scene == null:
		push_warning("Static router card not found: %s" % STATIC_ROUTER_CARD_ID)
		return
	var probe = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not probe is Unit_Card:
		if probe:
			probe.queue_free()
		return
	var size : Vector2 = (probe as Unit_Card).placement_size
	probe.queue_free()
	var w = int(size.x)
	var h = int(size.y)
	# Horizontal: center the footprint on the board's vertical center line.
	var top_x = int((unit_board_width - w) / 2.0)
	# Vertical: footprint centers land at 1/4 and 3/4 of the board height.
	var top_y_first = int(round(unit_board_height * 0.25 - h / 2.0))
	var top_y_second = int(round(unit_board_height * 0.75 - h / 2.0))
	_spawn_one_static_router(scene, Vector2i(top_x, top_y_first), size)
	_spawn_one_static_router(scene, Vector2i(top_x, top_y_second), size)


func _spawn_one_static_router(scene: PackedScene, top_left: Vector2i, size: Vector2) -> void:
	var cells = _get_cells_in_rect(top_left, size)
	if cells.size() != int(size.x) * int(size.y):
		return # Footprint doesn't fully fit on the board.
	var item_inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not item_inst is Unit_Card:
		if item_inst:
			item_inst.queue_free()
		return
	item_inst.setup_unit()
	# Occupy the grid so players can't place on top. Intentionally NOT added to
	# unit_board_space_map during normal battles, so right-click removal and
	# end-of-battle refund skip it. Formation editor save reads placements via
	# get_static_router_placements().
	for cell in cells:
		cell.full = true
		var bp : Vector2 = (cell as BoardSlot).board_position
		_static_router_tiles[Vector2i(int(bp.x), int(bp.y))] = true
	_static_router_placements.append({
		"top_left": top_left,
		"size": size,
		"scene": scene,
	})
	# Derive the anchor from grid coords + cell size directly. BoardUI is a
	# GridContainer that may not have laid out its cells yet when prep begins,
	# so BoardSlot.position can still read (0,0) here. unit_board's own
	# global_position (including its start_offset) is set explicitly though,
	# so it's safe to read immediately.
	var start_position = unit_board.global_position + Vector2(top_left.x * unit_board.cellWidth, top_left.y * unit_board.cellHeight)
	battle_manager.add_unit_to_board(item_inst, start_position, item_inst.placement_vectors, true)
	item_inst.queue_free()


## Static router anchors for formation CSV export (not stored in the space map).
func get_static_router_placements() -> Array:
	return _static_router_placements


## Clear static router tile locks without respawning (used when loading a formation that includes routers).
func clear_static_router_state() -> void:
	_static_router_tiles.clear()
	_static_router_placements.clear()


# =============================================================================
# SCRAP (spent/refunded on placement/removal)
# =============================================================================

func _spend_scrap_for_card(card: Unit_Card) -> void:
	if gsm == null or not gsm.has_node("ScrapBufferManager") or card == null:
		return
	var scrap_buffer := gsm.get_node("ScrapBufferManager") as ScrapBufferManager
	scrap_buffer.spend_scrap(card.get_total_scrap_cost())


func _refund_scrap_for_card(card: Unit_Card) -> void:
	if gsm == null or not gsm.has_node("ScrapBufferManager") or card == null:
		return
	var scrap_buffer := gsm.get_node("ScrapBufferManager") as ScrapBufferManager
	scrap_buffer.refund_scrap(card.get_total_scrap_cost())


# =============================================================================
# END-OF-BATTLE REFUND
# =============================================================================

func refund_units_after_battle() -> void:
	# Refund deployed units back to inventory and reset the placement grid.
	if inventory:
		var counts_by_scene: Dictionary = {} # PackedScene -> int
		var map_height = unit_board_height + 2 * SIDE_ROWS
		for x in unit_board_width:
			for map_y in map_height:
				var entry = unit_board_space_map[x][map_y]
				if entry == null:
					continue
				# entry = [unit_ref, top_corner, size]
				var unit_ref: PackedScene = entry[0]
				var top_corner: Vector2i = entry[1]
				var logical_y = map_y - SIDE_ROWS
				if top_corner.x != x or top_corner.y != logical_y:
					continue # only count once per placed unit
				counts_by_scene[unit_ref] = int(counts_by_scene.get(unit_ref, 0)) + 1

		for unit_ref in counts_by_scene.keys():
			var count = int(counts_by_scene[unit_ref])
			if count <= 0:
				continue
			var item_inst = (unit_ref as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
			if item_inst and item_inst.has_method("setup_unit"):
				item_inst.setup_unit()
			if item_inst and "item_name" in item_inst:
				inventory.add_item(item_inst.item_name, count)
			if item_inst:
				item_inst.queue_free()

	clear_placement_grid()


## During deployment: remove all player-placed units (not static routers), refund scrap, return cards to inventory.
func return_placed_units_to_inventory() -> void:
	var placements: Array = []
	var map_height = unit_board_height + 2 * SIDE_ROWS
	for x in unit_board_width:
		for map_y in map_height:
			var entry = unit_board_space_map[x][map_y]
			if entry == null:
				continue
			var top_corner: Vector2i = entry[1]
			var logical_y = map_y - SIDE_ROWS
			if top_corner.x != x or top_corner.y != logical_y:
				continue
			placements.append(entry)

	for entry in placements:
		var unit_ref: PackedScene = entry[0]
		var top_corner = entry[1]
		var size: Vector2 = entry[2]
		var top_i = Vector2i(int(top_corner.x), int(top_corner.y))
		var item_inst = unit_ref.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		if item_inst and item_inst.has_method("setup_unit"):
			item_inst.setup_unit()
		if item_inst is Unit_Card:
			_refund_scrap_for_card(item_inst as Unit_Card)
		if inventory and item_inst and "item_name" in item_inst:
			inventory.add_item(item_inst.item_name, 1)
		remove_from_board(top_i, size)
		if item_inst:
			item_inst.queue_free()

	reset_current_selection()


# =============================================================================
# FORMATION EDITOR BOARD OPERATIONS
# =============================================================================

func clear_board_allied_units() -> void:
	if battle_manager == null:
		return
	var up = battle_manager.get_node_or_null("Unit_Parent")
	if up == null:
		return
	for child in up.get_children():
		if child is Base_Unit and (child as Base_Unit).faction:
			child.queue_free()


func clear_board_enemy_units() -> void:
	var up = battle_manager.get_node_or_null("Unit_Parent")
	for child in up.get_children():
		if child is Base_Unit and not (child as Base_Unit).faction:
			child.queue_free()
	var indicators = _get_placement_indicators()
	if indicators:
		indicators.clear_enemy_packs()


func load_formation_rows_on_player_board(rows: Array) -> int:
	if enemy_spawner == null:
		return 0
	var seen_groups = {}
	var placed = 0
	for parsed in rows:
		if parsed.is_empty():
			continue
		var scene: PackedScene = enemy_spawner.pick_unit_scene_for_entry(parsed, seen_groups)
		if scene == null:
			continue
		var top = Vector2i(int(parsed["x"]), int(parsed["y"]))
		if place_unit_card_programmatic(scene, top, false):
			placed += 1
	return placed


func place_unit_card_programmatic(p_scene: PackedScene, top_left: Vector2i, rotated: bool) -> bool:
	var item_inst = p_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not item_inst is Unit_Card:
		item_inst.queue_free()
		return false
	item_inst.setup_unit()
	curr_unit_inst = item_inst
	curr_unit = p_scene
	rotated_placement = rotated
	var anchor = _get_board_slot_at_grid(top_left)
	if anchor == null:
		item_inst.queue_free()
		curr_unit_inst = null
		curr_unit = null
		return false
	targetCell = anchor
	objectCells = _get_object_cells_for_anchor(anchor)
	if not _check_and_highlight_cells(objectCells):
		_reset_highlight(objectCells)
		item_inst.queue_free()
		curr_unit_inst = null
		curr_unit = null
		return false

	for cell in objectCells:
		cell.full = true

	var grid_pos: Vector2 = objectCells[0].board_position
	var unit_size = item_inst.rotated_placement_size if rotated else item_inst.placement_size
	var unit_vec = item_inst.rotated_vectors if rotated else item_inst.placement_vectors

	var is_static_router = item_inst is Unit_Card and str((item_inst as Unit_Card).item_name) == STATIC_ROUTER_CARD_ID
	if is_static_router:
		# Keep static routers out of the space map (same as auto-spawn) so save
		# exports them once via get_static_router_placements().
		var top_i = Vector2i(int(grid_pos.x), int(grid_pos.y))
		for cell in objectCells:
			if cell is BoardSlot:
				var bp : Vector2 = (cell as BoardSlot).board_position
				_static_router_tiles[Vector2i(int(bp.x), int(bp.y))] = true
		_static_router_placements.append({
			"top_left": top_i,
			"size": unit_size,
			"scene": p_scene,
		})
	else:
		place_on_board(grid_pos, unit_size, p_scene)

	var router_excl = _router_exclusion_radius_from_card_inst(item_inst)
	if router_excl > 0.0:
		var center = _placement_center_global_from_cells(objectCells, unit_size)
		var top_i2 = Vector2i(int(grid_pos.x), int(grid_pos.y))
		_placed_router_exclusions.append({
			"center": center,
			"radius": router_excl,
			"top_corner": top_i2,
			"size": unit_size,
		})

	battle_manager.add_unit_to_board(item_inst, objectCells[0].global_position, unit_vec, true)
	if item_inst is Unit_Card and not is_static_router:
		_spend_scrap_for_card(item_inst as Unit_Card)
	_reset_highlight(objectCells)
	item_inst.queue_free()
	curr_unit_inst = null
	curr_unit = null
	isValid = false
	return true


# =============================================================================
# PLACEMENT + GRID HELPERS
# =============================================================================

func clear_placement_grid() -> void:
	_placed_router_exclusions.clear()
	var map_height = unit_board_height + 2 * SIDE_ROWS
	for i in unit_board_width:
		for j in map_height:
			unit_board_space_map[i][j] = null
	var boards = []
	boards.append(unit_board)
	if side_strip_top_board:
		boards.append(side_strip_top_board)
	if side_strip_bottom_board:
		boards.append(side_strip_bottom_board)
	for b in boards:
		for cell in b.get_children():
			if cell is BoardSlot:
				cell.full = false
				cell.change_color(Color(0.5, 0.5, 0.5, 0.5))


func _check_and_highlight_cells(cells: Array) -> bool:
	if curr_unit_inst == null:
		# No selected unit (or ran out). Nothing to validate/place.
		return false
	var valid = true

	# cell count check - prevents placing units on the edges of the board
	var active_size: Vector2 = curr_unit_inst.rotated_placement_size if rotated_placement else curr_unit_inst.placement_size
	var expected_count = int(active_size.x) * int(active_size.y)
	if expected_count != cells.size():
		valid = false

	for cell in cells:
		if cell.full:
			cell.change_color(Color.RED)
			valid = false
		else:
			cell.change_color(Color.GREEN)
	if valid and _router_placement_overlaps_exclusion(cells, active_size):
		valid = false
		for cell in cells:
			cell.change_color(Color.RED)
	return valid


func _place_unit():
	for cell in objectCells:
		cell.full = true

	var grid_pos : Vector2 = objectCells[0].board_position
	var unit_size = curr_unit_inst.rotated_placement_size if rotated_placement else curr_unit_inst.placement_size
	var unit_vec = curr_unit_inst.rotated_vectors if rotated_placement else curr_unit_inst.placement_vectors

	place_on_board(grid_pos, unit_size, curr_unit)
	var router_excl = _router_exclusion_radius_for_current_unit()
	if router_excl > 0.0:
		var center = _placement_center_global_from_cells(objectCells, unit_size)
		var top_i = Vector2i(int(grid_pos.x), int(grid_pos.y))
		_placed_router_exclusions.append({
			"center": center,
			"radius": router_excl,
			"top_corner": top_i,
			"size": unit_size,
		})
	battle_manager.add_unit_to_board(curr_unit_inst, objectCells[0].global_position, unit_vec, true)
	if curr_unit_inst is Unit_Card:
		_spend_scrap_for_card(curr_unit_inst as Unit_Card)
	_reset_highlight(objectCells)
	_clear_placement_indicators_preview()

	# Allow the player to keep placing this unit as long as there still are cards left
	if curr_inv_slot.remove_item(1) == false:
		curr_unit = null
		curr_unit_inst = null
		_clear_placement_stat_cache()
		if gui.selector_rect_debug:
			gui.selector_rect = Rect2(0,0,0,0)

		objectCells.clear()
	else:
		# Visually mark that you cannot keep placing here
		_check_and_highlight_cells(objectCells)
		_update_placement_indicators_preview()

	isValid = false


# Placement logic using logical grid
func check_unit_space_availability(top_corner: Vector2, size: Vector2) -> bool:
	for x in size.x:
		for y in size.y:
			var lx = int(top_corner.x) + int(x)
			var ly = int(top_corner.y) + int(y)
			if not _is_valid_logical_tile(Vector2i(lx, ly)):
				return false
			if unit_board_space_map[lx][_space_map_y(ly)] != null:
				return false
	return true


func place_on_board(top_corner: Vector2, size: Vector2, unit_ref: PackedScene) -> void:
	for x in size.x:
		for y in size.y:
			var lx = int(top_corner.x) + int(x)
			var ly = int(top_corner.y) + int(y)
			if _is_valid_logical_tile(Vector2i(lx, ly)):
				unit_board_space_map[lx][_space_map_y(ly)] = [unit_ref, top_corner, size]


func _router_exclusion_radius_for_current_unit() -> float:
	if curr_unit_inst is Unit_Card:
		var uc = curr_unit_inst as Unit_Card
		if uc.is_router_card:
			return uc.router_exclusion_radius
	return 0.0


func _router_exclusion_radius_from_card_inst(inst: Item) -> float:
	if inst is Unit_Card:
		var uc = inst as Unit_Card
		if uc.is_router_card:
			return uc.router_exclusion_radius
	return 0.0


func _placement_center_global_from_cells(cells: Array, size: Vector2) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var sorted: Array = cells.duplicate()
	sorted.sort_custom(func(a, b): return _cell_order(a, b) < 0)
	var tl = (sorted[0] as BoardSlot).global_position
	var cw = float(unit_board.cellWidth)
	var ch = float(unit_board.cellHeight)
	return tl + Vector2(size.x * cw, size.y * ch) * 0.5


func _router_placement_overlaps_exclusion(cells: Array, size: Vector2) -> bool:
	if curr_unit_inst == null or not curr_unit_inst is Unit_Card:
		return false
	var uc = curr_unit_inst as Unit_Card
	if not uc.is_router_card:
		return false
	var center = _placement_center_global_from_cells(cells, size)
	for z in _placed_router_exclusions:
		if center.distance_to(z["center"]) < float(z["radius"]):
			return true
	return false


func _get_board_slot_at_grid(grid_xy: Vector2i) -> BoardSlot:
	if not _is_valid_logical_tile(grid_xy):
		return null
	var board: GridContainer
	var local_y: int
	if grid_xy.y < 0:
		# Top strip: logical y -SIDE_ROWS .. -1
		board = side_strip_top_board
		local_y = grid_xy.y + SIDE_ROWS
	elif grid_xy.y >= unit_board_height:
		# Bottom strip: logical y height .. height+SIDE_ROWS-1
		board = side_strip_bottom_board
		local_y = grid_xy.y - unit_board_height
	else:
		board = unit_board
		local_y = grid_xy.y

	if board == null:
		return null
	var idx = grid_xy.x + local_y * board.width
	var children = board.get_children()
	if idx >= children.size():
		return null
	var cell = children[idx]
	return cell as BoardSlot if cell is BoardSlot else null


## Returns the BoardSlot at the given world position (transformed coords; works with pan/zoom).
func _get_cell_at_world_position(world_pos: Vector2) -> BoardSlot:
	# Main board first.
	var local = world_pos - unit_board.global_position
	var tile_x = int(local.x / unit_board.cellWidth)
	var tile_y = int(local.y / unit_board.cellHeight)
	if tile_x >= 0 and tile_x < unit_board_width and tile_y >= 0 and tile_y < unit_board_height:
		var idx = tile_x + tile_y * unit_board_width
		var children = unit_board.get_children()
		if idx < children.size():
			var cell = children[idx]
			return cell as BoardSlot if cell is BoardSlot else null

	# Side strips sit above/below the player board and start at its right edge.
	var cell_w = unit_board.cellWidth
	var cell_h = unit_board.cellHeight

	if side_strip_top_board:
		var top_local = world_pos - side_strip_top_board.global_position
		var top_x = int(top_local.x / cell_w)
		var top_y = int(top_local.y / cell_h)
		if top_x >= 0 and top_x < unit_board_width and top_y >= 0 and top_y < SIDE_ROWS:
			var idx2 = top_x + top_y * side_strip_top_board.width
			var children2 = side_strip_top_board.get_children()
			if idx2 < children2.size():
				var cell2 = children2[idx2]
				return cell2 as BoardSlot if cell2 is BoardSlot else null

	if side_strip_bottom_board:
		var bot_local = world_pos - side_strip_bottom_board.global_position
		var bot_x = int(bot_local.x / cell_w)
		var bot_y = int(bot_local.y / cell_h)
		if bot_x >= 0 and bot_x < unit_board_width and bot_y >= 0 and bot_y < SIDE_ROWS:
			var idx3 = bot_x + bot_y * side_strip_bottom_board.width
			var children3 = side_strip_bottom_board.get_children()
			if idx3 < children3.size():
				var cell3 = children3[idx3]
				return cell3 as BoardSlot if cell3 is BoardSlot else null

	return null


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
		var origin = anchor_cell.global_position
		var cell_size = Vector2(unit_board.cellWidth, unit_board.cellHeight)
		if rotated_placement:
			unit_rect = Rect2(origin, curr_unit_inst.rotated_placement_size * cell_size)
		else:
			unit_rect = Rect2(origin, curr_unit_inst.placement_size * cell_size)
	if gui.selector_rect_debug:
		gui.selector_rect = unit_rect
	var boards = [unit_board]
	if side_strip_top_board:
		boards.append(side_strip_top_board)
	if side_strip_bottom_board:
		boards.append(side_strip_bottom_board)
	for b in boards:
		for cell in b.get_children():
			if cell is Control and cell.get_global_rect().intersects(unit_rect):
				cells.append(cell)
	# Top-left first (for _place_unit which uses objectCells[0] as origin).
	cells.sort_custom(func(a, b): return _cell_order(a, b) < 0)
	return cells


func _cell_order(a: Control, b: Control) -> int:
	var pa = (a as BoardSlot).board_position
	var pb = (b as BoardSlot).board_position
	if pa.y != pb.y:
		return int(pa.y - pb.y)
	return int(pa.x - pb.x)


## Returns BoardSlots in the grid rect [top_corner, top_corner+size) (for reset after removal).
func _get_cells_in_rect(top_corner: Vector2i, size: Vector2) -> Array:
	var cells: Array = []
	for dx in int(size.x):
		for dy in int(size.y):
			var tx = top_corner.x + dx
			var ty = top_corner.y + dy
			if _is_valid_logical_tile(Vector2i(tx, ty)):
				var c = _get_board_slot_at_grid(Vector2i(tx, ty))
				if c != null:
					cells.append(c)
	return cells


func get_unit_at_tile(tile: Vector2i): # Returns PackedScene unit ref, left corner position, and placement vector
	if _is_valid_logical_tile(tile):
		return unit_board_space_map[tile.x][_space_map_y(tile.y)]
	return null


## Convert viewport/screen mouse position to world position (accounts for camera pan and zoom).
func _get_world_mouse_position() -> Vector2:
	var vp = get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


# =============================================================================
# PLACEMENT INDICATORS (range + targeting lines)
# =============================================================================

func _get_placement_indicators() -> PlacementIndicators:
	if battle_manager == null:
		return null
	return battle_manager.get_node_or_null("PlacementIndicators") as PlacementIndicators


func _board_cell_size() -> Vector2:
	return Vector2(unit_board.cellWidth, unit_board.cellHeight)


func _clear_placement_indicators_preview() -> void:
	var indicators = _get_placement_indicators()
	if indicators:
		indicators.clear_preview()


func _clear_placement_stat_cache() -> void:
	_cached_stats_card_id = ""
	_cached_is_melee = true
	_cached_attack_range = 0.0


func _refresh_placement_stat_cache() -> void:
	_clear_placement_stat_cache()
	if curr_unit_inst == null or not curr_unit_inst is Unit_Card:
		return
	var card: Unit_Card = curr_unit_inst as Unit_Card
	if card.related_unit == null:
		return
	var probe = card.related_unit.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if not probe is Base_Unit:
		probe.queue_free()
		return
	var unit: Base_Unit = probe as Base_Unit
	var card_id: String = card.item_name
	if not card_id.is_empty():
		unit.apply_upgrade_from_card(card_id)
		unit.apply_upgrade_abilities_after_ready()
	_cached_is_melee = unit.is_melee
	var coll_radius: float = 0.0
	var coll_shape_node = unit.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if coll_shape_node != null and coll_shape_node.shape is CircleShape2D:
		coll_radius = (coll_shape_node.shape as CircleShape2D).radius
	for c in unit.get_children():
		if c is Attack_Base:
			# Preview radius from unit center matches Attack_Base.in_range edge-to-edge
			# reach against a point target: attack_range + own collision radius.
			_cached_attack_range = float((c as Attack_Base).attack_range) + coll_radius
			break
	_cached_stats_card_id = card_id
	probe.queue_free()


func _update_placement_indicators_preview() -> void:
	if gui == null or not gui.deployment_mode:
		_clear_placement_indicators_preview()
		return
	if curr_unit_inst == null or not curr_unit_inst is Unit_Card or objectCells.is_empty():
		_clear_placement_indicators_preview()
		return
	var indicators = _get_placement_indicators()
	if indicators == null:
		return
	var card: Unit_Card = curr_unit_inst as Unit_Card
	var footprint: Vector2 = card.rotated_placement_size if rotated_placement else card.placement_size
	var vecs: Array = card.rotated_vectors if rotated_placement else card.placement_vectors
	var anchor: Vector2 = objectCells[0].global_position
	var cell: Vector2 = _board_cell_size()
	var is_multi: bool = card.num_units > 1
	var player_points: Array[Vector2] = PlacementIndicators.compute_pack_points(
		anchor, footprint, cell, is_multi
	)
	var player_center: Vector2 = PlacementIndicators.footprint_center(anchor, footprint, cell)
	var unit_worlds: Array[Vector2] = []
	for v in vecs:
		# Match BattleManager.add_unit_to_board (square cells: scale by cellHeight).
		unit_worlds.append(anchor + v * cell.y)
	indicators.update_preview(
		player_points,
		player_center,
		unit_worlds,
		_cached_is_melee,
		_cached_attack_range
	)
