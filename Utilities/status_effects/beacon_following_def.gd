extends StatusEffectDef
class_name BeaconFollowingDef

func _init() -> void:
	effect_id = &"beacon_following"
	display_name = "Beacon"
	default_duration = 8640000.0
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.BUFF
