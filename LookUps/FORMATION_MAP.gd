extends Node

const LEVELS = {
	"light" : 0,
	"medium" : 1,
	"heavy" : 2
}

func _ready():
	randomize()

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

const formation_map = {
	"light" : {
		"test_light": ["[2,2,1,1,1,1]", "[2,5,2,2,1,1]"],
	},
	"medium" : {
		"test_medium" : ["[2,2,2,2,1,1]", "[5,4,2,2,1,1]", "[6,6,1,1,1,1]"],
	},
	"heavy" : {
		"test_heavy" : ["[1,1,3,3,1,1]", "[5,5,3,3,1,1]", "[2,6,2,2,1,1]"],
	}
}
