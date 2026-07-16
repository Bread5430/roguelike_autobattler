extends Base_Unit

const ABLATIVE_STACK_KEY := "ablative"
const ABLATIVE_REGEN_INTERVAL := 5.0

var _ablative_regen_timer: float = 0.0
var _ablative_regen_enabled: bool = false


func post_ready() -> void:
	super.post_ready()
	_apply_base_ablative_armor()


func _apply_upgrade_abilities() -> void:
	match upgrade_path:
		UNIT_UPGRADES.PATH_A:
			_ablative_regen_enabled = true
			_ablative_regen_timer = ABLATIVE_REGEN_INTERVAL
		UNIT_UPGRADES.PATH_B:
			pass


func _apply_base_ablative_armor() -> void:
	var stacks = 1
	if upgrade_path == UNIT_UPGRADES.PATH_B:
		stacks = 2
		extra_move_speed_mult = 1.25
		extra_attack_speed_mult = 1.25
		_recompute_status_stat_modifiers()
	apply_status_effect(StatusEffectLibrary.ablative_armor(), ABLATIVE_STACK_KEY, stacks)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _ablative_regen_enabled or curr_hp <= 0:
		return
	_ablative_regen_timer -= delta
	if _ablative_regen_timer > 0.0:
		return
	_ablative_regen_timer = ABLATIVE_REGEN_INTERVAL
	apply_status_effect(StatusEffectLibrary.ablative_armor(), ABLATIVE_STACK_KEY, 1)
