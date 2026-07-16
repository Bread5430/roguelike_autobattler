extends StatusEffectDef
class_name InfestedDef

## On death, host spawns crawlers (basic_chaff) equal to its scrap_cost for the infector's faction.


func _init() -> void:
	effect_id = &"infested"
	display_name = "Infested"
	default_duration = 999999.0
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.DEBUFF
