extends Control

var level = "res://Environment/world.tscn"

func _ready() -> void:
	$CenterContainer/SettingsMenu/Fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$CenterContainer/SettingsMenu/SFXVolume.value = db_to_linear(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX"))) 
	$CenterContainer/SettingsMenu/MusicVolume.value = db_to_linear(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music"))) 
	$CenterContainer/SettingsMenu/MainVolume.value = db_to_linear(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Master"))) 


func _on_exit_button_down() -> void:
	get_tree().quit()


func _on_play_button_down() -> void:
	get_tree().change_scene_to_file(level)


func _on_settings_button_down() -> void:
	$CenterContainer/PrimaryMenu.hidden = true
	$CenterContainer/SettingsMenu.hidden = false


func _on_back_button_down() -> void:
	$CenterContainer/PrimaryMenu.hidden = false
	$CenterContainer/SettingsMenu.hidden = true


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)



func _on_main_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)


func _on_music_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)


func _on_sfx_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)
