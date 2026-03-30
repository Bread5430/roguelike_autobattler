extends Resource
class_name StatusEffectDef

## Unique id used for stacking keys and UI.
@export var effect_id: StringName = &""
@export var display_name: String = ""
## Optional icon for UI; assign in factory or in the inspector for .tres defs.
@export var icon: Texture2D
@export var default_duration: float = 3.0
@export var max_stacks: int = 10

## Multiplier applied per this instance (product across instances in host).
func get_dmg_taken_mult_for_stacks(stacks: int) -> float:
	return 1.0


func get_move_speed_mult_for_stacks(stacks: int) -> float:
	return 1.0


func get_attack_speed_mult_for_stacks(stacks: int) -> float:
	return 1.0


## Override for periodic effects (DoT). Default: no-op.
func process_instance(_instance: StatusEffectInstance, _host: Base_Unit, _delta: float) -> void:
	pass
