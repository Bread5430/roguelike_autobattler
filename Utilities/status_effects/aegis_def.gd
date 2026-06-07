extends StatusEffectDef
class_name AegisDef


func _init() -> void:
	effect_id = &"aegis"
	display_name = "Aegis"
	default_duration = 1.0
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.BUFF


func get_dmg_taken_mult_for_stacks(stacks: int) -> float:
	if stacks <= 0:
		return 1.0
	return 0.0
