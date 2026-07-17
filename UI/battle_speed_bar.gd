extends Control
class_name BattleSpeedBar

## Battle-phase speed controls: soft pause / 1× / 2× / 4×. Syncs with BattleSpeedController.

var _controller: BattleSpeedController

@onready var _pause_btn: Button = $HBox/PauseButton
@onready var _speed_1_btn: Button = $HBox/Speed1Button
@onready var _speed_2_btn: Button = $HBox/Speed2Button
@onready var _speed_4_btn: Button = $HBox/Speed4Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var group: ButtonGroup = ButtonGroup.new()
	group.allow_unpress = false
	_pause_btn.button_group = group
	_speed_1_btn.button_group = group
	_speed_2_btn.button_group = group
	_speed_4_btn.button_group = group
	_pause_btn.pressed.connect(func(): _on_rate_pressed(0.0))
	_speed_1_btn.pressed.connect(func(): _on_rate_pressed(1.0))
	_speed_2_btn.pressed.connect(func(): _on_rate_pressed(2.0))
	_speed_4_btn.pressed.connect(func(): _on_rate_pressed(4.0))
	_update_pressed_state(1.0)


func setup(controller: BattleSpeedController) -> void:
	if _controller and _controller.combat_speed_changed.is_connected(_on_combat_speed_changed):
		_controller.combat_speed_changed.disconnect(_on_combat_speed_changed)
	_controller = controller
	if _controller:
		_controller.combat_speed_changed.connect(_on_combat_speed_changed)
		_update_pressed_state(_controller.combat_speed)


func show_bar() -> void:
	visible = true
	if _controller:
		_update_pressed_state(_controller.combat_speed)


func hide_bar() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _controller == null:
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("battle_speed_pause"):
		_controller.toggle_soft_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_speed_slower"):
		_controller.step_slower()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_speed_faster"):
		_controller.step_faster()
		get_viewport().set_input_as_handled()


func _on_rate_pressed(rate: float) -> void:
	if _controller:
		_controller.set_combat_speed(rate)


func _on_combat_speed_changed(rate: float) -> void:
	_update_pressed_state(rate)


func _update_pressed_state(rate: float) -> void:
	_pause_btn.set_pressed_no_signal(rate <= 0.0)
	_speed_1_btn.set_pressed_no_signal(rate > 0.0 and rate < 2.0)
	_speed_2_btn.set_pressed_no_signal(rate >= 2.0 and rate < 4.0)
	_speed_4_btn.set_pressed_no_signal(rate >= 4.0)
