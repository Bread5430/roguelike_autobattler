extends Base_Unit


func _apply_upgrade_abilities() -> void:
	match upgrade_path:
		UNIT_UPGRADES.PATH_A:
			dmg_dealt_mult = 1.3
		UNIT_UPGRADES.PATH_B:
			var atk := get_node_or_null("Ranged_Attack")
			if atk:
				var timer := atk.get_node_or_null("Attack_CD") as Timer
				if timer:
					timer.wait_time *= 0.7
