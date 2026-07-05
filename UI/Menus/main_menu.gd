extends Control

const GAME_SETUP_SCENE := "res://UI/Menus/GameSetup.tscn"
const RUN_SCENE := "res://Manager/game_state_manager.tscn"

@onready var _primary_menu: Control = $PrimaryMenu
@onready var _options_menu: Control = $OptionsMenu
@onready var _load_game_button: Button = $PrimaryMenu/Center/VBox/LoadGameButton
@onready var _no_save_label: Label = $PrimaryMenu/Center/VBox/NoSaveLabel


func _ready() -> void:
	_options_menu.visible = false
	_options_menu.back_pressed.connect(_on_options_back)
	_refresh_load_button()


func _refresh_load_button() -> void:
	var has_save := SaveManager.has_save()
	_load_game_button.disabled = not has_save
	_no_save_label.visible = not has_save


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SETUP_SCENE)


func _on_load_game_pressed() -> void:
	if not SaveManager.has_save():
		return
	SaveManager.pending_load = true
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_options_pressed() -> void:
	_primary_menu.visible = false
	_options_menu.visible = true
	_options_menu.show_hub_only()


func _on_options_back() -> void:
	_options_menu.visible = false
	_primary_menu.visible = true


func _on_exit_pressed() -> void:
	get_tree().quit()
