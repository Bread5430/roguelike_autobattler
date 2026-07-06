extends Control
class_name RestUI

signal upgrade_requested(slot_data: Dictionary, slot_index: int)
signal upgrade_path_selected(slot_data: Dictionary, slot_index: int, path: String)
signal upgrade_path_cancelled
signal repair_requested
signal craft_mode_entered
signal craft_mode_exited
signal refresh_requested
signal leave_requested

const SHOP_SLOT_SCENE := preload("res://UI/ShopSlot.tscn")

@export var repair_cost := 2
@export var craft_cost := 3
@export var refresh_cost := 1

@onready var _backdrop: ColorRect = $Backdrop
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _actions_label: Label = $MainPanel/Margin/VBox/HeaderRow/ActionsLeftLabel
@onready var _components_label: Label = $MainPanel/Margin/VBox/HeaderRow/ComponentsLabel
@onready var _upgrade_row: HBoxContainer = $MainPanel/Margin/VBox/UpgradeRow
@onready var _repair_button: Button = $MainPanel/Margin/VBox/ActionRow/RepairButton
@onready var _craft_button: Button = $MainPanel/Margin/VBox/ActionRow/CraftButton
@onready var _refresh_button: Button = $MainPanel/Margin/VBox/ActionRow/RefreshButton
@onready var _leave_button: Button = $MainPanel/Margin/VBox/ActionRow/LeaveButton
@onready var _craft_overlay: Control = $CraftOverlay
@onready var _craft_backdrop: ColorRect = $CraftOverlay/CraftBackdrop
@onready var _craft_return_button: Button = $CraftOverlay/CraftPanel/Margin/VBox/ReturnButton
@onready var _upgrade_overlay: Control = $UpgradePathOverlay
@onready var _upgrade_backdrop: ColorRect = $UpgradePathOverlay/UpgradeBackdrop
@onready var _upgrade_card_name: Label = $UpgradePathOverlay/UpgradePanel/Margin/VBox/UpgradeCardName
@onready var _path_a_button: Button = $UpgradePathOverlay/UpgradePanel/Margin/VBox/PathAButton
@onready var _path_b_button: Button = $UpgradePathOverlay/UpgradePanel/Margin/VBox/PathBButton
@onready var _upgrade_cancel_button: Button = $UpgradePathOverlay/UpgradePanel/Margin/VBox/UpgradeCancelButton

var _offers: Dictionary = {}
var _upgrade_slots: Array[ShopSlot] = []
var _panel_visible := true
var _craft_mode := false
var _upgrade_mode := false
var _pending_upgrade_slot_index := -1
var _pending_upgrade_slot_data: Dictionary = {}
var _passthrough_helper: Node
var _last_components: int = 0
var _item_details_builder := ItemDetailsBuilder.new()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_craft_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_craft_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_craft_overlay.get_node("CraftPanel").mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_overlay.get_node("UpgradePanel").mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_craft_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_upgrade_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_repair_button.pressed.connect(_on_repair_pressed)
	_craft_button.pressed.connect(_on_craft_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_craft_return_button.pressed.connect(_on_craft_return_pressed)
	_path_a_button.pressed.connect(_on_path_a_pressed)
	_path_b_button.pressed.connect(_on_path_b_pressed)
	_upgrade_cancel_button.pressed.connect(_on_upgrade_cancel_pressed)


func setup(passthrough_helper: Node) -> void:
	_passthrough_helper = passthrough_helper


func open(offers: Dictionary, components: int) -> void:
	_offers = offers.duplicate(true)
	_last_components = components
	_panel_visible = true
	_craft_mode = false
	_upgrade_mode = false
	_craft_overlay.visible = false
	_upgrade_overlay.visible = false
	_build_upgrade_row()
	_update_header(components)
	_update_action_buttons(components)
	_set_panel_visible(true)
	visible = true


func close() -> void:
	if _craft_mode:
		exit_craft_mode()
	if _upgrade_mode:
		exit_upgrade_mode()
	_set_panel_visible(false)
	visible = false
	_clear_upgrade_row()


func is_panel_visible() -> bool:
	return _panel_visible and visible


func toggle_panel_visibility() -> void:
	if not visible or _craft_mode or _upgrade_mode:
		return
	_set_panel_visible(not _panel_visible)


func get_offers() -> Dictionary:
	return _offers.duplicate(true)


func set_offers(offers: Dictionary, components: int) -> void:
	_offers = offers.duplicate(true)
	_last_components = components
	_rebuild_upgrade_data()
	_update_header(components)
	_update_action_buttons(components)


func refresh_display(components: int) -> void:
	_last_components = components
	_update_header(components)
	_update_action_buttons(components)
	for slot in _upgrade_slots:
		slot._refresh_display()


func enter_craft_mode() -> void:
	if _craft_mode or _upgrade_mode:
		return
	_craft_mode = true
	_craft_overlay.visible = true
	_set_rest_controls_enabled(false)
	craft_mode_entered.emit()


func exit_craft_mode() -> void:
	if not _craft_mode:
		return
	_craft_mode = false
	_craft_overlay.visible = false
	_set_rest_controls_enabled(true)
	craft_mode_exited.emit()


func enter_upgrade_mode(slot_data: Dictionary, slot_index: int) -> void:
	if _craft_mode or _upgrade_mode:
		return
	_pending_upgrade_slot_data = slot_data.duplicate(true)
	_pending_upgrade_slot_index = slot_index
	_upgrade_mode = true
	_configure_upgrade_overlay(slot_data)
	_upgrade_overlay.visible = true
	_set_rest_controls_enabled(false)


func exit_upgrade_mode() -> void:
	if not _upgrade_mode:
		return
	_upgrade_mode = false
	_upgrade_overlay.visible = false
	_pending_upgrade_slot_index = -1
	_pending_upgrade_slot_data = {}
	_set_rest_controls_enabled(true)


func mark_upgrade_purchased(slot_index: int) -> void:
	var row: Array = _offers.get("upgrades", [])
	if slot_index < 0 or slot_index >= row.size():
		return
	row[slot_index]["purchased"] = true
	if slot_index < _upgrade_slots.size():
		_upgrade_slots[slot_index].mark_purchased()


func _configure_upgrade_overlay(slot_data: Dictionary) -> void:
	var base_id := str(slot_data.get("upgrade_id", ""))
	var labels := UNIT_UPGRADES.get_labels(base_id)
	_upgrade_card_name.text = _display_name_for_item(base_id)
	var label_a := str(labels.get(UNIT_UPGRADES.PATH_A, "Path A"))
	var label_b := str(labels.get(UNIT_UPGRADES.PATH_B, "Path B"))
	var blurb_a := UNIT_UPGRADES.get_blurb(base_id, UNIT_UPGRADES.PATH_A)
	var blurb_b := UNIT_UPGRADES.get_blurb(base_id, UNIT_UPGRADES.PATH_B)
	var price := int(slot_data.get("base_price", 0))
	if slot_data.get("on_sale", false):
		price = int(floor(float(price) * 0.5))
	var price_suffix := " (%dc)" % price
	_path_a_button.text = "%s\n%s%s" % [label_a, blurb_a, price_suffix] if blurb_a != "" else "%s%s" % [label_a, price_suffix]
	_path_b_button.text = "%s\n%s%s" % [label_b, blurb_b, price_suffix] if blurb_b != "" else "%s%s" % [label_b, price_suffix]
	var can_afford := _last_components >= price
	_path_a_button.disabled = not can_afford
	_path_b_button.disabled = not can_afford


func _display_name_for_item(item_id: String) -> String:
	if item_id.is_empty():
		return "Unknown"
	var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
	if scene == null:
		return item_id
	var inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if inst is Unit_Card:
		var payload := _item_details_builder.build_payload(inst as Unit_Card, item_id)
		inst.queue_free()
		return str(payload.get("display_name", item_id))
	if inst:
		inst.queue_free()
	return item_id


func _build_upgrade_row() -> void:
	_clear_upgrade_row()
	var row_data: Array = _offers.get("upgrades", [])
	for i in row_data.size():
		var slot: ShopSlot = SHOP_SLOT_SCENE.instantiate()
		_upgrade_row.add_child(slot)
		slot.configure(row_data[i])
		slot.slot_pressed.connect(func(data: Dictionary): _on_upgrade_slot_pressed(data, i))
		_upgrade_slots.append(slot)


func _rebuild_upgrade_data() -> void:
	_apply_row_data(_upgrade_slots, _offers.get("upgrades", []))


func _apply_row_data(slots: Array[ShopSlot], row_data: Array) -> void:
	for i in mini(slots.size(), row_data.size()):
		if row_data[i].get("purchased", false):
			slots[i].configure(row_data[i])
		else:
			slots[i].reroll(row_data[i])


func _clear_upgrade_row() -> void:
	for child in _upgrade_row.get_children():
		child.queue_free()
	_upgrade_slots.clear()


func _on_upgrade_slot_pressed(slot_data: Dictionary, slot_index: int) -> void:
	if _craft_mode or _upgrade_mode:
		return
	upgrade_requested.emit(slot_data, slot_index)


func _on_path_a_pressed() -> void:
	_emit_upgrade_path(UNIT_UPGRADES.PATH_A)


func _on_path_b_pressed() -> void:
	_emit_upgrade_path(UNIT_UPGRADES.PATH_B)


func _emit_upgrade_path(path: String) -> void:
	if not _upgrade_mode:
		return
	var data := _pending_upgrade_slot_data.duplicate(true)
	var index := _pending_upgrade_slot_index
	exit_upgrade_mode()
	upgrade_path_selected.emit(data, index, path)


func _on_upgrade_cancel_pressed() -> void:
	exit_upgrade_mode()
	upgrade_path_cancelled.emit()


func _on_repair_pressed() -> void:
	if _craft_mode or _upgrade_mode:
		return
	repair_requested.emit()


func _on_craft_pressed() -> void:
	if _craft_mode or _upgrade_mode:
		return
	enter_craft_mode()


func _on_refresh_pressed() -> void:
	if _craft_mode or _upgrade_mode:
		return
	refresh_requested.emit()


func _on_leave_pressed() -> void:
	if _craft_mode or _upgrade_mode:
		return
	leave_requested.emit()


func _on_craft_return_pressed() -> void:
	exit_craft_mode()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			accept_event()


func _set_panel_visible(show_panel: bool) -> void:
	_panel_visible = show_panel
	_backdrop.visible = show_panel
	_main_panel.visible = show_panel
	if show_panel and visible and not _craft_mode and not _upgrade_mode:
		if _passthrough_helper:
			_passthrough_helper.block_input()
	elif _passthrough_helper and not _craft_mode and not _upgrade_mode:
		_passthrough_helper.unblock_input()


func _set_rest_controls_enabled(enabled: bool) -> void:
	_repair_button.disabled = not enabled
	_craft_button.disabled = not enabled
	_refresh_button.disabled = not enabled
	_leave_button.disabled = not enabled
	for slot in _upgrade_slots:
		var purchased: bool = slot.slot_data.get("purchased", false)
		slot.disabled = not enabled or purchased


func _update_header(components: int) -> void:
	var actions_left := int(_offers.get("actions_left", 0))
	_actions_label.text = "Actions Left: %d" % actions_left
	_components_label.text = "Components: %d" % components


func _update_action_buttons(components: int) -> void:
	var actions_left := int(_offers.get("actions_left", 0))
	var has_actions := actions_left > 0
	_repair_button.text = "Repair (+20%% HP, %dc)" % repair_cost
	_craft_button.text = "Craft duplicate (%dc)" % craft_cost
	_refresh_button.text = "Refresh upgrades (%dc)" % refresh_cost
	_repair_button.disabled = _craft_mode or _upgrade_mode or not has_actions or components < repair_cost
	_craft_button.disabled = _craft_mode or _upgrade_mode or not has_actions or components < craft_cost
	_refresh_button.disabled = _craft_mode or _upgrade_mode or components < refresh_cost
	for slot in _upgrade_slots:
		if slot.slot_data.get("purchased", false):
			slot.disabled = true
			continue
		slot.disabled = _craft_mode or _upgrade_mode or not has_actions
