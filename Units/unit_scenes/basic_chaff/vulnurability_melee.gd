extends Attack_Base

func do_attack():
	var amount = get_strike_damage()
	target_unit.take_damage(amount, true, unit)
	unit.add_damage_dealt(amount)
	_apply_post_hit_status_effects()
	super()


func _apply_post_hit_status_effects() -> void:
	var stack_key = "vulnurability"
	target_unit.apply_status_effect(StatusEffectLibrary.damage_vulnerability(), stack_key, 1, -1.0)
	if unit.get("applies_infested") == true:
		target_unit.apply_status_effect(
			StatusEffectLibrary.infested(),
			"infested",
			1,
			-1.0,
			unit
		)
