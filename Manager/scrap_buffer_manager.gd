extends Node
class_name ScrapBufferManager

## Max bar capacity = enemy total scrap × this multiplier.
@export var enemy_scrap_multiplier: float = 0.8

var max_scrap: int = 0
var current_scrap: int = 0

var _prep_scrap_spent: int = 0
var _bonus_gold: int = 0
var _active: bool = false

signal scrap_changed(current: int, max_val: int)


func reset() -> void:
	max_scrap = 0
	current_scrap = 0
	_prep_scrap_spent = 0
	_bonus_gold = 0
	_active = false
	_emit_changed()


func begin_prep(enemy_total_scrap: int) -> void:
	_prep_scrap_spent = 0
	_bonus_gold = 0
	max_scrap = maxi(0, int(floor(float(enemy_total_scrap) * enemy_scrap_multiplier)))
	current_scrap = max_scrap
	_active = true
	_emit_changed()


func spend_scrap(amount: int) -> void:
	if not _active or amount <= 0:
		return
	current_scrap -= amount
	_prep_scrap_spent += amount
	_emit_changed()


func refund_scrap(amount: int) -> void:
	if not _active or amount <= 0:
		return
	current_scrap += amount
	_prep_scrap_spent = maxi(0, _prep_scrap_spent - amount)
	_emit_changed()


func on_combat_start() -> void:
	if not _active:
		return
	var refill := int(floor(float(_prep_scrap_spent) * 0.5))
	if refill > 0:
		current_scrap += refill
		_emit_changed()


func on_friendly_unit_died(unit_scrap: int) -> void:
	if not _active or unit_scrap <= 0:
		return
	var drain := int(floor(float(unit_scrap) * 0.5))
	if drain > 0:
		current_scrap -= drain
		_emit_changed()


func settle_battle() -> Dictionary:
	var repair_damage := 0
	_bonus_gold = 0
	if _active and current_scrap < 0:
		repair_damage = -current_scrap
	elif _active and current_scrap > 0:
		_bonus_gold = current_scrap
	_active = false
	return {"repair_damage": repair_damage, "bonus_gold": _bonus_gold}


func get_bonus_gold() -> int:
	return _bonus_gold


func _emit_changed() -> void:
	scrap_changed.emit(current_scrap, max_scrap)
