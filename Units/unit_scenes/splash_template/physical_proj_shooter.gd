extends Base_Unit


# Post Ready assumes that the instance has already been reparented to the Unit Parent
func post_ready():
	# Find all the attack nodes that use 
	var parent_proj_pool = get_parent().get_parent().proj_pool
	for node in get_children():
		if node is Attack_Base and node.has_method("set_proj_pool"):
			node.set_proj_pool(parent_proj_pool)
			
	super()
