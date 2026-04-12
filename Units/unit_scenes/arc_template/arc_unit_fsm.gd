extends FSM

var arc_attack: Attack_Base

func _ready():
	super()
	arc_attack = parent.get_node("Arc_Attack")

func _init() -> void:
	super()
	_add_state("march")
	_add_state("attack")
	_add_state("dead")

	start_state = states.march


func _state_logic(_delta: float) -> void:
	match state:
		states.march:
			arc_attack.check_new_targets()
			parent.move_vec = target_movement.get_flow_field()

		states.attack:
			arc_attack.check_new_targets()
			if arc_attack.check_can_attack():
				arc_attack.do_attack()
			parent.move_vec = Vector2.ZERO

	parent.movement()


func _get_transition() -> int:
	match state:
		states.march:
			if arc_attack.in_range():
				set_state(states.attack)

		states.attack:
			if not arc_attack.in_range():
				set_state(states.march)
	return super()


func _enter_state(_previous_state: int, new_state: int) -> void:
	match new_state:
		states.march:
			sprite.play("walk")

		states.dead:
			sprite.play("die")
			animation_player.play("dead")
