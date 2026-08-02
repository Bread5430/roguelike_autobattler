extends TimedSpellZone
class_name OrbitalStrikeMarker

@export var damage : int = 100

var _resolved : bool = false


func _ready() -> void:
	fill_color = Color(1.0, 0.2, 0.1, 0.3)
	outline_color = Color(1.0, 0.1, 0.05, 0.95)
	super._ready()


func _process(delta: float) -> void:
	if not _resolved and elapsed + delta >= lifetime:
		_resolved = true
		_strike()
	super._process(delta)


func _strike() -> void:
	var unit_parent = get_unit_parent()
	if unit_parent == null:
		return
	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var unit: Base_Unit = child
		if unit.curr_hp <= 0 or unit.is_spell_immune():
			continue
		if global_position.distance_to(unit.global_position) <= radius:
			unit.take_damage(damage)
