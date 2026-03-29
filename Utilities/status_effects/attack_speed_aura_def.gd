extends StatusEffectDef
class_name AttackSpeedAuraDef

## Multiplies attack speed (reduces Attack_CD wait_time divisor).
@export var attack_speed_multiplier: float = 1.2


func _init() -> void:
	effect_id = &"attack_speed_aura"
	display_name = "Attack Speed Up"
	default_duration = 0.25
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_attack_speed_mult_for_stacks(stacks: int) -> float:
	if stacks <= 0:
		return 1.0
	return pow(attack_speed_multiplier, stacks)
