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

## Returns all enemy units inside the arc (within distance and angle).
func get_enemies_in_arc() -> Array[Base_Unit]:
	var result: Array[Base_Unit] = []
	var unit_parent = _get_unit_parent()
	if unit_parent == null:
		return result

	var origin :Vector2 = unit.global_position
	var facing := _get_facing_direction()
	var half_angle_rad := deg_to_rad(arc_angle_deg * 0.5)
	var range_sq := attack_range * attack_range

	for child in unit_parent.get_children():
		if not child is Base_Unit:
			continue
		var other := child as Base_Unit
		if other.faction == unit.faction or not is_instance_valid(other):
			continue
		var to_other := other.global_position - origin
		var dist_sq := to_other.length_squared()
		if dist_sq > range_sq or dist_sq < 0.0001:
			continue
		var dir_to := to_other.normalized()
		var angle := dir_to.angle_to(facing)
		if abs(angle) <= half_angle_rad:
			result.append(other)
	return result

func in_range() -> bool:
	return get_enemies_in_arc().size() > 0

func do_attack() -> void:
	if _arc_hitbox and _arc_hitbox.has_method("setup_for_arc") and _arc_hitbox.has_method("align_and_strike"):
		_arc_hitbox.setup_for_arc(unit, not unit.faction, damage)
		_arc_hitbox.align_and_strike(_get_facing_direction())
	super()
