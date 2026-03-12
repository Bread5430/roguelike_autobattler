## Tactical cursor tooltip: shows live unit stats on hover during deployment and combat.
extends Control

const OFFSET := Vector2(24, 24)

@onready var _panel: PanelContainer = $PanelContainer
@onready var _vbox: VBoxContainer = $PanelContainer/VBoxContainer
@onready var _label_hp: Label = $PanelContainer/VBoxContainer/LabelHP
@onready var _label_damage: Label = $PanelContainer/VBoxContainer/LabelDamage
@onready var _label_reload: Label = $PanelContainer/VBoxContainer/LabelReload
@onready var _label_speed: Label = $PanelContainer/VBoxContainer/LabelSpeed
@onready var _label_total_dmg: Label = $PanelContainer/VBoxContainer/LabelTotalDamage

var _current_unit: Base_Unit


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	_clamp_to_viewport()


## Show stats for unit; pass null to hide.
func show_unit(unit: Base_Unit) -> void:
	_current_unit = unit
	if not unit or not is_instance_valid(unit):
		visible = false
		return
	visible = true
	_update_labels()


func _update_labels() -> void:
	if not _current_unit or not is_instance_valid(_current_unit):
		return
	var u: Base_Unit = _current_unit
	_label_hp.text = "HP: %d / %d" % [u.curr_hp, u.max_hp]
	_label_speed.text = "Movement: %d" % [int(u.move_speed)]
	_label_total_dmg.text = "Damage dealt: %d" % u.total_damage_dealt

	var atk := u.get_attack_stats()
	if atk.is_empty():
		_label_damage.text = "Damage/shot: —"
		_label_reload.text = "Reload: —"
	else:
		var effective_dmg := int(atk.damage * u.dmg_dealt_mult)
		_label_damage.text = "Damage/shot: %d" % effective_dmg
		_label_reload.text = "Reload: %.2fs" % atk.reload_time


func _clamp_to_viewport() -> void:
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	var size := _panel.size
	var vp_rect := Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	var pos := mouse + OFFSET
	# Keep tooltip on screen
	if pos.x + size.x > vp_rect.end.x:
		pos.x = vp_rect.end.x - size.x
	if pos.y + size.y > vp_rect.end.y:
		pos.y = vp_rect.end.y - size.y
	if pos.x < vp_rect.position.x:
		pos.x = vp_rect.position.x
	if pos.y < vp_rect.position.y:
		pos.y = vp_rect.position.y
	position = pos
