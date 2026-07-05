extends Control

const MAIN_MENU_SCENE := "res://UI/Menus/MainMenu.tscn"
const RUN_SCENE := "res://Manager/game_state_manager.tscn"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_start_game_pressed() -> void:
	SaveManager.pending_new_run = true
	get_tree().change_scene_to_file(RUN_SCENE)
