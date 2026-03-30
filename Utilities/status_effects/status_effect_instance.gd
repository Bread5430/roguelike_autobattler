extends RefCounted
class_name StatusEffectInstance

## Runtime state for one (effect_id, stack_key) on a unit.

var def: StatusEffectDef
var stack_key: String = ""
var stacks: int = 1
var remaining_time: float = 0.0
## Last applied segment duration (used for UI remaining fraction).
var reference_duration: float = 0.0
## Accumulator for periodic ticks (DoT).
var tick_accumulator: float = 0.0
## Effect-specific data (e.g. ticks_done for ramp DoT).
var custom_state: Dictionary = {}


func _init(p_def: StatusEffectDef, p_stack_key: String, p_stacks: int, p_duration: float) -> void:
	def = p_def
	stack_key = p_stack_key
	stacks = p_stacks
	remaining_time = p_duration
	reference_duration = p_duration


func get_instance_key() -> String:
	if def == null:
		return ""
	return "%s::%s" % [str(def.effect_id), stack_key]
