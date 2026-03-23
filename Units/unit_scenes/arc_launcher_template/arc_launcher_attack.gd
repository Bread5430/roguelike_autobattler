extends Attack_Base

@export var arc_angle_deg: float = 90.0
@export var arc_distance: float = 60.0

@onready var visible_time: Timer = $visble_time

var show_line: bool = false
var _line_end_local: Vector2 = Vector2.ZERO

var _arc_hitbox: Base_Projectile = null

func post_ready() -> void:
	super()
	_arc_hitbox = get_node_or_null("Arc_Hitbox") as Base_Projectile
	if _arc_hitbox and _arc_hitbox.has_method("set_capsule_size"):
		_arc_hitbox.set_capsule_size(arc_distance, arc_angle_deg)

func _get_facing_direction() -> Vector2:
	# Prefer facing toward the current target.
	if target_unit != null and is_instance_valid(target_unit):
		var to_target : Vector2 = target_unit.global_position - unit.global_position
		if to_target.length_squared() > 0.0001:
			return to_target.normalized()
	var flow = target_cmp.get_flow_field()
	if flow.length_squared() > 0.0001:
		return flow.normalized()
	return Vector2.RIGHT

func do_attack() -> void:
	var facing := _get_facing_direction()
	var origin : Vector2 = unit.global_position

	# Fire the arc at the end of the aiming line:
	# - if we have a target: end at target position (clamped by attack_range)
	# - otherwise: use straight ahead at attack_range
	var end_pos := origin + facing * float(attack_range - arc_distance)
	if target_unit != null and is_instance_valid(target_unit):
		var dist := (target_unit.global_position - origin).length()
		var clamped := minf(dist, float(attack_range))
		end_pos = origin + facing * clamped

	_line_end_local = end_pos - origin

	# Temporary aiming line (purely cosmetic).
	show_line = true
	if visible_time:
		visible_time.start()
	queue_redraw()

	# Enable the arc hitbox at the line end.
	if _arc_hitbox:
		_arc_hitbox.setup_for_arc(unit, not unit.faction, get_strike_damage())
		_arc_hitbox.set_capsule_size(arc_distance, arc_angle_deg)
		_arc_hitbox.align_and_strike_at(facing, end_pos)

	super()

func _draw() -> void:
	if not show_line:
		return
	draw_line(Vector2.ZERO, _line_end_local, Color.RED, 2)
	draw_circle(_line_end_local, 5, Color.RED)

func _on_visble_time_timeout() -> void:
	show_line = false
	queue_redraw()
