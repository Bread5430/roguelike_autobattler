extends Base_Unit

@export var flat_damage_reduction = 2

## Code is mostly the same, but bruiser takes less flat damage from all attacks
func take_damage(damage: int, apply_taken_mult: bool = true) -> void:
	var amt := float(damage)
	if apply_taken_mult:
		amt *= dmg_taken_mult
	curr_hp -= int(amt) - flat_damage_reduction

	if curr_hp <= 0:
		state_machine.set_state(state_machine.states.dead)
