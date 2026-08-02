extends TimedSpellZone
class_name FireField

@export var refresh_duration : float = 0.25

var _def : FireDef
var _field_key : String


func _ready() -> void:
	fill_color = Color(1.0, 0.55, 0.15, 0.28)
	outline_color = Color(1.0, 0.4, 0.1, 0.9)
	super._ready()
	_def = StatusEffectLibrary.fire()
	_field_key = "fire_%d" % get_instance_id()


func _process(delta: float) -> void:
	var unit_parent = get_unit_parent()
	if unit_parent != null:
		for child in unit_parent.get_children():
			if not child is Base_Unit:
				continue
			var unit: Base_Unit = child
			if unit.is_spell_immune() or unit.curr_hp <= 0:
				continue
			if global_position.distance_to(unit.global_position) <= radius:
				var stack_key = "%s_%d" % [_field_key, unit.get_instance_id()]
				unit.apply_status_effect(
					_def,
					stack_key,
					1,
					refresh_duration,
					null,
					{"from_spell": true}
				)
	super._process(delta)
