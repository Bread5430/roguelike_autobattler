extends Base_Unit


func _apply_upgrade_abilities() -> void:
	match upgrade_path:
		UNIT_UPGRADES.PATH_A:
			pass
		UNIT_UPGRADES.PATH_B:
			_refresh_bloodlust_bonuses()


func take_damage(damage: int, apply_taken_mult: bool = true, source: Base_Unit = null) -> void:
	super.take_damage(damage, apply_taken_mult, source)
	if upgrade_path == UNIT_UPGRADES.PATH_B and curr_hp > 0:
		_refresh_bloodlust_bonuses()


func _on_kill(killed: Base_Unit) -> void:
	if upgrade_path != UNIT_UPGRADES.PATH_A:
		return
	if killed == null:
		return
	var heal_amt = maxi(1, int(killed.max_hp * 0.25))
	curr_hp = mini(max_hp, curr_hp + heal_amt)


## Path B: up to +50% move/attack speed at empty HP (scales with missing HP fraction).
func _refresh_bloodlust_bonuses() -> void:
	if max_hp <= 0:
		return
	var missing_frac = clampf(1.0 - (float(curr_hp) / float(max_hp)), 0.0, 1.0)
	var bonus = 1.0 + missing_frac * 0.5
	extra_move_speed_mult = bonus
	extra_attack_speed_mult = bonus
	_recompute_status_stat_modifiers()
