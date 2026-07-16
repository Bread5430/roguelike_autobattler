extends Base_Unit

const DMG_PER_KILL := 0.15

var _kill_count: int = 0


func _apply_upgrade_abilities() -> void:
	match upgrade_path:
		UNIT_UPGRADES.PATH_A:
			pass
		UNIT_UPGRADES.PATH_B:
			flat_damage_reduction = 2


func _on_kill(_killed: Base_Unit) -> void:
	if upgrade_path != UNIT_UPGRADES.PATH_A:
		return
	_kill_count += 1
	dmg_dealt_mult = 1.0 + float(_kill_count) * DMG_PER_KILL
