extends Control

class_name Inventory
signal inspect_requested(item_inst: Item, item_name: String, source_global_pos: Vector2)
signal deconstruct_item_requested(item_id: String)
signal craft_item_requested(item_id: String)
signal bandwidth_upgrade_requested
signal duplicate_unit_requested(item_id: String)

const BANDWIDTH_UPGRADE_COST: int = 2
const DUPLICATE_IDLE_TEXT := "Duplicate Unit"

var slots : Array[InventorySlot]

@onready var inventory_grid : GridContainer = $InventoryGrid
@onready var upgrade_menu : VBoxContainer = $UpgradeMenu
@onready var upgrade_bandwidth_button : Button = $UpgradeMenu/UpgradeBandwidthButton
@onready var duplicate_unit_button : Button = $UpgradeMenu/DuplicateUnitButton
@export var starter_items : Array[String]
@export var starter_items_count : Array[int]
@export var columns : int
@export var rows : int

@export var slot_autoload : PackedScene 

var can_open_inventory = true
var deconstruct_mode = false
var craft_mode = false
var duplicate_mode = false
var _run_components : int = 0
var _run_scrap : int = 0

func _ready():
	toggle_window(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	inventory_grid.columns = columns

	for i in columns * rows:
		var new_slot = slot_autoload.instantiate()
		slots.append(new_slot)
		new_slot.set_item("", null, 0)
		new_slot.slot_right_clicked.connect(_on_slot_right_clicked)
		new_slot.mouse_entered.connect(_on_slot_mouse_entered.bind(new_slot))
		new_slot.mouse_exited.connect(_on_slot_mouse_exited.bind(new_slot))
		inventory_grid.add_child(new_slot)

	if upgrade_bandwidth_button:
		upgrade_bandwidth_button.pressed.connect(_on_upgrade_bandwidth_pressed)
	if duplicate_unit_button:
		duplicate_unit_button.pressed.connect(_on_duplicate_unit_pressed)

func post_ready():
	# Give slots a refernce to parent inventory
	for slot in inventory_grid.get_children():
		slot.parent_inventory = self
		
	# Give initial items
	for i in starter_items.size():
		add_item(starter_items[i],starter_items_count[i])

func _process(_delta: float) -> void:
	if DevConsole.is_blocking_game_input():
		return
	if deconstruct_mode or craft_mode:
		return
	if duplicate_mode:
		return
	if Input.is_action_just_pressed("inventory") and can_open_inventory:
		toggle_window(!visible)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not duplicate_mode:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	set_duplicate_mode(false)
	get_viewport().set_input_as_handled()


func toggle_window (open : bool):
	visible = open
	if open:
		move_to_front()
		var gui = get_parent()
		if gui and gui.get("gsm") and gui.gsm:
			refresh_upgrade_menu(gui.gsm.run_components, gui.gsm.run_gold)
	
	if visible:
		for slot in inventory_grid.get_children():
			slot.set_slot_visible()
	else:
		if duplicate_mode:
			set_duplicate_mode(false)
		for slot in inventory_grid.get_children():
			slot.set_slot_invisible()
	_refresh_upgrade_menu_visibility()

func on_give_player_item (_itemID : String, _amount : int):
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
	var slot = get_slot_to_remove(itemID)
  
	if slot == null or slot.item != item or slot.quantity < count:
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


func get_owned_item_ids(filter: String = "any") -> Array[String]:
	var owned: Array[String] = []
	for slot in slots:
		if slot.item_name.is_empty() or slot.quantity <= 0:
			continue
		if _item_matches_filter(slot.item_name, filter):
			owned.append(slot.item_name)
	return owned


func _item_matches_filter(item_id: String, filter: String) -> bool:
	var normalized = filter.strip_edges().to_lower()
	if normalized.is_empty() or normalized == "any":
		return true
	var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
	if scene == null:
		return false
	var path = scene.resource_path
	if normalized == "spell":
		return "Spells/" in path
	if normalized == "unit":
		if "Spells/" in path:
			return false
		var inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
		var is_unit = inst is Unit_Card
		if inst:
			inst.queue_free()
		return is_unit
	return true


func remove_all_of_item(item_id: String) -> int:
	var removed = 0
	for slot in slots:
		if slot.item_name == item_id and slot.quantity > 0:
			removed += slot.quantity
			slot.set_item("", null, 0)
	return removed


func set_deconstruct_mode(enabled: bool) -> void:
	deconstruct_mode = enabled
	if enabled:
		craft_mode = false
		set_duplicate_mode(false)
		toggle_window(true)
	elif visible and not craft_mode:
		toggle_window(false)
	_refresh_upgrade_menu_visibility()


func set_craft_mode(enabled: bool) -> void:
	craft_mode = enabled
	if enabled:
		deconstruct_mode = false
		set_duplicate_mode(false)
		toggle_window(true)
	elif visible and not deconstruct_mode:
		toggle_window(false)
	_refresh_upgrade_menu_visibility()


func set_duplicate_mode(enabled: bool) -> void:
	if duplicate_mode == enabled:
		if enabled:
			_reset_duplicate_button_text()
			_refresh_slot_cost_labels()
		return
	duplicate_mode = enabled
	_reset_duplicate_button_text()
	_refresh_slot_cost_labels()
	if duplicate_unit_button:
		duplicate_unit_button.button_pressed = enabled


func refresh_upgrade_menu(components: int, scrap: int) -> void:
	_run_components = components
	_run_scrap = scrap
	if upgrade_bandwidth_button:
		upgrade_bandwidth_button.disabled = _run_components < BANDWIDTH_UPGRADE_COST
		upgrade_bandwidth_button.text = "Upgrade Bandwidth\n+10  (%d Components)" % BANDWIDTH_UPGRADE_COST
	_reset_duplicate_button_text()


func _refresh_upgrade_menu_visibility() -> void:
	if upgrade_menu == null:
		return
	upgrade_menu.visible = visible and not deconstruct_mode and not craft_mode


func _on_upgrade_bandwidth_pressed() -> void:
	if deconstruct_mode or craft_mode:
		return
	bandwidth_upgrade_requested.emit()


func _on_duplicate_unit_pressed() -> void:
	if deconstruct_mode or craft_mode:
		return
	if not visible:
		toggle_window(true)
	set_duplicate_mode(not duplicate_mode)


func _on_slot_mouse_entered(slot: InventorySlot) -> void:
	if not duplicate_mode or slot == null or not (slot.item_inst is Unit_Card):
		return
	var cost = (slot.item_inst as Unit_Card).get_duplicate_cost()
	if duplicate_unit_button:
		duplicate_unit_button.text = "Duplicate Unit\n%d Comp, %d Scrap" % [int(cost.get("components", 0)), int(cost.get("scrap", 0))]


func _on_slot_mouse_exited(_slot: InventorySlot) -> void:
	if duplicate_mode:
		_reset_duplicate_button_text()


func _reset_duplicate_button_text() -> void:
	if duplicate_unit_button == null:
		return
	if duplicate_mode:
		duplicate_unit_button.text = "Duplicate Unit\nClick a unit"
	else:
		duplicate_unit_button.text = DUPLICATE_IDLE_TEXT


func _refresh_slot_cost_labels() -> void:
	for slot in slots:
		slot.update_bandwidth_cost_text()


func clear_all_slots() -> void:
	for slot in slots:
		slot.set_item("", null, 0)


func refresh_unit_card_icons() -> void:
	for slot in slots:
		if slot.item_inst is Unit_Card:
			var card = slot.item_inst as Unit_Card
			card.setup_unit()
			if slot.button_icon and card.get_texture():
				slot.button_icon.texture = card.get_texture()
			slot.update_bandwidth_cost_text()

func set_current_item(slot : InventorySlot):
	# Pass the item up to the GUI
	get_parent().set_current_item(slot)

func _on_slot_right_clicked(slot: InventorySlot, source_global_pos: Vector2) -> void:
	if slot == null or slot.item_inst == null:
		return
	inspect_requested.emit(slot.item_inst, slot.item_name, source_global_pos)
