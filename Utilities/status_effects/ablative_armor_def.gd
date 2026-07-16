extends StatusEffectDef
class_name AblativeArmorDef

## Each stack fully absorbs one damage instance, then is consumed.
## Duration is effectively infinite (see CSV / apply call sites).


func _init() -> void:
	effect_id = &"ablative_armor"
	display_name = "Ablative Armor"
	default_duration = 999999.0
	max_stacks = 20
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.BUFF
