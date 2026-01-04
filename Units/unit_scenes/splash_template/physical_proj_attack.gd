extends Attack_Base

@export var proj_scene : PackedScene
@export var proj_pool : Node

func set_proj_pool(pool : Node):
	proj_pool = pool

func do_attack():
	# Spawn a projectile instance, and pass it the information of its target
	
	var new_projectile = proj_pool.spawn_projectile(proj_scene)
	new_projectile.setup(get_parent(), self.global_position, not get_parent().faction)
	new_projectile.set_target_position(target_unit.global_position)
	
	super()
