extends HBoxContainer

signal rebind_requested(action: String)

var _action: String = ""

@onready var _name_label: Label = $NameLabel
@onready var _binding_label: Label = $BindingLabel
@onready var _rebind_button: Button = $RebindButton


func setup(action: String, display_name: String, binding_label: String) -> void:
	_action = action
	_name_label.text = display_name
	_binding_label.text = binding_label
	_rebind_button.pressed.connect(_on_rebind_pressed)


func _on_rebind_pressed() -> void:
	rebind_requested.emit(_action)
