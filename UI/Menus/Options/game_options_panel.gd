extends Control

@onready var _particles_toggle: CheckButton = $Margin/VBox/ParticlesToggle
@onready var _camera_speed_slider: HSlider = $Margin/VBox/CameraSpeedRow/CameraSpeedSlider
@onready var _camera_speed_label: Label = $Margin/VBox/CameraSpeedRow/CameraSpeedValue


func _ready() -> void:
	_particles_toggle.toggled.connect(_on_particles_toggled)
	_camera_speed_slider.value_changed.connect(_on_camera_speed_changed)
	refresh_from_settings()


func refresh_from_settings() -> void:
	_particles_toggle.button_pressed = SettingsManager.particles_enabled
	_camera_speed_slider.value = SettingsManager.camera_pan_speed
	_camera_speed_label.text = str(SettingsManager.camera_pan_speed)


func _on_particles_toggled(enabled: bool) -> void:
	SettingsManager.set_particles_enabled(enabled)


func _on_camera_speed_changed(value: float) -> void:
	var speed := int(value)
	_camera_speed_label.text = str(speed)
	SettingsManager.set_camera_pan_speed(speed)
