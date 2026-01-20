extends Button
class_name InventorySlot

var parent_inventory : Inventory
var item : PackedScene
var item_name : String
var item_inst : Item
var quantity : int
@onready var button_icon : TextureRect = $TextureRect
@onready var quantity_text : Label = $Label

func set_slot_visible():
	set_mouse_filter(Control.MOUSE_FILTER_STOP)

func set_slot_invisible():
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)

func set_item (itemID : String, new_item : PackedScene, count : int):
	if new_item == null:
		item = null
		return
		
	item_name = itemID
	item = new_item
	item_inst = item.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	item_inst.setup_unit()
	#add_child(item_inst)
	quantity = count
	
	button_icon.visible = true
	button_icon.texture = item_inst.get_texture()
	
	var max_dim = max(button_icon.texture.get_height(), button_icon.texture.get_width())
	button_icon.scale = Vector2(self.size.x / max_dim, self.size.y / max_dim)
	
	update_quantity_text()

func add_item(count : int):
	quantity += count
	update_quantity_text()

func remove_item(count : int) -> bool:
	quantity -= count
	if quantity <= 0:
		
		button_icon.visible = false
		set_item("",null,0)
		return false
		
	update_quantity_text()
	return true
  
func update_quantity_text ():
	if quantity <= 1:
		quantity_text.text = ""
	else:
		quantity_text.text = str(quantity)


func _on_pressed():
	print("Selected button")
	if item == null:
		return
  
	#var remove_after_use = item_inst.on_select()
  
	#if remove_after_use:
		#remove_item(1)
		
	parent_inventory.toggle_window(false)
	parent_inventory.set_current_item(self)
	
	accept_event()
