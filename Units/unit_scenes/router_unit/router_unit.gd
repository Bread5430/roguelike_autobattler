extends Base_Unit

@export var ally_death_stun_duration := 10.0
const ALLY_DEATH_STUN_STACK_KEY := "ally_death_stun"

@export var aura_radius: float = 180.0
@export var aura_refresh_duration: float = 2.0
## World pixels; must match router card [member Unit_Card.router_exclusion_radius] for deployment spacing UI.
@export var deployment_exclusion_radius: float = 180.0

var _attack_speed_aura: AttackSpeedAuraField


func post_ready() -> void:
	super.post_ready()
	_setup_attack_speed_aura()
	_setup_deployment_exclusion_visual()


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


func _setup_deployment_exclusion_visual() -> void:
	var viz := RouterDeploymentExclusionDraw.new()
	viz.name = "RouterDeploymentExclusionDraw"
	viz.z_index = 20
	add_child(viz)
	viz.setup(self)


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


## Draws deployment exclusion disk in world space; only while preparing battle and this router is the selected unit.
class RouterDeploymentExclusionDraw extends Node2D:
	var _host: Base_Unit

	func setup(host_unit: Base_Unit) -> void:
		_host = host_unit

	func _process(_delta: float) -> void:
		if _should_show():
			visible = true
			queue_redraw()
		else:
			visible = false

	func _should_show() -> bool:
		if _host == null or not is_instance_valid(_host):
			return false
		var gui: Node = _host.get_tree().get_first_node_in_group("GAME_GUI")
		if gui == null:
			return false
		if not gui.get("deployment_mode"):
			return false
		var tc: Node = gui.get_node_or_null("TacticalCursor")
		if tc == null or not tc.has_method("get_selected_unit"):
			return false
		return tc.get_selected_unit() == _host

	func _draw() -> void:
		if _host == null:
			return
		var fill := Color(1.0, 0.45, 0.12, 0.18)
		var rvar: Variant = _host.get("deployment_exclusion_radius")
		var rad: float = float(rvar) if rvar != null else 180.0
		draw_circle(Vector2.ZERO, rad, fill)
