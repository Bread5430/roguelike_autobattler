extends Control

const ROW_SCENE := preload("res://UI/Menus/Options/controls_binding_row.tscn")

@onready var _bindings_list: VBoxContainer = $Margin/VBox/Scroll/BindingList
@onready var _prompt_label: Label = $Margin/VBox/PromptLabel

var _listening_action: String = ""


func _ready() -> void:
	set_process_input(true)
	_prompt_label.visible = false
	_rebuild_rows()


func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			SettingsManager.rebind_action(_listening_action, event)
			_listening_action = ""
			_prompt_label.visible = false
			_rebuild_rows()
			get_viewport().set_input_as_handled()


func _rebuild_rows() -> void:
	for child in _bindings_list.get_children():
		child.queue_free()
	for action in SettingsManager.REBINDABLE_ACTIONS:
		var row := ROW_SCENE.instantiate()
		_bindings_list.add_child(row)
		row.setup(action, SettingsManager.get_action_display_name(action), SettingsManager.get_action_binding_label(action))
		row.rebind_requested.connect(_on_rebind_requested)


func _on_rebind_requested(action: String) -> void:
	_listening_action = action
	_prompt_label.text = "Press a key or mouse button for %s..." % SettingsManager.get_action_display_name(action)
	_prompt_label.visible = true
