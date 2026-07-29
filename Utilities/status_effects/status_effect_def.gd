extends Resource
class_name StatusEffectDef

enum Polarity {
	NEUTRAL,
	BUFF,
	DEBUFF,
}

## Unique id used for stacking keys and UI.
@export var effect_id: StringName = &""
@export var display_name: String = ""
## Optional icon for UI; assign in factory or in the inspector for .tres defs.
@export var icon: Texture2D
@export var default_duration: float = 3.0
@export var max_stacks: int = 10

## Multiplier applied per this instance (product across instances in host).
func get_dmg_taken_mult_for_stacks(_stacks: int) -> float:
	return 1.0


func get_move_speed_mult_for_stacks(_stacks: int) -> float:
	return 1.0


func get_attack_speed_mult_for_stacks(_stacks: int) -> float:
	return 1.0


## Override for periodic effects (DoT). Default: no-op.
func process_instance(_instance: StatusEffectInstance, _host: Base_Unit, _delta: float) -> void:
	pass


## Incoming damage pipeline hook. Return the remaining damage after this effect reacts
## (e.g. absorb to 0). Default: unchanged. Called before [member Base_Unit.dmg_taken_mult].
func modify_incoming_damage(
	_instance: StatusEffectInstance,
	_host: Base_Unit,
	amount: int,
	_source: Base_Unit,
	_apply_taken_mult: bool
) -> int:
	return amount


## Called once when the host first reaches 0 HP (before [signal Base_Unit.died]).
func on_host_death(_instance: StatusEffectInstance, _host: Base_Unit, _source: Base_Unit) -> void:
	pass


func get_polarity() -> Polarity:
	return Polarity.NEUTRAL


func restricts_movement() -> bool:
	return false


func restricts_basic_attacks() -> bool:
	return false


func restricts_special_abilities() -> bool:
	return false


func suppresses_buff_application() -> bool:
	return false


func suppresses_debuff_application() -> bool:
	return false


## Called on the host before a **new** instance is inserted (not on duration refresh of an existing key). Dispel-style defs purge here.
func on_applied(_host: Base_Unit) -> void:
	pass
