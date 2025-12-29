extends Node2D

@export var showAllied : bool = false
@export var showEnemy : bool = false
@export var drawGrid : bool = false
@onready var redraw_timer = $Redraw_Timer

var vectorFrom = Vector2(0, 0) #setget setfromvector

const arrowAngle: float = PI / 6.0
const arrowToVecRatio: float = 5.0
	

func draw_field(faction : bool):
	var flow_field
	var color
	if faction:
		flow_field = get_parent().flow_gen.friendly_flow
		color = Color(0,255,0)
	else:
		flow_field = get_parent().flow_gen.enemy_flow
		color = Color(255,0,0)
	
	var tile_size = get_parent().tile_size
	
	for x in flow_field.size():
		for y in flow_field[0].size():
			if Vector2(flow_field[x][y]) != Vector2.ZERO:
				# Draw an arrow that ends in a circle pointing in the direction of the vector
				draw_line(Vector2(tile_size * (x + 0.5) , tile_size * (y + 0.5)), \
					Vector2(tile_size * (x + 0.5), tile_size * (y + 0.5)) + Vector2(flow_field[x][y] * tile_size / 5).normalized() * 20, \
					color, 1.0)
				draw_circle(Vector2(tile_size * (x + 0.5), tile_size * (y + 0.5)) + \
					Vector2(flow_field[x][y] * tile_size / 5).normalized() * 20, 3, color)
			
			
func draw_borders(faction : bool):
	var border
	var color
	if faction:
		border =  get_parent().flow_gen.friendly_border_tiles
		color = Color(0,255,30)
	else:
		border =  get_parent().flow_gen.enemy_border_tiles
		color = Color(255,0,30)
	
	var tile_size = get_parent().tile_size
	
	for b in border:
		draw_circle(Vector2(tile_size * (b.x + 0.5), tile_size * (b.y + 0.5)), 3, color)
	
func draw_grid():
	var tile_size = get_parent().tile_size
	var tile_map_size = get_parent().tile_map_size
	
	for x in tile_map_size.x:
		draw_line(Vector2(x * tile_size, 0), Vector2(x * tile_size, tile_map_size.y * tile_size), Color(0,0,0), 1)
	for y in tile_map_size.y:
		draw_line(Vector2(0, y * tile_size), Vector2(tile_map_size.x * tile_size, y * tile_size), Color(0,0,0), 1)
	

func _draw() -> void:
	if drawGrid:
		draw_grid()
	if showAllied:
		draw_field(true)
		draw_borders(true)
	if showEnemy:
		draw_field(false)
		draw_borders(false)

func _on_redraw_timer_timeout():
	queue_redraw()
