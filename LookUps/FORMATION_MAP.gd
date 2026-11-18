extends Node

const formation_path = "res://Data/formations.csv"
const mini_formation_path = "res://Data/mini_formations.csv"

const SURFACE_MAIN := "main"
const SURFACE_SIDE := "side"

## Mini-formation rows use local template coords (0,0 = top-left of the patch), not
## absolute board coords. Spawn adds a random anchor; see enemy_spawner gap-fill.
const MINI_BOARD_WIDTH := 12
const MINI_BOARD_HEIGHT := 24
const MINI_SIDE_ROWS := 3
const MINI_MAIN_PLAYABLE_HEIGHT : int = MINI_BOARD_HEIGHT - 2 * MINI_SIDE_ROWS

const LEVELS = {
	"light" : 0,
	"medium" : 1,
	"heavy" : 2
}
var formation_map = {}
## level -> formation_name -> { "surface": String, "rows": Array }
var mini_formation_map = {}

func _ready():
	randomize()
	formation_map = load_formation_csv_structured(formation_path)
	mini_formation_map = load_mini_formation_csv_structured(mini_formation_path)


# Used to find specific formation - for bosses or fixed events
func formation_lookup(formation : String) -> Array:
	for L in LEVELS:
		if formation in formation_map[L]:
			return formation_map[L][formation]
	return []


func mini_formation_lookup(formation_name: String) -> Dictionary:
	for L in LEVELS:
		if formation_name in mini_formation_map[L]:
			return mini_formation_map[L][formation_name]
	return {}


# Get a random formation that matches this given density level
func random_formation(density : String):
	if density not in LEVELS:
		return false

	return formation_map[density][formation_map[density].keys().pick_random()]


## Returns { "surface": "main"|"side", "rows": Array } or null.
func random_mini_formation(density: String, surface: String) -> Variant:
	if density not in LEVELS:
		return null
	if surface != SURFACE_MAIN and surface != SURFACE_SIDE:
		return null
	if not mini_formation_map.has(density):
		return null
	var pool: Array = []
	for formation_name in mini_formation_map[density].keys():
		var def: Dictionary = mini_formation_map[density][formation_name]
		if str(def.get("surface", "")) == surface:
			pool.append(formation_name)
	if pool.is_empty():
		return null
	var picked: String = pool.pick_random()
	return mini_formation_map[density][picked].duplicate(true)


func load_formation_csv_structured(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open CSV: %s" % path)
		return {}

	var result := {}

	# Skip header
	file.get_line()

	var current_level := ""
	var current_name := ""

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue

		var c := line.split(",", true)

		var name := c[0]
		var level := c[1]

		# New formation starts when name is present
		if name != "":
			current_name = name
			current_level = level

			if not result.has(current_level):
				result[current_level] = {}

			result[current_level][current_name] = []

		var exact_val = null
		if c.size() > 8:
			var raw := str(c[8]).strip_edges()
			if raw != "":
				exact_val = raw
		var entry := {
			"x": int(c[2]),
			"y": int(c[3]),
			"w": int(c[4]),
			"h": int(c[5]),
			"role": int(c[6]),
			"group": int(c[7]),
			"exact_unit": exact_val,
			"exact_type": exact_val,
		}

		result[current_level][current_name].append(entry)

	file.close()
	return result


func load_mini_formation_csv_structured(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Mini formations CSV missing (optional): %s" % path)
		return {}

	var result := {}
	file.get_line()

	var current_level := ""
	var current_name := ""
	var current_surface := ""

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue

		var c := line.split(",", true)
		if c.size() < 9:
			push_warning("Mini formation row too short: %s" % line)
			continue

		var name := str(c[0]).strip_edges()
		if name != "":
			current_name = name
			current_level = str(c[1]).strip_edges().to_lower()
			current_surface = str(c[2]).strip_edges().to_lower()
			if current_surface != SURFACE_MAIN and current_surface != SURFACE_SIDE:
				push_error("Mini formation '%s' has invalid Surface '%s' (use main or side)" % [current_name, current_surface])
				continue
			if not result.has(current_level):
				result[current_level] = {}
			result[current_level][current_name] = {
				"surface": current_surface,
				"rows": [],
			}

		if current_name == "" or not result.has(current_level):
			continue

		var exact_val = null
		if c.size() > 9:
			var raw := str(c[9]).strip_edges()
			if raw != "":
				exact_val = raw
		var entry := {
			"x": int(c[3]),
			"y": int(c[4]),
			"w": int(c[5]),
			"h": int(c[6]),
			"role": int(c[7]),
			"group": int(c[8]),
			"exact_unit": exact_val,
			"exact_type": exact_val,
			"placement_surface": current_surface,
		}
		result[current_level][current_name]["rows"].append(entry)

	file.close()

	for level in result.keys():
		for formation_name in result[level].keys():
			var def: Dictionary = result[level][formation_name]
			if not _validate_mini_formation_surface(formation_name, def):
				def["rows"] = []

	return result


func _validate_mini_formation_surface(formation_name: String, def: Dictionary) -> bool:
	var surface: String = str(def.get("surface", ""))
	var rows: Array = def.get("rows", [])
	if rows.is_empty():
		push_warning("Mini formation '%s' has no rows" % formation_name)
		return false

	var max_x := 0
	var max_y := 0
	for row in rows:
		var parsed: Dictionary = row
		var x: int = int(parsed["x"])
		var y: int = int(parsed["y"])
		var w: int = int(parsed["w"])
		var h: int = int(parsed["h"])
		if x < 0 or y < 0:
			push_error(
				"Mini formation '%s': row x=%d y=%d must be non-negative (template-local coords)" % [
					formation_name, x, y
				]
			)
			return false
		max_x = maxi(max_x, x + w)
		max_y = maxi(max_y, y + h)

	if surface == SURFACE_MAIN:
		if max_x > MINI_BOARD_WIDTH or max_y > MINI_MAIN_PLAYABLE_HEIGHT:
			push_error(
				"Mini formation '%s' (main): footprint %dx%d exceeds placeable main patch %dx%d"
				% [formation_name, max_x, max_y, MINI_BOARD_WIDTH, MINI_MAIN_PLAYABLE_HEIGHT]
			)
			return false
	elif surface == SURFACE_SIDE:
		if max_x > MINI_BOARD_WIDTH or max_y > MINI_SIDE_ROWS:
			push_error(
				"Mini formation '%s' (side): footprint %dx%d exceeds strip patch %dx%d"
				% [formation_name, max_x, max_y, MINI_BOARD_WIDTH, MINI_SIDE_ROWS]
			)
			return false
	else:
		push_error("Mini formation '%s': unknown surface '%s'" % [formation_name, surface])
		return false
	return true
