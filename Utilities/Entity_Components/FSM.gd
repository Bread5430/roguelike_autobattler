extends Node
class_name FSM

var states: Dictionary = {}
var previous_state: int = -1
var state: int = -1: set = set_state
var post_ready_check = false
var round_start_check = false
var start_state = null
var beacon_move_vec: Vector2 = Vector2.ZERO

## Animation names played per state. Swapped on upgrade via [method set_animation_names]
## (see [method Base_Unit._apply_upgrade_animations]). Empty [member attack_animation] means no attack anim.
var run_animation : String = "walk"
var die_animation : String = "die"
var attack_animation : String = ""

@onready var parent: Base_Unit = get_parent()
@onready var sprite: AnimatedSprite2D = parent.get_node("AnimatedSprite2D")
@onready var animation_player: AnimationPlayer = parent.get_node("AnimationPlayer")
@onready var target_movement = parent.get_node("Target_Movement")

func _init():
	_add_state("wait_ready")

func _ready():
	set_state(states.wait_ready)
	if parent and parent.has_signal("beacon_status_changed"):
		parent.beacon_status_changed.connect(_on_beacon_status_changed)

func post_ready():
	post_ready_check = true

func _physics_process(delta: float) -> void:
	if state != -1:
		_refresh_shared_tick_cache()
		_state_logic(delta)
		var transition: int = _get_transition()
		if transition != -1:
			set_state(transition)


func _refresh_shared_tick_cache() -> void:
	beacon_move_vec = Vector2.ZERO
	if target_movement and target_movement.has_method("begin_physics_tick"):
		target_movement.begin_physics_tick()
		beacon_move_vec = target_movement.get_cached_beacon_move_vec()

func _state_logic(_delta: float) -> void:
	pass


func _get_transition() -> int:
	if state == states.wait_ready:
		# Ensure that the round has started, and that this node is ready
		if round_start_check == true and post_ready_check == true:
			if start_state != null:
				return start_state
	elif state == states.beaconed: # End beacon when out of path to follow
		if beacon_move_vec == Vector2.ZERO:
			_on_beacon_status_changed(false)
	return -1


func _add_state(new_state: String) -> void:
	states[new_state] = states.size()


## Overrides the animation names this FSM plays for movement/death/attack states.
## Empty names are ignored so callers can update only the animations they have art for.
func set_animation_names(run_name: String, die_name: String, attack_name: String = "") -> void:
	if run_name != "":
		run_animation = run_name
	if die_name != "":
		die_animation = die_name
	if attack_name != "":
		attack_animation = attack_name


func set_state(new_state: int) -> void:
	_exit_state(state)
	previous_state = state
	state = new_state
	if states.has("dead") and new_state == states.dead:
		parent.move_vec = Vector2.ZERO
		parent.velocity = Vector2.ZERO
		parent.disable_physics_collision()
	_enter_state(previous_state, state)


func _enter_state(_previous_state: int, _new_state: int) -> void:
	pass


func _exit_state(_state_exited: int) -> void:
	pass


func _on_beacon_status_changed(active: bool) -> void:
	if active and states.has("beaconed"):
		set_state(states.beaconed)
	elif !active and states.has("march"):
		set_state(states.march)
