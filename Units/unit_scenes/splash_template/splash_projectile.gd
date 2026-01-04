extends Base_Projectile


# The area of effect will be the main splash projectile area 2D
# This AOE will get briefly enabled for the length of the splash animation, and call its hit effect on the relevant hit bodies

func set_target_position(target_position: Vector2) -> void:
	super(target_position)
	lifetime.start(target_position.distance_to(global_position) / speed)

func on_spawned():
	is_active = true
	col_shape.disabled = true
	sprite.animation = &"default"
	# Don't set monitoring to be true
	# Start timer in different component

func _on_lifetime_timeout():
	self.monitoring = true
	col_shape.disabled = false
	speed = 0
	animation.play("explode")

func _on_body_entered(body): 
	if body.faction == target_faction:
		activate_hit_effect(body)
		# Do not return to pool since this needs to hit multiple things
