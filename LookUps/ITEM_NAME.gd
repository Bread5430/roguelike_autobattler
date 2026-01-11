extends Node

const items_path = "res://Data/items.csv"

func _ready():
	load_unit_csv(items_path)

func item_lookup(itemname : String) -> PackedScene:
	if itemname in name_obj_map:
		return name_obj_map[itemname]
	return null

enum  ROLES {
	CARRY = 1,
	SWARM = 2,
	CLEAR = 4,
	TANK = 8
}

const ROLE_LOOKUP := {
	"CARRY": ROLES.CARRY,
	"SWARM": ROLES.SWARM,
	"CLEAR": ROLES.CLEAR,
	"TANK": ROLES.TANK
}

var name_obj_map = {}
var unit_role_map = []



# Get the names of all the units that match one of the listed roles
# Caller will process these names and then ask for a seperate lookup to get the actual scenes these names point to
func get_all_matching_roles(bitstring : int) -> Array:
	var matches = []
	for map_item in unit_role_map:
		if bitstring & map_item[0]:
			matches.append(map_item[1])
	return matches

func load_unit_csv(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open unit CSV: %s" % path)
		return {}

	# Skip header
	file.get_line()

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue

		var c := line.split(",", false)
		if c.size() < 2 or c[0] == "":
			continue

		var name := c[0]
		var scene_path := c[1]
		var roles_str := c[2] if c.size() > 2 else ""

		# ---- name → PackedScene ----
		name_obj_map[name] = load(scene_path) as PackedScene

		# ---- roles → bitmask ----
		if roles_str != "":
			var role_mask := 0
			for role_name in roles_str.split("|"):
				if ROLE_LOOKUP.has(role_name):
					role_mask |= ROLE_LOOKUP[role_name]
				else:
					push_warning("Unknown role '%s' for unit '%s'" % [role_name, name])

			unit_role_map.append([role_mask, name])

	file.close()
