extends StatusEffectDef
class_name SpellImmuneDef


func _init() -> void:
	effect_id = &"spell_immune"
	display_name = "Spell Immune"
	default_duration = INF
	max_stacks = 1


func get_polarity() -> Polarity:
	return Polarity.NEUTRAL
