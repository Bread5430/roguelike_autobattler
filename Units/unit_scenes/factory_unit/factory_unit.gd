extends Base_Unit
class_name FactoryUnit

@export var is_factory: bool = true

var initial_health_fraction: float = 1.0
var player_health_manager: PlayerHealthManager


# Post Ready assumes that the instance has already been reparented to the Unit Parent
func post_ready():
	# Find all the attack nodes that use 
	var parent_proj_pool = get_parent().get_parent().proj_pool
	for node in get_children():
		if node is Attack_Base and node.has_method("set_proj_pool"):
			node.set_proj_pool(parent_proj_pool)
			
	super()


func _ready() -> void:
	super._ready()
	curr_hp = int(max_hp * clampf(initial_health_fraction, 0.0, 1.0))
	if curr_hp <= 0:
		state_machine.set_state(state_machine.states.dead)


func take_damage(damage: int, apply_taken_mult: bool = true) -> void:
	var before := curr_hp
	super.take_damage(damage, apply_taken_mult)
	var lost := before - curr_hp
	if lost > 0 and player_health_manager != null:
		player_health_manager.apply_damage(lost)
