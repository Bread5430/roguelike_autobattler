extends Node
class_name BattleSpeedController

## Owns battle combat rate via Engine.time_scale and soft-pause spell effect buffering.
## Soft pause (rate 0) is NOT get_tree().paused — PauseMenu stays orthogonal.

signal combat_speed_changed(rate: float)

const RATES: Array[float] = [0.0, 1.0, 2.0, 4.0]

var combat_speed: float = 1.0
var _rate_before_pause: float = 1.0
var _spell_buffer: Array = []
var _spell_holder: Node


func _ready() -> void:
	_spell_holder = Node.new()
	_spell_holder.name = "BufferedSpellHolder"
	add_child(_spell_holder)


func is_soft_paused() -> bool:
	return combat_speed <= 0.0


func set_combat_speed(rate: float) -> void:
	var was_paused: bool = is_soft_paused()
	var clamped: float = _clamp_rate(rate)
	if clamped <= 0.0:
		if combat_speed > 0.0:
			_rate_before_pause = combat_speed
		combat_speed = 0.0
		Engine.time_scale = 0.0
	else:
		combat_speed = clamped
		Engine.time_scale = clamped
		if was_paused:
			_flush_spell_buffer()
	combat_speed_changed.emit(combat_speed)


func toggle_soft_pause() -> void:
	if is_soft_paused():
		var resume: float = _rate_before_pause
		if resume <= 0.0:
			resume = 1.0
		set_combat_speed(resume)
	else:
		set_combat_speed(0.0)


func step_slower() -> void:
	## Among running rates only: 4 → 2 → 1. Never enters soft pause.
	if is_soft_paused():
		return
	if combat_speed >= 4.0:
		set_combat_speed(2.0)
	elif combat_speed >= 2.0:
		set_combat_speed(1.0)


func step_faster() -> void:
	## Soft-paused → 1×; else 1 → 2 → 4.
	if is_soft_paused():
		set_combat_speed(1.0)
	elif combat_speed < 2.0:
		set_combat_speed(2.0)
	elif combat_speed < 4.0:
		set_combat_speed(4.0)


func retain_spell(spell: Base_Spell) -> void:
	if spell == null or not is_instance_valid(spell):
		return
	if spell.get_parent() != _spell_holder:
		if spell.get_parent():
			spell.reparent(_spell_holder)
		else:
			_spell_holder.add_child(spell)


func queue_spell_effect(effect: Callable) -> void:
	_spell_buffer.append(effect)


func reset() -> void:
	_spell_buffer.clear()
	if _spell_holder:
		for child in _spell_holder.get_children():
			child.queue_free()
	combat_speed = 1.0
	_rate_before_pause = 1.0
	Engine.time_scale = 1.0
	combat_speed_changed.emit(combat_speed)


func _flush_spell_buffer() -> void:
	var pending: Array = _spell_buffer.duplicate()
	_spell_buffer.clear()
	for effect in pending:
		if effect is Callable and effect.is_valid():
			effect.call()


func _clamp_rate(rate: float) -> float:
	if rate <= 0.0:
		return 0.0
	if rate >= 4.0:
		return 4.0
	if rate >= 2.0:
		return 2.0
	return 1.0
