extends StatusEffectDef
class_name FireDef

@export var tick_interval : float = 0.25
@export var tick_damage : int = 3


func _init() -> void:
	effect_id = &"fire"
	display_name = "On Fire"
	default_duration = 0.25
	max_stacks = 1
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.DEBUFF


func process_instance(instance: StatusEffectInstance, host: Base_Unit, delta: float) -> void:
	instance.tick_accumulator += delta
	while instance.tick_accumulator >= tick_interval:
		instance.tick_accumulator -= tick_interval
		host.take_damage(tick_damage, false)
