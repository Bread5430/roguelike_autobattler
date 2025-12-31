extends Attack_Base

func do_attack():
	target_unit.take_damage(damage * unit.dmg_dealt_mult)
	super()
