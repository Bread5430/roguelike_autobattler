extends Attack_Base

## Arc-shaped area attack in front of the unit using a static capsule hitbox (Base_Projectile).
## Hitbox is enabled for 0.1s on attack; engine handles overlap detection.

@export var arc_angle_deg: float = 90.0

var _arc_hitbox: Base_Projectile = null

func post_ready() -> void:
	super()
	_arc_hitbox = get_node_or_null("Arc_Hitbox") as Base_Projectile
	if _arc_hitbox and _arc_hitbox.has_method("set_capsule_size"):
		_arc_hitbox.set_capsule_size(float(attack_range), arc_angle_deg)

func _get_unit_parent() -> Node:
	var u = get_parent()
	if u is Base_Unit:
		return u.get_parent()
	return null

func _get_facing_direction() -> Vector2:
	if target_unit != null and is_instance_valid(target_unit):
		var to_target : Vector2 = (target_unit.global_position - unit.global_position)
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	var flow : Vector2 = target_cmp.get_flow_field()
	if flow.length_squared() > 0.0001:
		return flow.normalized()
	return Vector2.RIGHT

func do_attack() -> void:
	if _arc_hitbox:
		_arc_hitbox.setup_for_arc(unit, not unit.faction, get_strike_damage())
		_arc_hitbox.align_and_strike(_get_facing_direction())
	super()
