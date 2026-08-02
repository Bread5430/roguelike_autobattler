extends TimedSpellZone
class_name GooField

@export var refresh_duration : float = 0.5

var _def : GroundSlowDef
var _field_key : String


func _ready() -> void:
	fill_color = Color(0.45, 0.9, 0.35, 0.28)
	outline_color = Color(0.35, 0.8, 0.25, 0.85)
	super._ready()
	_def = StatusEffectLibrary.ground_slow()
	_field_key = "goo_%d" % get_instance_id()


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
