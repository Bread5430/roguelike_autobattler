extends Control
class_name ShopUI

signal purchase_requested(slot_data: Dictionary, row_key: String, slot_index: int)
signal refresh_requested
signal scrap_mode_entered
signal scrap_mode_exited
signal leave_requested

const SHOP_SLOT_SCENE := preload("res://UI/ShopSlot.tscn")
const REFRESH_COST := 50

@onready var _backdrop: ColorRect = $Backdrop
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _gold_label: Label = $MainPanel/Margin/VBox/HeaderRow/GoldLabel
@onready var _components_label: Label = $MainPanel/Margin/VBox/HeaderRow/ComponentsLabel
@onready var _unit_row: HBoxContainer = $MainPanel/Margin/VBox/UnitRow
@onready var _spell_row: HBoxContainer = $MainPanel/Margin/VBox/SpellRow
@onready var _relic_row: HBoxContainer = $MainPanel/Margin/VBox/RelicRow
@onready var _refresh_button: Button = $MainPanel/Margin/VBox/FooterRow/RefreshButton
@onready var _leave_button: Button = $MainPanel/Margin/VBox/FooterRow/LeaveButton
@onready var _scraper_button: Button = $MainPanel/Margin/VBox/FooterRow/ScraperButton
@onready var _scrap_overlay: Control = $ScrapOverlay
@onready var _scrap_backdrop: ColorRect = $ScrapOverlay/ScrapBackdrop
@onready var _scrap_return_button: Button = $ScrapOverlay/ScrapPanel/Margin/VBox/ReturnButton

var _stock: Dictionary = {}
var _unit_slots: Array[ShopSlot] = []
var _spell_slots: Array[ShopSlot] = []
var _relic_slots: Array[ShopSlot] = []
var _refresh_used := false
var _panel_visible := true
var _scrap_mode := false
var _passthrough_helper: Node


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrap_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrap_overlay.get_node("ScrapPanel").mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_scrap_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_scraper_button.pressed.connect(_on_scraper_pressed)
	_scrap_return_button.pressed.connect(_on_scrap_return_pressed)


func setup(passthrough_helper: Node) -> void:
	_passthrough_helper = passthrough_helper


func open(stock: Dictionary, gold: int, components: int) -> void:
	_stock = stock.duplicate(true)
	_refresh_used = false
	_panel_visible = true
	_scrap_mode = false
	_scrap_overlay.visible = false
	_set_scrap_pass_through(false)
	_build_slot_rows()
	_update_currency_labels(gold, components)
	_update_refresh_button(gold)
	_set_panel_visible(true)
	visible = true


func close() -> void:
	if _scrap_mode:
		exit_scrap_mode()
	_set_panel_visible(false)
	visible = false
	_clear_slot_rows()


func is_panel_visible() -> bool:
	return _panel_visible and visible


func toggle_panel_visibility() -> void:
	if not visible or _scrap_mode:
		return
	_set_panel_visible(not _panel_visible)


func set_stock(stock: Dictionary, gold: int) -> void:
	_stock = stock.duplicate(true)
	_rebuild_slot_data()
	_update_currency_labels(gold, _get_components_from_label())
	_update_refresh_button(gold)


func refresh_currency(gold: int, components: int) -> void:
	_update_currency_labels(gold, components)
	_update_refresh_button(gold)
	for slot in _all_slots():
		slot._refresh_display()


func enter_scrap_mode() -> void:
	if _scrap_mode:
		return
	_scrap_mode = true
	_scrap_overlay.visible = true
	# Inventory is brought to the front for item clicks; keep shop chrome
	# pass-through so only the scrap return panel captures mouse.
	_set_scrap_pass_through(true)
	_set_shop_controls_enabled(false)
	scrap_mode_entered.emit()


func exit_scrap_mode() -> void:
	if not _scrap_mode:
		return
	_scrap_mode = false
	_scrap_overlay.visible = false
	_set_scrap_pass_through(false)
	_set_shop_controls_enabled(true)
	scrap_mode_exited.emit()


func mark_slot_sold(row_key: String, slot_index: int) -> void:
	var slots := _slots_for_row(row_key)
	if slot_index < 0 or slot_index >= slots.size():
		return
	slots[slot_index].mark_sold()
	var row: Array = _stock.get(row_key, [])
	if slot_index < row.size():
		row[slot_index]["sold"] = true


func _build_slot_rows() -> void:
	_clear_slot_rows()
	_unit_slots = _populate_row(_unit_row, _stock.get("units", []), "units")
	_spell_slots = _populate_row(_spell_row, _stock.get("spells", []), "spells")
	_relic_slots = _populate_row(_relic_row, _stock.get("relics", []), "relics")


func _populate_row(container: HBoxContainer, row_data: Array, row_key: String) -> Array[ShopSlot]:
	var slots: Array[ShopSlot] = []
	for i in row_data.size():
		var slot: ShopSlot = SHOP_SLOT_SCENE.instantiate()
		container.add_child(slot)
		slot.configure(row_data[i])
		slot.slot_pressed.connect(_on_slot_pressed.bind(row_key, i))
		slots.append(slot)
	return slots


func _rebuild_slot_data() -> void:
	_apply_row_data(_unit_slots, _stock.get("units", []))
	_apply_row_data(_spell_slots, _stock.get("spells", []))
	_apply_row_data(_relic_slots, _stock.get("relics", []))


func _apply_row_data(slots: Array[ShopSlot], row_data: Array) -> void:
	for i in mini(slots.size(), row_data.size()):
		if row_data[i].get("sold", false):
			slots[i].configure(row_data[i])
		else:
			slots[i].reroll(row_data[i])


func _clear_slot_rows() -> void:
	for container in [_unit_row, _spell_row, _relic_row]:
		for child in container.get_children():
			child.queue_free()
	_unit_slots.clear()
	_spell_slots.clear()
	_relic_slots.clear()


# NOTE: bound args (row_key, slot_index) are appended AFTER the signal's emitted
# slot_data, so the emitted arg must be the first parameter here.
func _on_slot_pressed(slot_data: Dictionary, row_key: String, slot_index: int) -> void:
	if _scrap_mode:
		return
	purchase_requested.emit(slot_data, row_key, slot_index)


func _on_refresh_pressed() -> void:
	if _scrap_mode or _refresh_used:
		return
	refresh_requested.emit()


func _on_leave_pressed() -> void:
	if _scrap_mode:
		return
	leave_requested.emit()


func _on_scraper_pressed() -> void:
	if _scrap_mode:
		return
	enter_scrap_mode()


func _on_scrap_return_pressed() -> void:
	exit_scrap_mode()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			accept_event()


func _set_panel_visible(show_panel: bool) -> void:
	_panel_visible = show_panel
	_backdrop.visible = show_panel
	_main_panel.visible = show_panel
	if show_panel and visible and not _scrap_mode:
		if _passthrough_helper:
			_passthrough_helper.block_input()
	elif _passthrough_helper:
		_passthrough_helper.unblock_input()


func _set_scrap_pass_through(enabled: bool) -> void:
	# While scrapping, inventory sits above most of the shop. Ignore mouse on
	# the shop chrome so inventory stays clickable, but keep ScrapPanel STOP
	# so "Leave Scraper" remains reachable even when overlapping the grid.
	var filter = Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
	mouse_filter = filter
	_backdrop.mouse_filter = filter
	_main_panel.mouse_filter = filter
	_scrap_overlay.mouse_filter = filter
	_scrap_backdrop.mouse_filter = filter
	_scrap_overlay.get_node("ScrapPanel").mouse_filter = Control.MOUSE_FILTER_STOP
	_scrap_return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if enabled:
		move_to_front()
		_scrap_overlay.move_to_front()


func _set_shop_controls_enabled(enabled: bool) -> void:
	_refresh_button.disabled = not enabled or _refresh_used
	_leave_button.disabled = not enabled
	_scraper_button.disabled = not enabled
	for slot in _all_slots():
		slot.disabled = not enabled or slot.slot_data.get("sold", false) or str(slot.slot_data.get("kind", "")) == "relic"


func _update_currency_labels(gold: int, components: int) -> void:
	_gold_label.text = "Gold: %d" % gold
	_components_label.text = "Components: %d" % components


func _update_refresh_button(gold: int) -> void:
	_refresh_button.text = "Refresh shop (%dg)" % REFRESH_COST
	_refresh_button.disabled = _refresh_used or _scrap_mode or gold < REFRESH_COST


func mark_refresh_used(gold: int) -> void:
	_refresh_used = true
	_update_refresh_button(gold)


func get_stock() -> Dictionary:
	return _stock.duplicate(true)


func _slots_for_row(row_key: String) -> Array[ShopSlot]:
	match row_key:
		"units":
			return _unit_slots
		"spells":
			return _spell_slots
		"relics":
			return _relic_slots
	return []


func _all_slots() -> Array[ShopSlot]:
	var all: Array[ShopSlot] = []
	all.append_array(_unit_slots)
	all.append_array(_spell_slots)
	all.append_array(_relic_slots)
	return all


func _get_components_from_label() -> int:
	var text := _components_label.text
	var parts := text.split(": ")
	if parts.size() >= 2:
		return int(parts[1])
	return 0
