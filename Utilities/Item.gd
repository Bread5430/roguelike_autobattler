extends Sprite2D
class_name Item

enum TYPE {
	spell_card,
	unit_card
}

# Can either be a spell or 1 stack of a unit
var item_type : TYPE
@export var item_name : String
@export var max_stack_size : int
@export var unit_slots : int
@export var spell_slots : int

func get_item_type() -> TYPE:
	return item_type
	
func get_item_name() -> String:
	return item_name
	
func on_select():
	return self

func get_slot_cost() -> Vector2:
	return Vector2(unit_slots, spell_slots)

#func get_texture() -> Texture2D:
#	return texture
