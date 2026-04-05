extends StatusEffectDef
class_name StunnedDef


func _init() -> void:
	effect_id = &"stunned"
	display_name = "Stunned"
	default_duration = 2.0
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.DEBUFF


func get_move_speed_mult_for_stacks(stacks: int) -> float:
	if stacks <= 0:
		return 1.0
	return 0.0


func restricts_movement() -> bool:
	return true


func restricts_basic_attacks() -> bool:
	return true


func restricts_special_abilities() -> bool:
	return true
