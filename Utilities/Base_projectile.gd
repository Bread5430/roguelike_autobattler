extends Area2D

class_name Base_Projectile

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var col_shape : CollisionShape2D = $CollisionShape2D
@onready var lifetime : Timer = $Lifetime
@onready var animation : AnimationPlayer = $AnimationPlayer
var pool_manager: ProjectilePool = null

###### Internal Vars
@export var speed : int = 50
@export var lifetime_val : float = 1.0
var direction : Vector2
var target_faction : bool
var is_active: bool = false

# Optional: Trail/particles that need cleanup
var trail_particles: GPUParticles2D = null

###### Standard Functions


##### Spawning and Pooling management
func _ready():
	# Find trail particles if they exist
	trail_particles = get_node_or_null("TrailParticles")

func set_pool_manager(pool: ProjectilePool) -> void:
	"""Called by the pool when the projectile is created"""
	pool_manager = pool
	

func on_spawned() -> void:
	"""Called when projectile is taken from pool and activated"""
	is_active = true
	
	# Reset any state
	if trail_particles:
		trail_particles.emitting = true
	
	# Override this in child classes for custom setup

func setup(spawn_position: Vector2, spawn_direction: Vector2, spawn_speed: float = -1.0) -> void:
	"""Setup projectile parameters after spawning"""
	global_position = spawn_position
	direction = spawn_direction.normalized()
	
	if spawn_speed > 0:
		speed = spawn_speed
	
	# Rotate sprite to face direction
	rotation = direction.angle()

func _physics_process(delta):
	if not is_active:
		return
	position += direction * speed * delta

##### Hit detection and lifetime

func _on_lifetime_timeout():
	return_to_pool()
	
func _on_body_entered(body): 
	if body.faction == target_faction:
		activate_hit_effect(body)
		return_to_pool()
	else: # Do nothing if it hits an allied unit
		pass

func return_to_pool() -> void:
	"""Return this projectile to the pool"""
	if pool_manager:
		pool_manager.return_to_pool(self)
	else:
		# Fallback if no pool manager
		queue_free()

#OVERIDE - This is to be overrided in each seperate projectile
func activate_hit_effect(body):
	pass

func set_direction():
	direction = Vector2.from_angle(rotation)

func set_target(target_position: Vector2) -> void:
	"""Aim at a specific target"""
	direction = (target_position - global_position).normalized()
	rotation = direction.angle()

# ============================================================================
# DEBUG METHODS
# ============================================================================

func get_remaining_lifetime() -> float:
	"""Get remaining lifetime in seconds"""
	return max(0.0, lifetime.wait_time - lifetime.time_left)

func is_expired() -> bool:
	"""Check if projectile has exceeded its lifetime"""
	return lifetime.time_left <= 0
