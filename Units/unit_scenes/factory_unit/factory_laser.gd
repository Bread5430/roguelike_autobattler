extends "res://Units/unit_scenes/ranged_unit_template/basic_ranged.gd"

@export var target_rank: int = 0


func _ready() -> void:
	visible_time.timeout.connect(_on_visble_time_timeout)


func check_new_targets() -> bool:
	var targets = target_cmp.get_N_targets(2)
	var new_target: Base_Unit = null
	if target_rank < targets.size():
		new_target = targets[target_rank] as Base_Unit
	if new_target == target_unit:
		return false
	target_unit = new_target
	_last_retarget_frame = Engine.get_physics_frames()
	return true


func do_attack() -> void:
	if not _target_is_valid_for_attack():
		return
	super()
