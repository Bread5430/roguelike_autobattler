extends Control

@onready var _master_slider: HSlider = $Margin/VBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $Margin/VBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Margin/VBox/SfxRow/SfxSlider


func _ready() -> void:
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	refresh_from_settings()


func refresh_from_settings() -> void:
	_master_slider.value = SettingsManager.master_volume
	_music_slider.value = SettingsManager.music_volume
	_sfx_slider.value = SettingsManager.sfx_volume


func _on_master_changed(value: float) -> void:
	SettingsManager.set_master_volume(value)


func _on_music_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)


func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value)
