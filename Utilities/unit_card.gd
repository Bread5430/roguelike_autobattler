extends Item
class_name Unit_Card
#const PLACEMENT_TILE_SIZE = 50

@export var num_units : int
@export var placement_size : Vector2
var rotated_placement_size : Vector2 

@export var related_unit : PackedScene
## When true, offered at rest sites for unit-card upgrades (one path choice per run).
@export var is_upgradable: bool = true
## When true, only spawned via enemy formations — excluded from player inventory grants and battle rewards.
@export var enemy_formation_only: bool = false
## When true, other routers cannot be placed overlapping this card's [member router_exclusion_radius] (deployment only).
@export var is_router_card: bool = false
## World pixels: minimum center-to-center spacing vs other routers' zones ([code]r_self + r_other[/code]).
@export var router_exclusion_radius: float = 180.0

var placement_vectors : Array
var rotated_vectors : Array


# Returns of Vector of size 1x2, based on if it wants to be rotated
# First index is placement size
# Second index is plcement vectors
func get_placement(rotated : bool) -> Array:
	if rotated:
		return [rotated_placement_size,rotated_vectors]
	else:
		return [placement_size, placement_vectors]


func get_unit_glossary_id() -> String:
	if related_unit == null:
		return ""
	var unit_inst = related_unit.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var glossary_id := ""
	if unit_inst is Base_Unit:
		glossary_id = (unit_inst as Base_Unit).unit_glossary_id
	unit_inst.queue_free()
	return glossary_id


func get_total_scrap_cost() -> int:
	var glossary_id := get_unit_glossary_id()
	if glossary_id.is_empty():
		return 0
	var cost := UNIT_GLOSSARY.get_scrap_cost(glossary_id) * num_units
	if not item_name.is_empty() and UnitUpgradeRegistry.has_upgrade(item_name):
		cost *= 2
	return cost


func _apply_upgraded_card_texture() -> void:
	if item_name.is_empty():
		return
	var path := UnitUpgradeRegistry.get_upgrade_path(item_name)
	if path.is_empty():
		return
	var tex_path := UNIT_UPGRADES.get_card_sprite_path(item_name, path)
	if tex_path.is_empty() or not ResourceLoader.exists(tex_path):
		return
	var res: Resource = load(tex_path)
	if res is Texture2D:
		texture = res as Texture2D


### Internal Functions

func setup_unit():
	item_type = TYPE.unit_card
	placement_vectors = divide_grid(num_units)
	rotated_vectors = get_rotated_placement_vectors()
	rotated_placement_size = Vector2(placement_size.y, placement_size.x)
	_apply_upgraded_card_texture()

func get_rotated_placement_vectors() -> Array:
	var rot_arr = []
	for i in placement_vectors:
		rot_arr.append(Vector2(i.y, i.x))
	return rot_arr

func divide_grid(n: int) -> Array:
	var best_rows : int = 1
	var best_cols : int = n
	var min_aspect_diff := INF
	
	# Step 1: Find optimal rows and columns
	for rows in range(1, int(sqrt(n)) + 1):
		if n % rows == 0:
			var cols := int(n / rows)
			var aspect_ratio_grid := placement_size.x / placement_size.y
			var aspect_ratio_cell :=  cols / rows
			var aspect_diff : float = abs(log(aspect_ratio_grid) - log(aspect_ratio_cell))
			
			if aspect_diff < min_aspect_diff:
				min_aspect_diff = aspect_diff
				best_rows = rows
				best_cols = cols
	
	var rows := best_rows
	var cols := best_cols
	
	# Step 2: Cell size
	var cell_width := placement_size.x / cols
	var cell_height := placement_size.y / rows
	
	# Step 3: Calculate centers
	var centers := []
	for r in range(rows):
		for c in range(cols):
			var center_x := (c + 0.5) * cell_width
			var center_y := (r + 0.5) * cell_height
			centers.append(Vector2(center_x, center_y))
	
	return centers
