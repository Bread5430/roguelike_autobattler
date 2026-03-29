extends Node2D
class_name GroundSlowField

## Persistent field: reapplies slow to every [Base_Unit] inside [member radius].

var battle_manager: Node
var radius: float = 180.0
var refresh_duration: float = 2.0

var _def: GroundSlowDef
var _field_key: String


func _ready() -> void:
	_field_key = "slowfield_%d" % get_instance_id()
	_def = StatusEffectLibrary.ground_slow()
	z_index = 50


func _process(_delta: float) -> void:
	if _def == null or battle_manager == null:
		return
	var up := battle_manager.get_node_or_null("Unit_Parent")
	if up == null:
		return
	for child in up.get_children():
		if not child is Base_Unit:
			continue
		var u: Base_Unit = child
		if global_position.distance_to(u.global_position) <= radius:
			var sk := "%s_%d" % [_field_key, u.get_instance_id()]
			u.apply_status_effect(_def, sk, 1, refresh_duration)
