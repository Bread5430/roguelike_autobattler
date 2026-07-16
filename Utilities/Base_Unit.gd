extends CharacterBody2D
class_name Base_Unit

@onready var sprite = $AnimatedSprite2D
@onready var coll_circle = $CollisionShape2D
@onready var animation = $AnimationPlayer
@onready var state_machine = $FSM
@onready var target_move = $Target_Movement

var unit_name : String

## Key for UNIT_GLOSSARY rows in Data/units_glossary.csv; one id per unit template scene.
@export var unit_glossary_id: String = ""

# Stats
@export var max_hp : int
@onready var curr_hp : int = max_hp

## Damage used when this unit strikes; overwritten from glossary when [member unit_glossary_id] matches.
@export var base_damage: int = 1

var scrap_cost: int = 0

## Flat damage subtracted after [member dmg_taken_mult] (e.g. Bruiser, Arc Path B).
var flat_damage_reduction: int = 0

## Set when spawned from an upgraded unit card; "", "path_a", or "path_b".
var upgrade_path: String = ""

var total_damage_dealt : int = 0
var dmg_dealt_mult : float = 1.0
var dmg_taken_mult : float = 1.0
## Extra multipliers stacked on top of status-effect recompute (e.g. Bruiser Path B).
var extra_move_speed_mult : float = 1.0
var extra_attack_speed_mult : float = 1.0

# Movement Related
@export var base_speed : int
@onready var move_speed : float = base_speed
@onready var move_vec : Vector2 = Vector2.ZERO

@export var spawn_position : Vector2
@export var faction : bool

## --- Status effects ---
var _status_effect_instances: Dictionary = {} ## String -> StatusEffectInstance
## Cached Attack_Base timer wait_time before status modifiers (per Attack_Base instance id).
var _base_attack_cd_wait: Dictionary = {} ## int -> float
var _restriction_movement: bool = false
var _restriction_basic_attacks: bool = false
var _restriction_special_abilities: bool = false
var _suppress_buff_application: bool = false
var _suppress_debuff_application: bool = false

signal beacon_status_changed(active: bool)
signal died(unit: Base_Unit)

var _death_notified: bool = false


func _ready() -> void:
	_sync_from_glossary()
	curr_hp = max_hp


func _sync_from_glossary() -> void:
	if unit_glossary_id.is_empty():
		return
	if not UNIT_GLOSSARY.has_entry(unit_glossary_id):
		push_warning("Unknown unit_glossary_id '%s' on %s" % [unit_glossary_id, name])
		return
	var e := UNIT_GLOSSARY.get_entry(unit_glossary_id)
	max_hp = int(e["max_hp"])
	base_speed = int(e["movement_speed"])
	move_speed = float(e["movement_speed"])
	base_damage = int(e["damage"])
	scrap_cost = int(e.get("scrap_cost", 0))
	var dn := str(e.get("display_name", ""))
	if dn != "":
		unit_name = dn


func _physics_process(delta: float) -> void:
	_process_status_effects(delta)
	move_and_slide()
	
func movement():
	velocity = move_vec.normalized() * move_speed


func disable_physics_collision() -> void:
	if coll_circle != null:
		coll_circle.set_deferred("disabled",true)


## If [param apply_taken_mult] is false, damage ignores [member dmg_taken_mult] (e.g. DoT ticks).
## [param source] is the unit that dealt the damage (used for kill credit).
func take_damage(damage: int, apply_taken_mult: bool = true, source: Base_Unit = null) -> void:
	if _try_consume_ablative_armor():
		return
	var amt = float(damage)
	if apply_taken_mult:
		amt *= dmg_taken_mult
	var final_dmg = maxi(0, int(amt) - flat_damage_reduction)
	curr_hp -= final_dmg

	if curr_hp <= 0:
		state_machine.set_state(state_machine.states.dead)
		if not _death_notified:
			_death_notified = true
			_handle_infested_on_death()
			died.emit(self)
			if source != null and is_instance_valid(source):
				source.notify_kill(self)


## Called on the killer when this unit scores a kill. Override [method _on_kill] in subclasses.
func notify_kill(killed: Base_Unit) -> void:
	_on_kill(killed)


func _on_kill(_killed: Base_Unit) -> void:
	pass


## Consumes one Ablative Armor stack and fully blocks this hit. Returns true if blocked.
func _try_consume_ablative_armor() -> bool:
	var key = _status_instance_key(&"ablative_armor", "ablative")
	if not _status_effect_instances.has(key):
		return false
	var inst: StatusEffectInstance = _status_effect_instances[key]
	inst.stacks -= 1
	if inst.stacks <= 0:
		_status_effect_instances.erase(key)
	_recompute_status_stat_modifiers()
	return true


const CRAWLER_SCENE_PATH := "res://Units/unit_scenes/basic_chaff/basicChaff.tscn"


func _handle_infested_on_death() -> void:
	var key = _status_instance_key(&"infested", "infested")
	if not _status_effect_instances.has(key):
		return
	var inst: StatusEffectInstance = _status_effect_instances[key]
	var spawn_faction = bool(inst.custom_state.get("spawn_faction", false))
	var count = maxi(1, scrap_cost)
	var parent_node = get_parent()
	if parent_node == null:
		return
	if not ResourceLoader.exists(CRAWLER_SCENE_PATH):
		return
	var crawler_scene: PackedScene = load(CRAWLER_SCENE_PATH) as PackedScene
	if crawler_scene == null:
		return
	for i in count:
		var crawler = crawler_scene.instantiate()
		if crawler == null:
			continue
		crawler.faction = spawn_faction
		var angle = TAU * float(i) / float(count)
		crawler.position = position + Vector2(cos(angle), sin(angle)) * 12.0
		parent_node.add_child(crawler)
		if crawler is Base_Unit:
			var bu: Base_Unit = crawler
			bu.post_ready()
			bu.set_start_stop(true)

func post_ready():
	for node in get_children():
		if node.has_method("post_ready"):
			node.post_ready()
	_ensure_attack_cd_cache()
	_recompute_status_stat_modifiers()
	apply_upgrade_abilities_after_ready()


func apply_upgrade_from_card(card_item_id: String) -> void:
	upgrade_path = UnitUpgradeRegistry.get_upgrade_path(card_item_id)
	if upgrade_path.is_empty():
		return
	_apply_upgrade_stats()
	_apply_upgrade_animations(card_item_id)


func apply_upgrade_abilities_after_ready() -> void:
	if upgrade_path.is_empty():
		return
	_apply_upgrade_abilities()


func _apply_upgrade_stats() -> void:
	max_hp *= 2
	curr_hp = max_hp
	base_damage *= 2
	scrap_cost *= 2


## Points the FSM at the upgraded animations authored on the AnimatedSprite2D.
## Names follow "walk_<key>" / "die_<key>" where <key> comes from the CSV path label
## (see UNIT_UPGRADES.get_animation_key). Only names that actually exist as animations
## are applied, so a missing variant simply keeps the base animation.
func _apply_upgrade_animations(card_item_id: String) -> void:
	if state_machine == null or not state_machine.has_method("set_animation_names"):
		return
	var key : String = UNIT_UPGRADES.get_animation_key(card_item_id, upgrade_path)
	if key.is_empty():
		return
	var frames : SpriteFrames = sprite.sprite_frames if sprite != null else null
	var run_name : String = "walk_" + key
	var die_name : String = "die_" + key
	var final_run : String = run_name if (frames != null and frames.has_animation(run_name)) else ""
	var final_die : String = die_name if (frames != null and frames.has_animation(die_name)) else ""
	state_machine.set_animation_names(final_run, final_die)
	if sprite != null and final_run != "":
		sprite.play(final_run)


func _apply_upgrade_abilities() -> void:
	pass

func set_start_stop(stopped_state : bool):
	state_machine.round_start_check = stopped_state

## Current attack damage before strike multipliers (buffs can adjust base_damage later).
func get_attack_damage() -> int:
	return base_damage

## Call when this unit deals damage (for tactical cursor / stats).
func add_damage_dealt(amount: int) -> void:
	total_damage_dealt += amount

## Returns attack stats from first Attack_Base child, or empty dict if none.
func get_attack_stats() -> Dictionary:
	for c in get_children():
		if c is Attack_Base:
			var atk: Attack_Base = c
			var timer := atk.get_node_or_null("Attack_CD") as Timer
			var reload_time: float = timer.wait_time if timer else 0.0
			return {
				"damage": get_attack_damage(),
				"reload_time": reload_time
			}
	return {}


func apply_status_effect(
	def: StatusEffectDef,
	stack_key: String,
	stacks_add: int = 1,
	duration_override_seconds: float = -1.0,
	_source_unit: Base_Unit = null,
	_params: Dictionary = {}
) -> void:
	if def == null:
		return
	var dur := def.default_duration
	if duration_override_seconds > 0.0:
		dur = duration_override_seconds
	var key := _status_instance_key(def.effect_id, stack_key)
	if _status_effect_instances.has(key):
		var inst: StatusEffectInstance = _status_effect_instances[key]
		inst.stacks = mini(inst.stacks + stacks_add, def.max_stacks)
		inst.remaining_time = dur
		inst.reference_duration = dur
		_recompute_status_stat_modifiers()
	else:
		var had_beacon_before := _has_effect_id(&"beacon_following")
		var pol := def.get_polarity()
		if pol == StatusEffectDef.Polarity.BUFF and _suppress_buff_application:
			return
		if pol == StatusEffectDef.Polarity.DEBUFF and _suppress_debuff_application:
			return
		def.on_applied(self)
		var inst2 := StatusEffectInstance.new(def, stack_key, stacks_add, dur)
		if def.effect_id == &"infested" and _source_unit != null and is_instance_valid(_source_unit):
			inst2.custom_state["spawn_faction"] = _source_unit.faction
		_status_effect_instances[key] = inst2
		_recompute_status_stat_modifiers()
		if def.effect_id == &"beacon_following" and not had_beacon_before:
			beacon_status_changed.emit(true)


func is_movement_restricted() -> bool:
	return _restriction_movement


func is_basic_attacks_restricted() -> bool:
	return _restriction_basic_attacks


func is_special_abilities_restricted() -> bool:
	return _restriction_special_abilities


func is_buff_application_suppressed() -> bool:
	return _suppress_buff_application


func is_debuff_application_suppressed() -> bool:
	return _suppress_debuff_application


func purge_status_effects_by_polarity(polarity: StatusEffectDef.Polarity) -> void:
	var had_beacon_before := _has_effect_id(&"beacon_following")
	var to_remove: Array[String] = []
	for eff_key in _status_effect_instances:
		var inst: StatusEffectInstance = _status_effect_instances[eff_key]
		if inst.def and inst.def.get_polarity() == polarity:
			to_remove.append(eff_key)
	if to_remove.is_empty():
		return
	for eff_key in to_remove:
		_status_effect_instances.erase(eff_key)
	_recompute_status_stat_modifiers()
	if had_beacon_before and not _has_effect_id(&"beacon_following"):
		beacon_status_changed.emit(false)


## One dictionary per active instance: [code]instance_key[/code], [code]display_name[/code], [code]stacks[/code], [code]remaining[/code], [code]duration_fraction[/code], [code]icon[/code].
func get_active_status_effects_for_ui() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _status_effect_instances:
		var inst: StatusEffectInstance = _status_effect_instances[key]
		if inst.def == null:
			continue
		var disp := str(inst.def.display_name).strip_edges()
		if disp.is_empty():
			disp = STATUS_EFFECT_DATA.get_display_name(inst.def.effect_id)
		var ref_dur: float = inst.reference_duration
		var frac: float = 1.0
		if ref_dur > 0.001:
			frac = clampf(inst.remaining_time / ref_dur, 0.0, 1.0)
		out.append({
			"instance_key": key,
			"display_name": disp,
			"stacks": inst.stacks,
			"remaining": inst.remaining_time,
			"duration_fraction": frac,
			"icon": _get_status_effect_icon(inst),
		})
	return out


func _get_status_effect_icon(inst: StatusEffectInstance) -> Texture2D:
	if inst.def and inst.def.icon:
		return inst.def.icon
	if inst.def:
		var row := STATUS_EFFECT_DATA.get_entry(str(inst.def.effect_id))
		var p := str(row.get("icon_path", "")).strip_edges()
		if p != "" and ResourceLoader.exists(p):
			var res: Resource = load(p)
			if res is Texture2D:
				return res as Texture2D
	return null


func remove_status_effect(effect_id: StringName, stack_key: String) -> void:
	var had_effect_before := _has_effect_id(effect_id)
	var key := _status_instance_key(effect_id, stack_key)
	if not _status_effect_instances.has(key):
		return
	_status_effect_instances.erase(key)
	_recompute_status_stat_modifiers()
	if effect_id == &"beacon_following" and had_effect_before and not _has_effect_id(effect_id):
		beacon_status_changed.emit(false)


func _status_instance_key(effect_id: StringName, stack_key: String) -> String:
	return "%s::%s" % [str(effect_id), stack_key]


func _ensure_attack_cd_cache() -> void:
	for c in get_children():
		if c is Attack_Base:
			var atk: Attack_Base = c
			var tid := atk.get_instance_id()
			if not _base_attack_cd_wait.has(tid) and atk.attack_cd:
				_base_attack_cd_wait[tid] = atk.attack_cd.wait_time


func _recompute_status_stat_modifiers() -> void:
	_ensure_attack_cd_cache()
	var dmg_t: float = 1.0
	var move_m: float = 1.0
	var atk_m: float = 1.0
	_restriction_movement = false
	_restriction_basic_attacks = false
	_restriction_special_abilities = false
	_suppress_buff_application = false
	_suppress_debuff_application = false
	for key in _status_effect_instances:
		var inst: StatusEffectInstance = _status_effect_instances[key]
		if inst.def == null:
			continue
		var d: StatusEffectDef = inst.def
		dmg_t *= d.get_dmg_taken_mult_for_stacks(inst.stacks)
		move_m *= d.get_move_speed_mult_for_stacks(inst.stacks)
		atk_m *= d.get_attack_speed_mult_for_stacks(inst.stacks)
		if d.restricts_movement():
			_restriction_movement = true
		if d.restricts_basic_attacks():
			_restriction_basic_attacks = true
		if d.restricts_special_abilities():
			_restriction_special_abilities = true
		if d.suppresses_buff_application():
			_suppress_buff_application = true
		if d.suppresses_debuff_application():
			_suppress_debuff_application = true
	dmg_taken_mult = dmg_t
	move_speed = float(base_speed) * move_m * extra_move_speed_mult
	if atk_m <= 0.001:
		atk_m = 1.0
	var combined_atk = atk_m * extra_attack_speed_mult
	if combined_atk <= 0.001:
		combined_atk = 1.0
	for c in get_children():
		if c is Attack_Base:
			var atk: Attack_Base = c
			var tid := atk.get_instance_id()
			var base_w: float = float(_base_attack_cd_wait.get(tid, atk.attack_cd.wait_time if atk.attack_cd else 1.0))
			if atk.attack_cd:
				atk.attack_cd.wait_time = base_w / combined_atk


func _process_status_effects(delta: float) -> void:
	if _status_effect_instances.is_empty():
		return
	var to_remove: Array[String] = []
	for key in _status_effect_instances:
		var inst: StatusEffectInstance = _status_effect_instances[key]
		if inst.def:
			inst.def.process_instance(inst, self, delta)
		inst.remaining_time -= delta
		if inst.remaining_time <= 0.0:
			to_remove.append(key)
	for key in to_remove:
		var inst_rm: StatusEffectInstance = _status_effect_instances[key]
		var removed_effect_id: StringName = inst_rm.def.effect_id if inst_rm and inst_rm.def else &""
		_status_effect_instances.erase(key)
		_recompute_status_stat_modifiers()
		if removed_effect_id == &"beacon_following" and not _has_effect_id(&"beacon_following"):
			beacon_status_changed.emit(false)


func _has_effect_id(effect_id: StringName) -> bool:
	for key in _status_effect_instances:
		var inst: StatusEffectInstance = _status_effect_instances[key]
		if inst and inst.def and inst.def.effect_id == effect_id:
			return true
	return false
