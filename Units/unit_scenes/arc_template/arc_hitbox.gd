extends Base_Projectile

## Static capsule hitbox attached to the unit. Does not move or use the projectile pool.
## Enabled for a brief window on attack; uses engine collision for damage (no iteration).

const STRIKE_DURATION := 0.1

#@onready var col_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox_timer: Timer = $HitboxActiveTimer

func _ready() -> void:
	# Start disabled; never use pool or lifetime
	monitoring = false
	if col_shape:
		col_shape.disabled = true
	# Disable base Lifetime so it never fires
	var life_timer := get_node_or_null("Lifetime") as Timer
	if life_timer:
		life_timer.stop()
		life_timer.one_shot = true

func _physics_process(_delta: float) -> void:
	# Static hitbox: never move
	pass

## Configure from arc attack: parent unit, faction, damage. Call before strike().
func setup_for_arc(parent: Base_Unit, tgt_faction: bool, dmg: int) -> void:
	parent_unit = parent
	parent_dmg_mult = parent.dmg_dealt_mult
	target_faction = tgt_faction
	damage = dmg

## Size the capsule to approximate the arc: length = range, width from arc angle.
func set_capsule_size(arc_range: float, arc_angle_deg: float) -> void:
	if not col_shape or not col_shape.shape is CapsuleShape2D:
		return
	var cap: CapsuleShape2D = col_shape.shape
	# Capsule axis is along local Y in Godot; we rotate so length runs forward
	# height = length along axis, radius = half-width
	var half_angle_rad := deg_to_rad(arc_angle_deg * 0.5)
	cap.height = arc_range
	cap.radius = arc_range * tan(half_angle_rad) * 0.5
	# Capsule axis is local Y; center it so it extends in front of the unit after rotation
	position = Vector2(0, arc_range * 0.5)

## Align hitbox to facing and enable for STRIKE_DURATION. Call from arc_attack.do_attack().
func align_and_strike(facing_direction: Vector2) -> void:
	rotation = facing_direction.angle()
	monitoring = true
	if col_shape:
		col_shape.disabled = false
	hitbox_timer.start(STRIKE_DURATION)

func _on_body_entered(body: Node2D) -> void:
	if body is Base_Unit and body.faction == target_faction:
		activate_hit_effect(body)
	# Do not return_to_pool; we are a static child of the unit

func _on_lifetime_timeout() -> void:
	# Static hitbox is never pooled or removed; ignore base projectile lifetime
	pass

func _on_hitbox_active_timeout() -> void:
	monitoring = false
	if col_shape:
		col_shape.disabled = true
