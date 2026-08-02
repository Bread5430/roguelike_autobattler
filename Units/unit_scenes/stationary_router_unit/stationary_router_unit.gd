extends Base_Unit

@export var ally_death_stun_duration := 10.0
const ALLY_DEATH_STUN_STACK_KEY := "ally_death_stun"


func post_ready() -> void:
	super.post_ready()
	apply_status_effect(StatusEffectLibrary.spell_immune(), "static_router", 1)


func take_damage(damage: int, apply_taken_mult: bool = true, source: Base_Unit = null) -> void:
	var was_alive = curr_hp > 0
	super.take_damage(damage, apply_taken_mult, source)
	if was_alive and curr_hp <= 0:
		_apply_same_faction_death_stun()


func _apply_same_faction_death_stun() -> void:
	var parent_unit := get_parent()
	if parent_unit == null:
		return
	var def := StatusEffectLibrary.stunned()
	for c in parent_unit.get_children():
		if c == self or not c is Base_Unit:
			continue
		var ally: Base_Unit = c
		if ally.faction != faction:
			continue
		ally.apply_status_effect(def, ALLY_DEATH_STUN_STACK_KEY, 1, ally_death_stun_duration)
