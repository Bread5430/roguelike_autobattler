extends Base_Projectile

## Pierces one enemy shape (damage once per shape); a second distinct enemy shape takes damage and despawns.

var _pierced_shape_id: Variant = null


func _ready() -> void:
	super()
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)


func on_spawned() -> void:
	_pierced_shape_id = null
	super()


func _collision_shape_from_body(body: CharacterBody2D, shape_index: int) -> CollisionShape2D:
	var owner_id := body.shape_find_owner(shape_index)
	if owner_id < 0:
		return null
	var owner_node := body.shape_owner_get_owner(owner_id)
	return owner_node as CollisionShape2D


func _identity_from_hit(body: Node2D, body_shape_index: int) -> Variant:
	if not is_instance_valid(body):
		return null
	if body is CharacterBody2D:
		var cs := _collision_shape_from_body(body as CharacterBody2D, body_shape_index)
		if cs != null:
			return cs
	return Vector2i(body.get_instance_id(), body_shape_index)


func _should_ignore_body(body: Node2D) -> bool:
	if not is_instance_valid(body):
		return true
	if body == parent_unit:
		return true
	if not body is Base_Unit:
		return true
	return body.faction != target_faction


func _on_body_shape_entered(_body_rid: RID, body: Node2D, body_shape_index: int, _local_shape_index: int) -> void:
	if not is_active:
		return
	if _should_ignore_body(body):
		return
	if not body.has_method("take_damage"):
		return
	var shape_id = _identity_from_hit(body, body_shape_index)
	if shape_id == null:
		return

	if _pierced_shape_id == null:
		activate_hit_effect(body)
		_pierced_shape_id = shape_id
		return
	if shape_id == _pierced_shape_id:
		return
	activate_hit_effect(body)
	return_to_pool()
