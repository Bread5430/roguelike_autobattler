extends Attack_Base

@export var proj_scene : PackedScene
@export var proj_pool : Node

func set_proj_pool(pool : Node):
	proj_pool = pool

func do_attack():
	
	# Spawn a projectile instance, and pass it the information of its target
	var new_projectile = proj_pool.pool_instantiate(proj_scene)
	new_projectile.set_target(target_unit)
	proj_pool.enable_in_scene(new_projectile)
	
	super()
