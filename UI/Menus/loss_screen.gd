extends Control

const GAME_SETUP_SCENE := "res://UI/Menus/GameSetup.tscn"

var _gsm: Node

@onready var _backdrop: ColorRect = $Backdrop
@onready var _try_again_button: Button = $MainPanel/Margin/VBox/TryAgainButton
@onready var _metaprogression_button: Button = $MainPanel/Margin/VBox/MetaprogressionButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_children_process_mode(self)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_try_again_button.pressed.connect(_on_try_again_pressed)
	_metaprogression_button.pressed.connect(_on_metaprogression_pressed)


func setup(gsm: Node) -> void:
	_gsm = gsm


func open() -> void:
	visible = true
	get_tree().paused = true


func _on_try_again_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SETUP_SCENE)


func _on_metaprogression_pressed() -> void:
	# TODO: metaprogression screen — unlocks and meta-currency upgrades.
	print("TODO: View Metaprogression")


func _set_children_process_mode(node: Node) -> void:
	for child in node.get_children():
		child.process_mode = Node.PROCESS_MODE_ALWAYS
		_set_children_process_mode(child)
