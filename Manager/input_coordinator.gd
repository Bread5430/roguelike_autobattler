# Dedicated child of GameStateManager. Receives unhandled input for the game area
# and delegates to GUI (placement) or BattleManager (unit selection).
extends Node

var _gsm: Node
var _gui: Control
var _battle_manager: Control


func _ready():
	_gsm = get_parent()
	_gui = _gsm.get_node_or_null("UICanvas/Gui")
	_battle_manager = _gsm.get_node_or_null("BattleManager")
	if not _gui:
		push_error("InputCoordinator: GUI not found.")
	if not _battle_manager:
		push_error("InputCoordinator: BattleManager not found.")


func _unhandled_input(event: InputEvent):
	# Only delegate mouse clicks in the game area; leave other input (e.g. R for rotate) to others.
	# Ensure that event is a mouse pressed event
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# Skip if over UI so those controls keep receiving _gui_input.
	# TODO: validate if is mouse over pipeline is necesary
	if _gui and _gui.has_method("is_mouse_over_ui_element") and _gui.is_mouse_over_ui_element(mouse_pos):
		return

	# Require game state to delegate (parent is GameStateManager with current_state and GameState enum).
	var state = _gsm.current_state if "current_state" in _gsm else null
	if state == null:
		return

	match state:
		_gsm.GameState.BATTLE_PREPARATION:
			if _gui and _gui.has_method("handle_game_area_click"):
				_gui.handle_game_area_click(event)
		_gsm.GameState.BATTLE_ACTIVE:
			if _battle_manager and _battle_manager.has_method("handle_unit_click"):
				_battle_manager.handle_unit_click(event)

	get_viewport().set_input_as_handled()
