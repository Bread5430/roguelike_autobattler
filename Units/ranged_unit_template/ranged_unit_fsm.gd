extends FSM

var ranged_attack : Attack_Base

func _ready():
	super()
	ranged_attack = parent.get_node("Ranged_Attack")

func _init() -> void:
	super() # Get the waiting state
	_add_state("march")
	_add_state("attack")
	_add_state("dead")
	
	start_state = states.march
	
	
func _state_logic(_delta: float) -> void:
	match state:
		states.march:
			ranged_attack.check_new_targets()
			parent.move_vec = target_movement.get_flow_field()

		states.attack:
			if ranged_attack.check_can_attack():
				ranged_attack.do_attack()
			parent.move_vec = Vector2.ZERO
			
	parent.movement()


func _get_transition() -> int:
	match state:
		states.march:
			if ranged_attack.in_range():
				set_state(states.attack)
		
		states.attack:
			if not ranged_attack.in_range():
				set_state(states.march)
	return super()
	
	
func _enter_state(_previous_state: int, new_state: int) -> void:
	match new_state:
		states.march:
			sprite.play("walk")

		states.dead:
			sprite.play("die")
			animation_player.play("dead")
