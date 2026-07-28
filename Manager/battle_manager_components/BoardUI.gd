
extends GridContainer

## Top and bottom board rows treated as side strips (stun corridor / formation mirror).
const SIDE_ROWS : int = 3

@export var width := 5:
	set(value): 
		width = value
		_remove_grid()
		_create_grid()
@export var height := 5:
	set(value): 
		height = value
		_remove_grid()
		_create_grid()
@export var cellWidth := 100:
	set(value): 
		cellWidth = value
		_remove_grid()
		_create_grid()
@export var cellHeight := 100:
	set(value):
		cellHeight = value
		_remove_grid()
		_create_grid()
@export var borderSize = 0:
	set(value):
		borderSize = value
		_remove_grid()
		_create_grid()

## Tile offset (in board cells) applied to the whole grid's position, starting
## placement at cell (1, 1) instead of (0, 0). This keeps every placed unit off
## the battle space's world origin edge (row/col 0 of BattleManager.tile_map_size),
## which the flow field otherwise always treats as a map border regardless of
## actual unit adjacency.
@export var start_offset : Vector2i = Vector2i(1, 1):
	set(value):
		start_offset = value
		_remove_grid()
		_create_grid()

## Logical board coordinate offset applied to BoardSlot.board_position.
## Side strips sit outside the main board vertically: top strip maps to
## y -SIDE_ROWS..-1, bottom strip to y height..height+SIDE_ROWS-1.
@export var board_position_offset : Vector2i = Vector2i.ZERO

@export var GRID_CELL : PackedScene

func is_side_row(y: int) -> bool:
	return y < SIDE_ROWS or y >= height - SIDE_ROWS


func _create_grid():
	add_theme_constant_override("h_separation", borderSize)
	add_theme_constant_override("v_separation", borderSize)
	
	columns = width
	position = Vector2(start_offset.x * cellWidth, start_offset.y * cellHeight)

	for i in width * height:
		var gridCellNode : BoardSlot = GRID_CELL.instantiate()
		gridCellNode.custom_minimum_size = Vector2(cellWidth, cellHeight)
		gridCellNode.set_board_position(Vector2(i % width + board_position_offset.x, int(i / width) + board_position_offset.y))
		add_child(gridCellNode)

func _remove_grid():
	for node in get_children():
		node.queue_free()

func post_ready():
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	for i in get_children():
		if i.has_method("post_ready"):
			i.post_ready()
