extends Base_Projectile

## Circular melee AOE attached to the bruiser. Does not move or use the projectile pool.
## Enabled briefly on attack; engine collision applies damage to all overlapping enemies.

const STRIKE_DURATION := 0.1

@onready var hitbox_timer: Timer = $HitboxActiveTimer


func _ready() -> void:
	sprite.hide()
	monitoring = false
	if col_shape:
		col_shape.disabled = true
	var life_timer = get_node_or_null("Lifetime") as Timer
	if life_timer:
		life_timer.stop()
		life_timer.one_shot = true


func _physics_process(_delta: float) -> void:
	pass


func setup_for_strike(parent: Base_Unit, tgt_faction: bool, dmg: int) -> void:
	parent_unit = parent
	parent_dmg_mult = parent.dmg_dealt_mult
	target_faction = tgt_faction
	damage = dmg


func set_aoe_radius(radius: float) -> void:
	if not col_shape or not col_shape.shape is CircleShape2D:
		return
	var circle: CircleShape2D = col_shape.shape
	circle.radius = radius
	position = Vector2.ZERO


func strike() -> void:
	monitoring = true
	if col_shape:
		col_shape.disabled = false
	sprite.show()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"strike"):
		sprite.play(&"strike")
	hitbox_timer.start(STRIKE_DURATION)


func _on_body_entered(body: Node2D) -> void:
	if body is Base_Unit and body.faction == target_faction:
		activate_hit_effect(body)


func _on_lifetime_timeout() -> void:
	pass


func _on_hitbox_active_timeout() -> void:
	monitoring = false
	if col_shape:
		col_shape.disabled = true
	sprite.hide()
