extends Control
class_name RestUI

signal upgrade_requested(slot_data: Dictionary, slot_index: int)
signal repair_requested
signal craft_mode_entered
signal craft_mode_exited
signal refresh_requested

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
@onready var _craft_overlay: Control = $CraftOverlay
@onready var _craft_backdrop: ColorRect = $CraftOverlay/CraftBackdrop
@onready var _craft_return_button: Button = $CraftOverlay/CraftPanel/Margin/VBox/ReturnButton

var _offers: Dictionary = {}
var _upgrade_slots: Array[ShopSlot] = []
var _panel_visible := true
var _craft_mode := false
var _passthrough_helper: Node


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_craft_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_craft_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_craft_overlay.get_node("CraftPanel").mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_craft_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_repair_button.pressed.connect(_on_repair_pressed)
	_craft_button.pressed.connect(_on_craft_pressed)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_craft_return_button.pressed.connect(_on_craft_return_pressed)


func setup(passthrough_helper: Node) -> void:
	_passthrough_helper = passthrough_helper


func open(offers: Dictionary, components: int) -> void:
	_offers = offers.duplicate(true)
	_panel_visible = true
	_craft_mode = false
	_craft_overlay.visible = false
	_build_upgrade_row()
	_update_header(components)
	_update_action_buttons(components)
	_set_panel_visible(true)
	visible = true


func close() -> void:
	if _craft_mode:
		exit_craft_mode()
	_set_panel_visible(false)
	visible = false
	_clear_upgrade_row()


func is_panel_visible() -> bool:
	return _panel_visible and visible


func toggle_panel_visibility() -> void:
	if not visible or _craft_mode:
		return
	_set_panel_visible(not _panel_visible)


func get_offers() -> Dictionary:
	return _offers.duplicate(true)


func set_offers(offers: Dictionary, components: int) -> void:
	_offers = offers.duplicate(true)
	_rebuild_upgrade_data()
	_update_header(components)
	_update_action_buttons(components)


func refresh_display(components: int) -> void:
	_update_header(components)
	_update_action_buttons(components)
	for slot in _upgrade_slots:
		slot._refresh_display()


func enter_craft_mode() -> void:
	if _craft_mode:
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


func mark_upgrade_purchased(slot_index: int) -> void:
	var row: Array = _offers.get("upgrades", [])
	if slot_index < 0 or slot_index >= row.size():
		return
	row[slot_index]["purchased"] = true
	if slot_index < _upgrade_slots.size():
		_upgrade_slots[slot_index].mark_purchased()


func _build_upgrade_row() -> void:
	_clear_upgrade_row()
	var row_data: Array = _offers.get("upgrades", [])
	for i in row_data.size():
		var slot: ShopSlot = SHOP_SLOT_SCENE.instantiate()
		_upgrade_row.add_child(slot)
		slot.configure(row_data[i])
		slot.slot_pressed.connect(_on_upgrade_slot_pressed.bind(i))
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


func _on_upgrade_slot_pressed(slot_index: int, slot_data: Dictionary) -> void:
	if _craft_mode:
		return
	upgrade_requested.emit(slot_data, slot_index)


func _on_repair_pressed() -> void:
	if _craft_mode:
		return
	repair_requested.emit()


func _on_craft_pressed() -> void:
	if _craft_mode:
		return
	enter_craft_mode()


func _on_refresh_pressed() -> void:
	if _craft_mode:
		return
	refresh_requested.emit()


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
	if show_panel and visible and not _craft_mode:
		if _passthrough_helper:
			_passthrough_helper.block_input()
	elif _passthrough_helper:
		_passthrough_helper.unblock_input()


func _set_rest_controls_enabled(enabled: bool) -> void:
	_repair_button.disabled = not enabled
	_craft_button.disabled = not enabled
	_refresh_button.disabled = not enabled
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
	_repair_button.disabled = _craft_mode or not has_actions or components < repair_cost
	_craft_button.disabled = _craft_mode or not has_actions or components < craft_cost
	_refresh_button.disabled = _craft_mode or components < refresh_cost
	for slot in _upgrade_slots:
		if slot.slot_data.get("purchased", false):
			slot.disabled = true
			continue
		slot.disabled = _craft_mode or not has_actions or components < slot.get_effective_price()
