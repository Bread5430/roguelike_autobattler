extends Control
class_name BattleRewardsUI

signal rewards_closed
signal instant_gold_claimed(amount: int)
signal unit_picked(item_id: String)

@onready var _backdrop: ColorRect = $Backdrop
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _victory_label: Label = $MainPanel/Margin/VBox/VictoryLabel
@onready var _repair_damage_label: Label = $MainPanel/Margin/VBox/RepairDamageLabel
@onready var _reward_list: VBoxContainer = $MainPanel/Margin/VBox/RewardList
@onready var _close_button: Button = $MainPanel/Margin/VBox/CloseButton
@onready var _submenu_overlay: Control = $SubmenuOverlay
@onready var _submenu_backdrop: ColorRect = $SubmenuOverlay/SubmenuBackdrop
@onready var _unit_options: VBoxContainer = $SubmenuOverlay/SubmenuPanel/Margin/VBox/UnitOptions
@onready var _submenu_close_button: Button = $SubmenuOverlay/SubmenuPanel/Margin/VBox/SubmenuCloseButton

var _payload: Dictionary = {}
var _reward_buttons: Dictionary = {} # entry id -> Button
var _active_unit_choice_entry: Dictionary = {}
var _passthrough_helper: Node
var _health_manager: PlayerHealthManager


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_submenu_overlay.visible = false
	_submenu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_submenu_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_submenu_overlay.get_node("SubmenuPanel").mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_submenu_backdrop.gui_input.connect(_on_backdrop_gui_input)
	_close_button.pressed.connect(_on_close_pressed)
	_submenu_close_button.pressed.connect(_on_submenu_close_pressed)


func setup(health_manager: PlayerHealthManager, passthrough_helper: Node) -> void:
	_health_manager = health_manager
	_passthrough_helper = passthrough_helper


func open(payload: Dictionary) -> void:
	_payload = payload.duplicate(true)
	_clear_reward_list()
	_clear_unit_options()
	_hide_submenu()
	_refresh_header()
	_build_reward_buttons()
	visible = true
	_passthrough_helper.block_input()
	await rewards_closed


func close() -> void:
	_hide_submenu()
	visible = false
	_passthrough_helper.unblock_input()
	rewards_closed.emit()


func _refresh_header() -> void:
	_victory_label.text = "Victory!"
	var repair_damage := 0
	if _health_manager:
		repair_damage = _health_manager.get_repair_damage_taken_this_battle()
	_repair_damage_label.text = "Repair damage: %d" % repair_damage


func _build_reward_buttons() -> void:
	var entries: Array = _payload.get("entries", [])
	for entry in entries:
		if not entry is Dictionary:
			continue
		var entry_dict: Dictionary = entry
		if entry_dict.get("claimed", false):
			continue
		var btn := Button.new()
		btn.text = str(entry_dict.get("label", "Reward"))
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var entry_id: String = str(entry_dict.get("id", ""))
		btn.pressed.connect(_on_reward_button_pressed.bind(entry_dict, btn))
		_reward_list.add_child(btn)
		_reward_buttons[entry_id] = btn


func _on_reward_button_pressed(entry: Dictionary, btn: Button) -> void:
	var kind: String = str(entry.get("kind", ""))
	match kind:
		"instant":
			_claim_instant_reward(entry, btn)
		"unit_choice":
			_open_unit_choice_submenu(entry)
		_:
			push_warning("BattleRewardsUI: unknown reward kind '%s'" % kind)


func _claim_instant_reward(entry: Dictionary, btn: Button) -> void:
	if entry.get("claimed", false):
		return
	var gold_amount := int(entry.get("gold", 0))
	if gold_amount > 0:
		instant_gold_claimed.emit(gold_amount)
	entry["claimed"] = true
	btn.disabled = true
	btn.text = "%s (claimed)" % str(entry.get("label", "Reward"))


func _open_unit_choice_submenu(entry: Dictionary) -> void:
	if entry.get("claimed", false):
		return
	_active_unit_choice_entry = entry
	_clear_unit_options()
	var options: Array = entry.get("options", [])
	for option in options:
		var item_id := str(option)
		var btn := Button.new()
		btn.text = _display_name_for_item(item_id)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_unit_option_pressed.bind(item_id))
		_unit_options.add_child(btn)
	_submenu_overlay.visible = true


func _on_unit_option_pressed(item_id: String) -> void:
	if _active_unit_choice_entry.is_empty():
		return
	unit_picked.emit(item_id)
	_active_unit_choice_entry["claimed"] = true
	var entry_id: String = str(_active_unit_choice_entry.get("id", ""))
	if _reward_buttons.has(entry_id):
		var btn: Button = _reward_buttons[entry_id]
		btn.disabled = true
		btn.text = "%s (claimed)" % str(_active_unit_choice_entry.get("label", "Reward"))
	_active_unit_choice_entry = {}
	_hide_submenu()


func _display_name_for_item(item_id: String) -> String:
	var scene: PackedScene = ITEM_NAME.item_lookup(item_id)
	if scene == null:
		return item_id
	var inst = scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if inst is Unit_Card:
		var payload := ItemDetailsBuilder.new().build_payload(inst as Unit_Card, item_id)
		inst.queue_free()
		return str(payload.get("display_name", item_id))
	if inst and "unit_glossary_id" in inst:
		var glossary_id: String = str(inst.unit_glossary_id)
		if UNIT_GLOSSARY.has_entry(glossary_id):
			var entry := UNIT_GLOSSARY.get_entry(glossary_id)
			inst.queue_free()
			return str(entry.get("display_name", item_id))
	if inst and "item_name" in inst:
		var name := str(inst.item_name)
		inst.queue_free()
		return name
	if inst:
		inst.queue_free()
	return item_id


func _hide_submenu() -> void:
	_submenu_overlay.visible = false
	_active_unit_choice_entry = {}


func _on_submenu_close_pressed() -> void:
	_hide_submenu()


func _on_close_pressed() -> void:
	close()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			accept_event()


func _clear_reward_list() -> void:
	_reward_buttons.clear()
	for child in _reward_list.get_children():
		child.queue_free()


func _clear_unit_options() -> void:
	for child in _unit_options.get_children():
		child.queue_free()
