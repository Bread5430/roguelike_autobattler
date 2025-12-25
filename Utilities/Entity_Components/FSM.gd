extends Node
class_name FSM

var states: Dictionary = {}
var previous_state: int = -1
var state: int = -1: set = set_state
var post_ready_check = false
var round_start_check = false
var start_state = null

@onready var parent: Base_Unit = get_parent()
@onready var sprite: AnimatedSprite2D = parent.get_node("AnimatedSprite2D")
@onready var animation_player: AnimationPlayer = parent.get_node("AnimationPlayer")
@onready var target_movement = parent.get_node("Target_Movement")

func _init():
	_add_state("wait_ready")

func _ready():
	set_state(states.wait_ready)

func post_ready():
	post_ready_check = true

func _physics_process(delta: float) -> void:
	if state != -1:
		_state_logic(delta)
		var transition: int = _get_transition()
		if transition != -1:
			set_state(transition)


func _state_logic(_delta: float) -> void:
	pass


func _get_transition() -> int:
	if state == states.wait_ready:
		# Ensure that the round has started, and that this node is ready
		if round_start_check == true and post_ready_check == true:
			if start_state != null:
				return start_state
			 
	return -1


func _add_state(new_state: String) -> void:
	states[new_state] = states.size()


func set_state(new_state: int) -> void:
	_exit_state(state)
	previous_state = state
	state = new_state
	_enter_state(previous_state, state)


func _enter_state(_previous_state: int, _new_state: int) -> void:
	pass


func _exit_state(_state_exited: int) -> void:
	pass
