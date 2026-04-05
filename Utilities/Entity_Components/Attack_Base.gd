extends Node2D
class_name Attack_Base

var unit
var target_cmp

@onready var attack_cd : Timer = $Attack_CD

###### Internal Variables
@export var attack_range : int
var target_unit : Base_Unit = null
var can_attack = true

####### Primary Functions

func in_range() -> bool:
	if target_unit == null:
		return false
		
	# Subtract the collision circle radius for both the target and the attacker
	# For the case when melee units have range smaller than the target's collision
	return (target_unit.position - unit.position).length_squared() - \
	 target_unit.coll_circle.shape.get_radius() ** 2 - unit.coll_circle.shape.get_radius() ** 2 \
		< attack_range ** 2

func check_new_targets() -> bool:
	var new_target = target_cmp.get_target()
	if new_target == target_unit:
		return false
	else:
		target_unit = new_target
		return true
	
func check_can_attack() -> bool:
	if unit.is_basic_attacks_restricted():
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


## Damage for this strike: parent unit's damage stat times dealt multiplier (queried at fire time).
func get_strike_damage() -> int:
	if unit is Base_Unit:
		var u: Base_Unit = unit
		return int(u.get_attack_damage() * u.dmg_dealt_mult)
	return 0


func _on_attack_cd_timeout():
	can_attack = true
