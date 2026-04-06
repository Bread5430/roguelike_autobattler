extends Base_Unit

@export var ally_death_stun_duration := 10.0
const ALLY_DEATH_STUN_STACK_KEY := "ally_death_stun"

@export var aura_radius: float = 180.0
@export var aura_refresh_duration: float = 2.0

var _attack_speed_aura: AttackSpeedAuraField


func post_ready() -> void:
	super.post_ready()
	_setup_attack_speed_aura()


func _setup_attack_speed_aura() -> void:
	var unit_parent := get_parent()
	if unit_parent == null:
		return
	var bm := unit_parent.get_parent()
	if bm == null:
		return
	_attack_speed_aura = AttackSpeedAuraField.new()
	_attack_speed_aura.name = "AttackSpeedAuraField"
	_attack_speed_aura.battle_manager = bm
	_attack_speed_aura.aura_source_unit = self
	_attack_speed_aura.radius = aura_radius
	_attack_speed_aura.refresh_duration = aura_refresh_duration
	add_child(_attack_speed_aura)


func take_damage(damage: int, apply_taken_mult: bool = true) -> void:
	var was_alive := curr_hp > 0
	super.take_damage(damage, apply_taken_mult)
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
