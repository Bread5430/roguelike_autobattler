extends FSM

var melee_atk : Attack_Base

func _ready():
	super()
	melee_atk = parent.get_node("Melee_Attack")

func _init() -> void:
	super() # Get the waiting state
	_add_state("march")
	_add_state("local_march")
	_add_state("attack")
	_add_state("dead")
	
	start_state = states.march

	
func _state_logic(_delta: float) -> void:
	match state:
		states.march:
			melee_atk.check_new_targets()
			parent.move_vec = target_movement.get_flow_field()
		states.local_march:
			melee_atk.check_new_targets()
			parent.move_vec = target_movement.get_dir_target()
		states.attack:
			if melee_atk.check_can_attack():
				melee_atk.do_attack()
			parent.move_vec = Vector2.ZERO
			
	parent.movement()

func _get_transition() -> int:
	match state:
		states.march:
			if melee_atk.in_range():
				set_state(states.attack)
			if target_movement.in_same_tile():
				set_state(states.local_march)
		
		states.local_march:
			if melee_atk.in_range():
				set_state(states.attack)
			else:
				set_state(states.march)
		
		states.attack:
			if not melee_atk.in_range():
				set_state(states.local_march)
	return super()
	
	
func _enter_state(_previous_state: int, new_state: int) -> void:
	match new_state:
		states.march:
			sprite.play("walk")
			
		states.local_march:
			sprite.play("walk")

		states.dead:
			sprite.play("die")
			animation_player.play("dead")
