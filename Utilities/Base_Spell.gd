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
