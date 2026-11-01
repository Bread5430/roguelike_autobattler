extends Button
class_name InventorySlot

signal slot_right_clicked(slot: InventorySlot, source_global_pos: Vector2)

var parent_inventory : Inventory
var item : PackedScene
var item_name : String
var item_inst : Item
var quantity : int
@onready var button_icon : TextureRect = $TextureRect
@onready var quantity_text : Label = $Label
@onready var bandwidth_cost_text : Label = $ScrapCostLabel
@onready var tier_text : Label = $TierLabel

const BANDWIDTH_COST_COLOR := Color(0.4, 0.7, 1.0)
const DUPLICATE_COST_COLOR := Color(0.95, 0.75, 0.25)

func set_slot_visible():
	set_mouse_filter(Control.MOUSE_FILTER_STOP)

func set_slot_invisible():
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)

func set_item (itemID : String, new_item : PackedScene, count : int):
	if new_item == null:
		if item_inst and is_instance_valid(item_inst):
			item_inst.queue_free()
		item = null
		item_inst = null
		item_name = ""
		quantity = 0
		if button_icon:
			button_icon.visible = false
			button_icon.texture = null
		if quantity_text:
			quantity_text.text = ""
		if bandwidth_cost_text:
			bandwidth_cost_text.visible = false
			bandwidth_cost_text.text = ""
		if tier_text:
			tier_text.visible = false
			tier_text.text = ""
		return

	if item_inst and is_instance_valid(item_inst):
		item_inst.queue_free()
	item_name = itemID
	item = new_item
	item_inst = item.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	
	
	if item_inst is Unit_Card:
		item_inst.setup_unit()
	elif item_inst is Spell_Card:
		item_inst.setup_spell()
	#add_child(item_inst)
	quantity = count
	
	button_icon.visible = true
	button_icon.texture = item_inst.get_texture()
	
	var max_dim = max(button_icon.texture.get_height(), button_icon.texture.get_width())
	button_icon.scale = Vector2(self.size.x / max_dim, self.size.y / max_dim)
	
	update_quantity_text()
	update_bandwidth_cost_text()

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


func update_bandwidth_cost_text() -> void:
	if bandwidth_cost_text == null:
		return
	if item_inst is Unit_Card:
		var card = item_inst as Unit_Card
		if tier_text:
			tier_text.visible = true
			tier_text.text = "T%d" % maxi(1, card.unit_tier)
		bandwidth_cost_text.visible = true
		if parent_inventory and parent_inventory.duplicate_mode:
			var cost = card.get_duplicate_cost()
			bandwidth_cost_text.text = "%dc %ds" % [int(cost.get("components", 0)), int(cost.get("scrap", 0))]
			bandwidth_cost_text.add_theme_color_override("font_color", DUPLICATE_COST_COLOR)
		else:
			bandwidth_cost_text.text = str(card.get_total_bandwidth_cost())
			bandwidth_cost_text.add_theme_color_override("font_color", BANDWIDTH_COST_COLOR)
	else:
		if tier_text:
			tier_text.visible = false
			tier_text.text = ""
		bandwidth_cost_text.visible = false
		bandwidth_cost_text.text = ""


func _on_pressed():
	print("Selected button")
	if item == null:
		return

	if parent_inventory.deconstruct_mode:
		parent_inventory.deconstruct_item_requested.emit(item_name)
		accept_event()
		return

	if parent_inventory.craft_mode:
		if item_inst is Unit_Card:
			parent_inventory.craft_item_requested.emit(item_name)
		accept_event()
		return

	if parent_inventory.duplicate_mode:
		if item_inst is Unit_Card:
			parent_inventory.duplicate_unit_requested.emit(item_name)
		accept_event()
		return
  
	#var remove_after_use = item_inst.on_select()
  
	#if remove_after_use:
		#remove_item(1)
		
	parent_inventory.toggle_window(false)
	parent_inventory.set_current_item(self)
	
	accept_event()

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if item == null or item_inst == null:
		return
	var source_global_pos := get_global_rect().get_center()
	slot_right_clicked.emit(self, source_global_pos)
	accept_event()
