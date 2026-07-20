extends Node2D
class_name Attack_Base

var unit
var target_cmp

@onready var attack_cd : Timer = $Attack_CD

###### Internal Variables
@export var attack_range : int
var target_unit : Base_Unit = null
var can_attack = true
const RETARGET_INTERVAL_FRAMES := 3
var _last_retarget_frame: int = -1


func _ready() -> void:
	if attack_cd != null and not attack_cd.timeout.is_connected(_on_attack_cd_timeout):
		attack_cd.timeout.connect(_on_attack_cd_timeout)

####### Primary Functions

func in_range() -> bool:
	if not _target_is_valid_for_attack():
		return false
	# Edge-to-edge: gap between collision circles must be within attack_range.
	# Matches placement range preview (circle radius = attack_range + own coll radius).
	var dist: float = (target_unit.position - unit.position).length()
	var r_sum: float = 0.0
	if unit.coll_circle != null and unit.coll_circle.shape is CircleShape2D:
		r_sum += (unit.coll_circle.shape as CircleShape2D).radius
	if target_unit.coll_circle != null and target_unit.coll_circle.shape is CircleShape2D:
		r_sum += (target_unit.coll_circle.shape as CircleShape2D).radius
	return dist - r_sum < float(attack_range)

func check_new_targets() -> bool:
	var frame := Engine.get_physics_frames()
	if _target_is_valid_for_attack() and _last_retarget_frame >= 0 and frame - _last_retarget_frame < RETARGET_INTERVAL_FRAMES:
		return false
	
	var new_target = target_cmp.get_target()
	_last_retarget_frame = frame
	if new_target == target_unit:
		return false
	else:
		target_unit = new_target
		return true
	
func check_can_attack() -> bool:
	if unit.is_basic_attacks_restricted():
		return false
	if not _target_is_valid_for_attack():
		return false
	if in_range() and can_attack:
		return true
	return false
	
func do_attack() -> void:
	can_attack = false
	attack_cd.start()

####### Helper functions

func post_ready() -> void:
	unit = get_parent()
	target_cmp = unit.target_move


func _target_is_valid_for_attack() -> bool:
	if target_unit == null or not is_instance_valid(target_unit):
		return false
	return target_unit.curr_hp > 0


## Damage for this strike: parent unit's damage stat times dealt multiplier (queried at fire time).
func get_strike_damage() -> int:
	if unit is Base_Unit:
		var u: Base_Unit = unit
		return int(u.get_attack_damage() * u.dmg_dealt_mult)
	return 0


func _on_attack_cd_timeout():
	can_attack = true
