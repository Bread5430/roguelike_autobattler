extends Base_Unit

## Path B: on-hit slow + purge buffs.
var applies_disrupt_shot: bool = false

const PATH_A_RANGE_MULT := 3.0


func _apply_upgrade_abilities() -> void:
	match upgrade_path:
		UNIT_UPGRADES.PATH_A:
			var atk = get_node_or_null("Ranged_Attack")
			if atk != null and "attack_range" in atk:
				atk.attack_range = int(atk.attack_range * PATH_A_RANGE_MULT)
		UNIT_UPGRADES.PATH_B:
			applies_disrupt_shot = true
