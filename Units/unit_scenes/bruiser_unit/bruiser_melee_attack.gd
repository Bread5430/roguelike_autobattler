extends Attack_Base

## Melee AOE: activates a circular hitbox child for a brief window (same pattern as arc_attack).

var _aoe_hitbox: Base_Projectile = null


func post_ready() -> void:
	super()
	_aoe_hitbox = get_node_or_null("Bruiser_Melee_Hitbox") as Base_Projectile
	if _aoe_hitbox and _aoe_hitbox.has_method("set_aoe_radius"):
		var radius: float = float(attack_range)
		if unit != null and unit.coll_circle != null and unit.coll_circle.shape is CircleShape2D:
			radius += (unit.coll_circle.shape as CircleShape2D).radius
		_aoe_hitbox.set_aoe_radius(radius)


func do_attack() -> void:
	if _aoe_hitbox and _aoe_hitbox.has_method("setup_for_strike") and _aoe_hitbox.has_method("strike"):
		_aoe_hitbox.setup_for_strike(unit, not unit.faction, get_strike_damage())
		_aoe_hitbox.strike()
	super()
