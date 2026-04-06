extends Node2D
class_name AttackSpeedAuraField

## Persistent aura: reapplies attack speed buff to [Base_Unit]s in [member radius].
## Spell mode: [member aura_source_unit] unset — only player faction ([code]faction == true[/code]).
## Unit mode: [member aura_source_unit] set — same [code]faction[/code] as source; skips while source is dead.

var battle_manager: Node
var radius: float = 180.0
var refresh_duration: float = 2.0
## When non-null, only buff units sharing this unit's faction; [member global_position] should follow the source (e.g. child of unit at origin).
var aura_source_unit: Base_Unit = null

var _def: AttackSpeedAuraDef
var _aura_key: String


func _ready() -> void:
	_aura_key = "aura_%d" % get_instance_id()
	_def = StatusEffectLibrary.attack_speed_aura()
	z_index = 50


func _process(_delta: float) -> void:
	if _def == null or battle_manager == null:
		return
	if aura_source_unit != null and not is_instance_valid(aura_source_unit):
		return
	if aura_source_unit != null and aura_source_unit.curr_hp <= 0:
		return
	var up := battle_manager.get_node_or_null("Unit_Parent")
	if up == null:
		return
	for child in up.get_children():
		if not child is Base_Unit:
			continue
		var u: Base_Unit = child
		if aura_source_unit != null:
			if u.faction != aura_source_unit.faction:
				continue
		else:
			if not u.faction:
				continue
		if global_position.distance_to(u.global_position) <= radius:
			var sk := "%s_%d" % [_aura_key, u.get_instance_id()]
			u.apply_status_effect(_def, sk, 1, refresh_duration)
