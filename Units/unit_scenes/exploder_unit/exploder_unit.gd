extends Base_Unit

const DEATH_SPLASH_SCENE := preload("res://Units/unit_scenes/splash_template/splash_projectile.tscn")

var _proj_pool: ProjectilePool


func post_ready() -> void:
	_proj_pool = get_parent().get_parent().proj_pool
	super.post_ready()


func spawn_death_explosion() -> void:
	if _proj_pool == null:
		return
	var proj := _proj_pool.spawn_projectile(DEATH_SPLASH_SCENE)
	if proj == null:
		return
	proj.setup(self, global_position, not faction)
	proj.set_properties_via_spawner({
		"damage": 10,
		"speed": 300,
		"lifetime_val": 1.0,
	})
	proj.set_target_position(global_position)
	proj.scale = Vector2(2,2)
