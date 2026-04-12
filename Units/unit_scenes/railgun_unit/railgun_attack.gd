extends Attack_Base

@export var proj_scene: PackedScene
@export var proj_pool: Node

@export var speed: int = 520
@export var lifetime_val: float = 1.0


func set_proj_pool(pool: Node) -> void:
	proj_pool = pool


func do_attack() -> void:
	var new_projectile = proj_pool.spawn_projectile(proj_scene)
	new_projectile.setup(get_parent(), self.global_position, not get_parent().faction)

	new_projectile.set_properties_via_spawner({
		"damage": get_strike_damage(),
		"speed": speed,
		"lifetime_val": lifetime_val,
	})

	new_projectile.set_target_position(target_unit.global_position)

	super()
