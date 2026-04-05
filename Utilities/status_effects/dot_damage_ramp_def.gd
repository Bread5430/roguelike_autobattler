extends StatusEffectDef
class_name DotDamageRampDef

@export var tick_interval: float = 0.5
@export var base_tick_damage: int = 1
@export var damage_ramp_per_tick: int = 1


func _init() -> void:
	effect_id = &"dot_damage_ramp"
	display_name = "Burning"
	default_duration = 5.0
	max_stacks = 5
	StatusEffectTune.apply_csv(self, effect_id)


func get_polarity() -> Polarity:
	return Polarity.DEBUFF


func get_dmg_taken_mult_for_stacks(_stacks: int) -> float:
	return 1.0


func get_move_speed_mult_for_stacks(_stacks: int) -> float:
	return 1.0


func get_attack_speed_mult_for_stacks(_stacks: int) -> float:
	return 1.0


func process_instance(instance: StatusEffectInstance, host: Base_Unit, delta: float) -> void:
	instance.tick_accumulator += delta
	while instance.tick_accumulator >= tick_interval:
		instance.tick_accumulator -= tick_interval
		var ticks_done: int = int(instance.custom_state.get("ticks_done", 0))
		var dmg: int = base_tick_damage + ticks_done * damage_ramp_per_tick
		host.take_damage(dmg, false)
		instance.custom_state["ticks_done"] = ticks_done + 1
