extends Control

class_name Inventory

var slots : Array[InventorySlot]

@onready var inventory_grid : GridContainer = $InventoryGrid
@export var starter_items : Array[String]
@export var starter_items_count : Array[int]
@export var columns : int
@export var rows : int

@export var slot_autoload : PackedScene 

var can_open_inventory = true

func _ready():
	toggle_window(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	inventory_grid.columns = columns

	for i in columns * rows:
		var new_slot = slot_autoload.instantiate()
		slots.append(new_slot)
		new_slot.set_item("", null, 0)
		inventory_grid.add_child(new_slot)

func post_ready():
	# Give slots a refernce to parent inventory
	for slot in inventory_grid.get_children():
		slot.parent_inventory = self
		
	# Give initial items
	for i in starter_items.size():
		add_item(starter_items[i],starter_items_count[i])

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory") and can_open_inventory:
		toggle_window(!visible)
		accept_event()


func toggle_window (open : bool):
	visible = open
	
	if visible:
		for slot in inventory_grid.get_children():
			slot.set_slot_visible()
	else:
		for slot in inventory_grid.get_children():
			slot.set_slot_invisible()

func on_give_player_item (itemID : String, amount : int):
	pass

func add_item (itemID : String, count : int):
	var item = ITEM_NAME.item_lookup(itemID)
	var slot = get_slot_to_add(itemID)
  
	if slot == null:
		return
  
	if slot.item == null:
		slot.set_item(itemID, item, count)
	elif slot.item == item:
		slot.add_item(count)

func remove_item (itemID : String, count: int) -> bool:
	var item = ITEM_NAME.item_lookup(itemID)
	var slot = get_slot_to_remove(item)
  
	if slot == null or slot.item == item or slot.quantity < count:
		return false
  
	slot.remove_item(count)
	return true

func get_slot_to_add (itemID : String) -> InventorySlot:
	var item = ITEM_NAME.item_lookup(itemID)
	for slot in slots:
		if slot.item_name == itemID:# and slot.quantity < item.max_stack_size: # Accessing Item properties requires instantiation - not sure if necesary
			return slot
  
	for slot in slots:
		if slot.item == null:
			return slot
  
	return null

func get_slot_to_remove (itemID : String) -> InventorySlot:
	for slot in slots:
		if slot.item_name == itemID:
			return slot
  
	return null

func get_number_of_item (itemID : String) -> int:
	var total = 0
  
	for slot in slots:
		if slot.item_name == itemID:
			total += slot.quantity
  
	return total

func set_current_item(slot : InventorySlot):
	# Pass the item up to the GUI
	get_parent().set_current_item(slot)
