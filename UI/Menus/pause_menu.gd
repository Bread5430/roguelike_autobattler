extends Control

const GAME_SETUP_SCENE := "res://UI/Menus/GameSetup.tscn"

var _gsm: Node
var _gui: Control

@onready var _backdrop: ColorRect = $Backdrop
@onready var _main_panel: PanelContainer = $MainPanel
@onready var _options_menu: Control = $OptionsMenu
@onready var _resume_button: Button = $MainPanel/Margin/VBox/ResumeButton
@onready var _options_button: Button = $MainPanel/Margin/VBox/OptionsButton
@onready var _save_exit_button: Button = $MainPanel/Margin/VBox/SaveExitButton
@onready var _restart_button: Button = $MainPanel/Margin/VBox/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_children_process_mode(self)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_menu.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_save_exit_button.pressed.connect(_on_save_exit_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_options_menu.back_pressed.connect(_on_options_back)


func setup(gsm: Node, gui: Control = null) -> void:
	_gsm = gsm
	_gui = gui


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _gsm and _gsm.has_node("UICanvas/LossScreen"):
		var loss_screen: Control = _gsm.get_node("UICanvas/LossScreen")
		if loss_screen.visible:
			return
	if is_open():
		close()
		get_viewport().set_input_as_handled()
		return
	if _gui and _gui.has_method("should_block_pause_menu") and _gui.should_block_pause_menu():
		return
	open()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func open() -> void:
	_show_main_panel()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	_options_menu.visible = false
	get_tree().paused = false


func _show_main_panel() -> void:
	_main_panel.visible = true
	_options_menu.visible = false
	if _options_menu.has_method("show_hub_only"):
		_options_menu.show_hub_only()


func _on_resume_pressed() -> void:
	close()


func _on_options_pressed() -> void:
	_main_panel.visible = false
	_options_menu.visible = true
	if _options_menu.has_method("show_hub_only"):
		_options_menu.show_hub_only()


func _on_options_back() -> void:
	_show_main_panel()


func _on_save_exit_pressed() -> void:
	if _gsm and _gsm.has_method("save_and_exit_to_menu"):
		_gsm.save_and_exit_to_menu()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SETUP_SCENE)


func _set_children_process_mode(node: Node) -> void:
	for child in node.get_children():
		child.process_mode = Node.PROCESS_MODE_ALWAYS
		_set_children_process_mode(child)
