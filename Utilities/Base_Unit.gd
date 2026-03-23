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

var total_damage_dealt : int = 0
var dmg_dealt_mult : float = 1.0
var dmg_taken_mult : float = 1.0

# Movement Related
@export var base_speed : int
@onready var move_speed : float = base_speed
@onready var move_vec : Vector2 = Vector2.ZERO

@export var spawn_position : Vector2
@export var faction : bool


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
	var dn := str(e.get("display_name", ""))
	if dn != "":
		unit_name = dn


func _physics_process(_delta):
	move_and_slide()
	
func movement():
	velocity = move_vec.normalized() * move_speed
	

func take_damage(damage: int):
	curr_hp -= damage * dmg_taken_mult

	if curr_hp <= 0:
		state_machine.set_state(state_machine.states.dead)

func post_ready():
	for node in get_children():
		if node.has_method("post_ready"):
			node.post_ready()

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
