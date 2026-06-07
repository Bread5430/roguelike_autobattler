extends Attack_Base

@export var target_rank: int = 0
@export var proj_scene: PackedScene
@export var proj_pool: Node
@export var speed: int = 520
@export var lifetime_val: float = 1.0


func set_proj_pool(pool: Node) -> void:
	proj_pool = pool


func check_new_targets() -> bool:
	var targets = target_cmp.get_N_targets(2)
	var new_target: Base_Unit = null
	if target_rank < targets.size():
		new_target = targets[target_rank] as Base_Unit
	if new_target == target_unit:
		return false
	target_unit = new_target
	_last_retarget_frame = Engine.get_physics_frames()
	return true


func do_attack() -> void:
	if not _target_is_valid_for_attack() or proj_pool == null or proj_scene == null:
		return
	var new_projectile = proj_pool.spawn_projectile(proj_scene)
	new_projectile.setup(get_parent(), global_position, not get_parent().faction)
	new_projectile.set_properties_via_spawner({
		"damage": get_strike_damage(),
		"speed": speed,
		"lifetime_val": lifetime_val,
	})
	new_projectile.set_target_position(target_unit.global_position)
	super()
