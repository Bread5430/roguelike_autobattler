extends Node
class_name ProjectilePool

# Pool configuration
@export var initial_pool_size: int = 50
@export var max_pool_size: int = 200
@export var auto_expand: bool = true
@export var debug_mode: bool = false

# Pool storage
# Dictionary structure: { scene_path: { "template": PackedScene, "available": Array, "active": Array } }
var pools: Dictionary = {}
var scene_templates: Dictionary = {}

# Statistics
var total_instantiations: int = 0
var total_reuses: int = 0

signal pool_expanded(scene_path: String, new_size: int)
signal pool_exhausted(scene_path: String)

func _ready():
	if debug_mode:
		print("ProjectilePool initialized")

# ============================================================================
# POOL MANAGEMENT
# ============================================================================

func register_projectile_type(proj_scene: PackedScene, preload_count: int = 0) -> void:
	"""Register a projectile type and optionally pre-instantiate some"""
	if not proj_scene:
		push_error("Cannot register null projectile scene")
		return
	
	var scene_path = proj_scene.resource_path
	
	# Initialize pool structure for this type
	if not pools.has(scene_path):
		pools[scene_path] = {
			"template": proj_scene,
			"available": [],
			"active": []
		}
		scene_templates[scene_path] = proj_scene
		
		if debug_mode:
			print("Registered projectile type: %s" % scene_path)
	
	# Pre-instantiate projectiles
	if preload_count > 0:
		prewarm_pool(proj_scene, preload_count)

func prewarm_pool(proj_scene: PackedScene, count: int) -> void:
	"""Pre-instantiate projectiles to avoid runtime allocation"""
	var scene_path = proj_scene.resource_path
	
	if not pools.has(scene_path):
		register_projectile_type(proj_scene, 0)
	
	for i in range(count):
		var projectile = _create_new_projectile(proj_scene)
		if projectile:
			pools[scene_path]["available"].append(projectile)
	
	if debug_mode:
		print("Prewarmed pool '%s' with %d projectiles" % [scene_path, count])

func pool_instantiate(proj_scene: PackedScene) -> Node:
	"""Get a projectile from the pool or create a new one"""
	if not proj_scene:
		push_error("Cannot instantiate null projectile scene")
		return null
	
	var scene_path = proj_scene.resource_path
	
	# Register if not already in pool
	if not pools.has(scene_path):
		register_projectile_type(proj_scene, 0)
	
	var pool = pools[scene_path]
	var projectile: Node = null
	
	# Try to reuse an available projectile
	if not pool["available"].is_empty():
		projectile = pool["available"].pop_back()
		total_reuses += 1
		
		if debug_mode:
			print("Reused projectile from pool '%s' (available: %d)" % [scene_path, pool["available"].size()])
	
	# Create new projectile if pool is empty
	else:
		# Check if we can expand the pool
		var total_count = pool["available"].size() + pool["active"].size()
		
		if total_count >= max_pool_size and not auto_expand:
			push_warning("Pool exhausted for '%s' and auto_expand is disabled" % scene_path)
			pool_exhausted.emit(scene_path)
			return null
		
		projectile = _create_new_projectile(proj_scene)
		total_instantiations += 1
		
		if debug_mode:
			print("Created new projectile for pool '%s' (total: %d)" % [scene_path, total_count + 1])
		
		if total_count > 0 and total_count % 10 == 0:
			pool_expanded.emit(scene_path, total_count)
	
	# Move to active list
	if projectile:
		pool["active"].append(projectile)
		
		# Set pool reference on projectile if it has the method
		if projectile.has_method("set_pool_manager"):
			projectile.set_pool_manager(self)
	
	return projectile

func _create_new_projectile(proj_scene: PackedScene) -> Node:
	"""Internal method to create and setup a new projectile"""
	var projectile = proj_scene.instantiate()
	
	if not projectile:
		push_error("Failed to instantiate projectile scene")
		return null
	
	# Add as child but keep it disabled
	add_child(projectile)
	_deactivate_projectile(projectile)
	
	return projectile

func enable_in_scene(projectile: Node) -> void:
	"""Enable and setup a projectile for use"""
	if not projectile:
		push_warning("Attempted to enable null projectile")
		return
	
	# Call setup method if available
	if projectile.has_method("on_spawned"):
		projectile.on_spawned()
	elif projectile.has_method("setup"):
		projectile.setup()
	
	# Activate the projectile
	_activate_projectile(projectile)
	
	if debug_mode:
		print("Enabled projectile: %s" % projectile.name)

func return_to_pool(projectile: Node) -> void:
	"""Return a projectile to the pool for reuse"""
	if not projectile:
		return
	
	# Find which pool this projectile belongs to
	var scene_path = _find_projectile_pool(projectile)
	
	if scene_path.is_empty():
		push_warning("Projectile not found in any pool, freeing it")
		projectile.queue_free()
		return
	
	var pool = pools[scene_path]
	
	# Remove from active list
	var active_index = pool["active"].find(projectile)
	if active_index != -1:
		pool["active"].remove_at(active_index)
	
	# Check if already in available pool (shouldn't happen, but safety check)
	if projectile in pool["available"]:
		push_warning("Projectile already in available pool")
		return
	
	# Call cleanup method if available
	if projectile.has_method("on_returned"):
		projectile.on_returned()
	elif projectile.has_method("cleanup"):
		projectile.cleanup()
	
	# Deactivate and return to pool
	_deactivate_projectile(projectile)
	pool["available"].append(projectile)
	
	if debug_mode:
		print("Returned projectile to pool '%s' (available: %d)" % [scene_path, pool["available"].size()])

func _find_projectile_pool(projectile: Node) -> String:
	"""Find which pool a projectile belongs to"""
	for scene_path in pools.keys():
		var pool = pools[scene_path]
		if projectile in pool["active"] or projectile in pool["available"]:
			return scene_path
	return ""

func _activate_projectile(projectile: Node) -> void:
	"""Activate a projectile (show, enable physics, etc.)"""
	projectile.show()
	projectile.set_process(true)
	projectile.set_physics_process(true)
	projectile.set_process_input(false)  # Projectiles usually don't need input
	
	# Enable collision if it's a physics body
	if projectile is CollisionObject2D or projectile is CollisionObject3D:
		for child in projectile.get_children():
			if child is CollisionShape2D or child is CollisionShape3D:
				child.disabled = false

func _deactivate_projectile(projectile: Node) -> void:
	"""Deactivate a projectile (hide, disable physics, etc.)"""
	projectile.hide()
	projectile.set_process(false)
	projectile.set_physics_process(false)
	
	# Reset position to avoid issues
	projectile.global_position = Vector2(-10000, -10000)
	
	# Disable collision if it's a physics body
	if projectile is RigidBody2D or projectile is CharacterBody2D:
		projectile.velocity = Vector2.ZERO
		
	if projectile is CollisionObject2D or projectile is CollisionObject3D:
		for child in projectile.get_children():
			if child is CollisionShape2D or child is CollisionShape3D:
				child.disabled = true

# ============================================================================
# UTILITY METHODS
# ============================================================================

func clean_up() -> void:
	"""Remove all children and reset pools"""
	if debug_mode:
		print("Cleaning up all projectile pools")
	
	for scene_path in pools.keys():
		var pool = pools[scene_path]
		
		# Free all projectiles
		for projectile in pool["active"]:
			if is_instance_valid(projectile):
				projectile.queue_free()
		
		for projectile in pool["available"]:
			if is_instance_valid(projectile):
				projectile.queue_free()
	
	# Clear data structures
	pools.clear()
	scene_templates.clear()
	total_instantiations = 0
	total_reuses = 0

func get_pool_stats(proj_scene: PackedScene = null) -> Dictionary:
	"""Get statistics about the pool(s)"""
	if proj_scene:
		var scene_path = proj_scene.resource_path
		if pools.has(scene_path):
			var pool = pools[scene_path]
			return {
				"scene_path": scene_path,
				"available": pool["available"].size(),
				"active": pool["active"].size(),
				"total": pool["available"].size() + pool["active"].size()
			}
		return {}
	else:
		# Return stats for all pools
		var stats = {
			"total_instantiations": total_instantiations,
			"total_reuses": total_reuses,
			"reuse_rate": (float(total_reuses) / (total_reuses + total_instantiations)) if (total_reuses + total_instantiations) > 0 else 0.0,
			"pools": {}
		}
		
		for scene_path in pools.keys():
			var pool = pools[scene_path]
			stats["pools"][scene_path] = {
				"available": pool["available"].size(),
				"active": pool["active"].size(),
				"total": pool["available"].size() + pool["active"].size()
			}
		
		return stats

func print_stats() -> void:
	"""Print pool statistics to console"""
	var stats = get_pool_stats()
	print("\n=== Projectile Pool Statistics ===")
	print("Total Instantiations: %d" % stats.total_instantiations)
	print("Total Reuses: %d" % stats.total_reuses)
	print("Reuse Rate: %.1f%%" % (stats.reuse_rate * 100))
	print("\nPer-Type Stats:")
	
	for scene_path in stats.pools.keys():
		var pool_stats = stats.pools[scene_path]
		print("  %s:" % scene_path.get_file())
		print("    Active: %d" % pool_stats.active)
		print("    Available: %d" % pool_stats.available)
		print("    Total: %d" % pool_stats.total)
	
	print("==================================\n")

# ============================================================================
# HELPER: Get projectile with setup
# ============================================================================

func spawn_projectile(proj_scene: PackedScene, spawn_position: Vector2, spawn_rotation: float = 0.0) -> Node:
	"""Convenience method to get and setup a projectile in one call"""
	var projectile = pool_instantiate(proj_scene)
	
	if projectile:
		projectile.global_position = spawn_position
		projectile.global_rotation = spawn_rotation
		enable_in_scene(projectile)
	
	return projectile
