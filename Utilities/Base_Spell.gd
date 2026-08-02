extends Node
class_name Base_Spell

## Reference set by spell bar when adding the spell. Used for preview placement and cast targeting.
var battle_manager : Node
@export var cast_time : float = 1.0

var _cast_pending : bool = false
var _confirmed_cast_position : Vector2

## Override in subclasses. Update or show the area-of-effect indicator at the given global position.
func preview(_world_pos: Vector2) -> void:
	pass

## Override in subclasses. Apply the spell effect at the given global position. Remove preview after casting.
func cast(_world_pos: Vector2) -> void:
	pass


## Locks the final preview, waits the universal cast time, then resolves the spell.
func begin_cast(world_pos: Vector2) -> void:
	if _cast_pending:
		return
	_cast_pending = true
	_confirmed_cast_position = world_pos
	lock_cast_indicator(world_pos)
	if cast_time > 0.0:
		await get_tree().create_timer(cast_time).timeout
	if not is_inside_tree():
		return
	cast(_confirmed_cast_position)
	clear_preview()
	queue_free()


func lock_cast_indicator(world_pos: Vector2) -> void:
	preview(world_pos)

## Call when entering casting mode to create preview; call when exiting to remove it.
func clear_preview() -> void:
	pass


## Multi-step spells override [method handles_casting_input] and [method on_casting_click].
## Return dict keys: [code]consume_spell[/code] (remove from bar), [code]exit_casting[/code] (leave casting mode).
func handles_casting_input() -> bool:
	return false


func on_casting_click(_world_pos: Vector2) -> Dictionary:
	return {"consume_spell": true, "exit_casting": true}


func on_casting_cancel() -> void:
	pass


func can_affect_unit(unit: Base_Unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.curr_hp > 0 and not unit.is_spell_immune()


func apply_spell_status(
	unit: Base_Unit,
	def: StatusEffectDef,
	stack_key: String,
	stacks_add: int = 1,
	duration_override_seconds: float = -1.0
) -> void:
	if not can_affect_unit(unit):
		return
	unit.apply_status_effect(
		def,
		stack_key,
		stacks_add,
		duration_override_seconds,
		null,
		{"from_spell": true}
	)


func deal_spell_damage(unit: Base_Unit, damage: int) -> void:
	if can_affect_unit(unit):
		unit.take_damage(damage)


## Ask the battle_manager for active modifiers at the current cast location, then apply these to the spell
func _apply_modifiers(cast_location : Vector2, modifiable_attributes : Dictionary) -> void:
	pass
