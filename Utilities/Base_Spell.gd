extends Node
class_name Base_Spell

## Reference set by spell bar when adding the spell. Used for preview placement and cast targeting.
var battle_manager : Node

## Override in subclasses. Update or show the area-of-effect indicator at the given global position.
func preview(_world_pos: Vector2) -> void:
	pass

## Override in subclasses. Apply the spell effect at the given global position. Remove preview after casting.
func cast(_world_pos: Vector2) -> void:
	pass

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


## Ask the battle_manager for active modifiers at the current cast location, then apply these to the spell
func _apply_modifiers(cast_location : Vector2, modifiable_attributes : Dictionary) -> void:
	pass
