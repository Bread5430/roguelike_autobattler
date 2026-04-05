extends StatusEffectDef
class_name GroundSlowDef

## Multiplies movement speed (0.7 = 30% slow).
@export var move_speed_multiplier: float = 0.65


func _init() -> void:
	effect_id = &"ground_slow"
	display_name = "Slowed"
	default_duration = 0.25
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.DEBUFF


func get_move_speed_mult_for_stacks(stacks: int) -> float:
	if stacks <= 0:
		return 1.0
	return pow(move_speed_multiplier, stacks)
