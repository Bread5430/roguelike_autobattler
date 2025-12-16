extends Control

var level = "res://Environment/world.tscn"


func _on_play_click_fin():
	get_tree().change_scene_to_file(level)


func _on_exit_click_fin():
	get_tree().quit()
