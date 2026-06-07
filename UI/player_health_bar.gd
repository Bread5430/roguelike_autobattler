extends PanelContainer

@onready var _bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var _label: Label = $MarginContainer/VBoxContainer/Label

var _health_manager: PlayerHealthManager


func setup(health_manager: PlayerHealthManager) -> void:
	if _health_manager != null and _health_manager.health_changed.is_connected(_on_health_changed):
		_health_manager.health_changed.disconnect(_on_health_changed)
	_health_manager = health_manager
	if _health_manager == null:
		return
	_health_manager.health_changed.connect(_on_health_changed)
	_on_health_changed(_health_manager.curr_health, _health_manager.max_health)
	visible = true


func _on_health_changed(curr: int, max_val: int) -> void:
	if max_val <= 0:
		_bar.max_value = 1.0
		_bar.value = 0.0
	else:
		_bar.max_value = float(max_val)
		_bar.value = float(curr)
	_label.text = "Factory Health: %d / %d" % [curr, max_val]
