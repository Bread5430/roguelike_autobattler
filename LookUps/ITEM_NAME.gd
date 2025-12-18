extends Node

func item_lookup(itemname : String) -> PackedScene:
	if itemname in name_obj_map:
		return name_obj_map[itemname]
	return null

const name_obj_map = {
	"four_melee" : preload("res://Units/unit_cards/four_melee/four_melee.tscn"),
	"chaff_swarm" : preload("res://Units/unit_cards/chaff_swarm/chaff_swarm.tscn"),
	"one_ranged" : preload("res://Units/unit_cards/one_ranged/one_ranged.tscn"),
}


enum  ROLES {
	CARRY = 1,
	SWARM = 2,
	CLEAR = 4,
	TANK = 8
}

# Get the names of all the units that match one of the listed roles
# Caller will process these names and then ask for a seperate lookup to get the actual scenes these names point to
func get_all_matching_roles(bitstring : int) -> Array:
	var matches = []
	for map_item in unit_role_map:
		if bitstring & map_item[0]:
			matches.append(unit_role_map[0])
	return matches

const unit_role_map = [
	[ROLES.SWARM | ROLES.TANK, "four_melee"],
	[ROLES.SWARM, "chaff_swarm"],
	[ROLES.CARRY, "one_ranged"],
	
]
