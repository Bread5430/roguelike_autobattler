extends Node
class_name PlayerHealthManager

@export var max_health: int = 100
@export var curr_health: int = 100

var _health_snapshot_at_battle_start: int = -1
var _repair_damage_this_battle: int = 0

signal health_changed(curr: int, max_val: int)
signal game_over


func reset_for_new_campaign() -> void:
	curr_health = max_health
	_health_snapshot_at_battle_start = -1
	_repair_damage_this_battle = 0
	_emit_health_changed()


func snapshot_health_for_battle() -> void:
	_health_snapshot_at_battle_start = curr_health
	_repair_damage_this_battle = 0


func get_repair_damage_taken_this_battle() -> int:
	return _repair_damage_this_battle


func get_health_fraction() -> float:
	if max_health <= 0:
		return 0.0
	return clampf(float(curr_health) / float(max_health), 0.0, 1.0)


func sync_from_unit_hp(curr: int, max_hp: int) -> void:
	if max_hp <= 0:
		return
	curr_health = clampi(int(round(float(curr) / float(max_hp) * float(max_health))), 0, max_health)
	_emit_health_changed()


func apply_damage(amount: int) -> void:
	if amount <= 0:
		return
	curr_health = maxi(0, curr_health - amount)
	_emit_health_changed()
	if curr_health <= 0:
		game_over.emit()


func apply_damage_capped(amount: int, min_hp: int = 1) -> int:
	if amount <= 0:
		return 0
	var before := curr_health
	curr_health = maxi(min_hp, curr_health - amount)
	var applied := before - curr_health
	_repair_damage_this_battle += applied
	_emit_health_changed()
	if curr_health <= 0:
		game_over.emit()
	return applied


func restore_health_fraction(fraction: float) -> void:
	if fraction <= 0.0:
		return
	var amount := int(round(float(max_health) * fraction))
	curr_health = mini(max_health, curr_health + amount)
	_emit_health_changed()


func _emit_health_changed() -> void:
	health_changed.emit(curr_health, max_health)
