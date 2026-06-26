extends Control
class_name RandomEventUI

signal choice_selected(choice_id: String)

@onready var _backdrop: ColorRect = $Backdrop
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _title_label: Label = $MainPanel/Margin/HBox/RightColumn/TitleLabel
@onready var _flavor_label: Label = $MainPanel/Margin/HBox/RightColumn/FlavorLabel
@onready var _event_image: TextureRect = $MainPanel/Margin/HBox/EventImage
@onready var _choice_list: VBoxContainer = $MainPanel/Margin/HBox/RightColumn/ChoiceList

var _payload: Dictionary = {}
var _panel_visible := true
var _passthrough_helper: Node


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)


func setup(passthrough_helper: Node) -> void:
	_passthrough_helper = passthrough_helper


func open(payload: Dictionary) -> void:
	_payload = payload.duplicate(true)
	_panel_visible = true
	_refresh_content()
	_set_panel_visible(true)
	visible = true


func close() -> void:
	_set_panel_visible(false)
	visible = false
	_clear_choices()


func is_panel_visible() -> bool:
	return _panel_visible and visible


func toggle_panel_visibility() -> void:
	if not visible:
		return
	_set_panel_visible(not _panel_visible)


func get_payload() -> Dictionary:
	return _payload.duplicate(true)


func set_payload(payload: Dictionary) -> void:
	_payload = payload.duplicate(true)
	_refresh_content()


func _refresh_content() -> void:
	var title := str(_payload.get("title", ""))
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_flavor_label.text = str(_payload.get("flavor_text", ""))
	var image_path := str(_payload.get("image_path", ""))
	if image_path.is_empty():
		_event_image.texture = null
	else:
		var tex: Texture2D = load(image_path)
		_event_image.texture = tex
	_build_choice_buttons()


func _build_choice_buttons() -> void:
	_clear_choices()
	for choice in _payload.get("choices", []):
		if not choice is Dictionary:
			continue
		var choice_dict: Dictionary = choice
		var btn := Button.new()
		btn.text = str(choice_dict.get("label", "Choose"))
		btn.disabled = not bool(choice_dict.get("enabled", true))
		var choice_id := str(choice_dict.get("choice_id", ""))
		btn.pressed.connect(_on_choice_pressed.bind(choice_id))
		_choice_list.add_child(btn)


func _clear_choices() -> void:
	for child in _choice_list.get_children():
		child.queue_free()


func _on_choice_pressed(choice_id: String) -> void:
	if choice_id.is_empty():
		return
	choice_selected.emit(choice_id)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			accept_event()


func _set_panel_visible(show_panel: bool) -> void:
	_panel_visible = show_panel
	_backdrop.visible = show_panel
	_main_panel.visible = show_panel
	if _passthrough_helper:
		_passthrough_helper.block_input()
