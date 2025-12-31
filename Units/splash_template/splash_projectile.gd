extends Base_Projectile

@export var damage : int = 3

# The area of effect will be the main splash projectile area 2D
# This AOE will get briefly enabled for the length of the splash animation, and call its hit effect on the relevant hit bodies

func on_spawned():
	is_active = true
	# Don't set monitoring to be true
	

func _on_lifetime_timeout():
	self.monitoring = true
	# TODO: await the effect animation to complete
	super()

func _on_body_entered(body): 
	if body.faction == target_faction:
		activate_hit_effect(body)
		# Do not return to pool since this needs to hit multiple things
	else:
		pass

func activate_hit_effect(body):
	body.take_damage(damage * parent_unit.dmg_dealt_mult)
