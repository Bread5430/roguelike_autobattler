extends Base_Unit

const REVIVE_DELAY := 5.0
const REVIVE_CHANCE := 0.5

## When true, melee applies Infested on hit (Path A).
var applies_infested: bool = false

var _revive_enabled: bool = false
var _has_revived: bool = false
var _revive_pending: bool = false
var _revive_timer: float = 0.0
var _will_revive_this_death: bool = false


func _apply_upgrade_abilities() -> void:
	match upgrade_path:
		UNIT_UPGRADES.PATH_A:
			applies_infested = true
			extra_move_speed_mult = 1.35
			_recompute_status_stat_modifiers()
		UNIT_UPGRADES.PATH_B:
			_revive_enabled = true


func finish_death() -> void:
	if _will_revive_this_death:
		_begin_revive()
		return
	queue_free()


func take_damage(damage: int, apply_taken_mult: bool = true, source: Base_Unit = null) -> void:
	var was_alive = curr_hp > 0
	super.take_damage(damage, apply_taken_mult, source)
	if was_alive and curr_hp <= 0 and _revive_enabled and not _has_revived:
		_will_revive_this_death = randf() < REVIVE_CHANCE


func _begin_revive() -> void:
	_has_revived = true
	_will_revive_this_death = false
	_revive_pending = true
	_revive_timer = REVIVE_DELAY
	_death_notified = false
	if coll_circle != null:
		coll_circle.set_deferred("disabled", true)
	visible = false
	velocity = Vector2.ZERO
	move_vec = Vector2.ZERO
	if animation != null and animation.is_playing():
		animation.stop()


func _physics_process(delta: float) -> void:
	if _revive_pending:
		_revive_timer -= delta
		if _revive_timer <= 0.0:
			_complete_revive()
		return
	super._physics_process(delta)


func _complete_revive() -> void:
	_revive_pending = false
	curr_hp = max_hp
	visible = true
	if coll_circle != null:
		coll_circle.set_deferred("disabled", false)
	if state_machine != null:
		if state_machine.states.has("march"):
			state_machine.set_state(state_machine.states.march)
		set_start_stop(true)
