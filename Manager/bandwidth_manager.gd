extends Node
class_name BandwidthManager

const DEFAULT_MAX_BANDWIDTH: int = 50
## Functionally infinite bandwidth limit for formation editor
const FORMATION_EDITOR_BANDWIDTH_CAP: int = 100000

## Used by [method bandwidth_from_enemy_total] (relic TODO); not applied in prep.
@export var enemy_bandwidth_multiplier: float = 0.8

var max_bandwidth: int = DEFAULT_MAX_BANDWIDTH
var current_bandwidth: int = 0

var _prep_bandwidth_spent: int = 0
var _bonus_gold: int = 0
var _active: bool = false
## When true, current_bandwidth tracks spent cost (counts up from 0) instead of remaining budget.
var _cost_tracking_mode: bool = false

signal bandwidth_changed(current: int, max_val: int)


func reset() -> void:
	max_bandwidth = DEFAULT_MAX_BANDWIDTH
	current_bandwidth = 0
	_prep_bandwidth_spent = 0
	_bonus_gold = 0
	_active = false
	_cost_tracking_mode = false
	_emit_changed()


func begin_prep() -> void:
	_prep_bandwidth_spent = 0
	_bonus_gold = 0
	_cost_tracking_mode = false
	current_bandwidth = max_bandwidth
	_active = true
	_emit_changed()


## Formation editor: bar starts at 0 / cap; placement increases the numerator by full bandwidth cost.
func begin_formation_cost_tracking(cap: int = FORMATION_EDITOR_BANDWIDTH_CAP) -> void:
	_prep_bandwidth_spent = 0
	_bonus_gold = 0
	_cost_tracking_mode = true
	max_bandwidth = maxi(0, cap)
	current_bandwidth = 0
	_active = true
	_emit_changed()


func spend_bandwidth(amount: int) -> void:
	if not _active or amount <= 0:
		return
	if _cost_tracking_mode:
		current_bandwidth += amount
	else:
		current_bandwidth -= amount
	_prep_bandwidth_spent += amount
	_emit_changed()


func refund_bandwidth(amount: int) -> void:
	if not _active or amount <= 0:
		return
	if _cost_tracking_mode:
		current_bandwidth = maxi(0, current_bandwidth - amount)
	else:
		current_bandwidth += amount
	_prep_bandwidth_spent = maxi(0, _prep_bandwidth_spent - amount)
	_emit_changed()


func on_combat_start() -> void:
	if not _active:
		return
	var refill = int(floor(float(_prep_bandwidth_spent) * 0.5))
	if refill > 0:
		current_bandwidth += refill
		_emit_changed()


func on_friendly_unit_died(unit_bandwidth: int) -> void:
	if not _active or unit_bandwidth <= 0:
		return
	var drain = int(floor(float(unit_bandwidth) * 0.5))
	if drain > 0:
		current_bandwidth -= drain
		_emit_changed()


func increase_max(amount: int) -> void:
	if amount <= 0:
		return
	max_bandwidth += amount
	_emit_changed()


func set_max_bandwidth(value: int) -> void:
	max_bandwidth = maxi(DEFAULT_MAX_BANDWIDTH, value)
	_emit_changed()


func settle_battle() -> Dictionary:
	var repair_damage = 0
	_bonus_gold = 0
	if _active and current_bandwidth < 0:
		repair_damage = -current_bandwidth
	elif _active and current_bandwidth > 0:
		_bonus_gold = current_bandwidth
	_active = false
	return {"repair_damage": repair_damage, "bonus_gold": _bonus_gold}


func get_bonus_gold() -> int:
	return _bonus_gold


# TODO: relic — scale player bandwidth from enemy bandwidth total.
func bandwidth_from_enemy_total(enemy_total: int) -> int:
	return maxi(0, int(floor(float(enemy_total) * enemy_bandwidth_multiplier)))


func _emit_changed() -> void:
	bandwidth_changed.emit(current_bandwidth, max_bandwidth)
