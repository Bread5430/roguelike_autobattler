extends FSM

var _attacks: Array[Attack_Base] = []


func _init() -> void:
	super() # Get the waiting state
	_add_state("march")
	_add_state("attack")
	_add_state("beaconed")
	_add_state("dead")
	
	start_state = states.march

func _ready() -> void:
	super()
	_attacks = [
		parent.get_node("Laser_Turret") as Attack_Base,
		parent.get_node("Cannon_Turret") as Attack_Base,
	]

func _state_logic(_delta: float) -> void:
	match state:
		states.march:
			for atk in _attacks:
				atk.check_new_targets()
			parent.move_vec = target_movement.get_flow_field()

		states.attack:
			for atk in _attacks:
				atk.check_new_targets()
				if atk.check_can_attack():
					atk.do_attack()
			parent.move_vec = Vector2.ZERO

		states.beaconed:
			for atk in _attacks:
				atk.check_new_targets()
				if atk.check_can_attack():
						atk.do_attack()
			parent.move_vec = beacon_move_vec
			
	parent.movement()


func _get_transition() -> int:
	match state:
		states.march:
			for atk in _attacks:
				if atk.in_range():
					set_state(states.attack)
					break
		
		states.attack:
			var any_in_range = false
			for atk in _attacks:
				if atk.in_range():
					any_in_range = true
					break
			if not any_in_range:
				set_state(states.march)

	return super()
