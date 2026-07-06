extends Base_Unit


func _apply_upgrade_abilities() -> void:
	match upgrade_path:
		UNIT_UPGRADES.PATH_A:
			move_speed *= 1.25
		UNIT_UPGRADES.PATH_B:
			dmg_taken_mult = 0.75
