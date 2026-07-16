extends Attack_Base

func do_attack():
	var amount = get_strike_damage()
	target_unit.take_damage(amount, true, unit)
	unit.add_damage_dealt(amount)
	super()
