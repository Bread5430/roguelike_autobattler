extends Node

const formation_path = "res://Data/formations.csv"

const LEVELS = {
	"light" : 0,
	"medium" : 1,
	"heavy" : 2
}
var formation_map = {}

func _ready():
	randomize()
	formation_map = load_formation_csv_structured(formation_path)

# Used to find specific formation - for bosses or fixed events
func formation_lookup(formation : String) -> Array:
	for L in LEVELS:
		if formation in formation_map[L]:
			return formation_map[L][formation]
	return []

# Get a random formation that matches this given density level
func random_formation(density : String):
	if density not in LEVELS:
		return false
	
	return formation_map[density][formation_map[density].keys().pick_random()]
	
	
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

		var entry := {
			"x": int(c[2]),
			"y": int(c[3]),
			"w": int(c[4]),
			"h": int(c[5]),
			"role": int(c[6]),
			"group": int(c[7]),
			"exact_unit": c[8] if (c.size() > 8 and c[8] != "") else null
		}

		result[current_level][current_name].append(entry)

	file.close()
	return result
