extends Attack_Base

func do_attack():
	var amount := int(damage * unit.dmg_dealt_mult)
	target_unit.take_damage(amount)
	unit.add_damage_dealt(amount)
	super()
