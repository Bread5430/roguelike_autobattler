## Selected unit panel (bottom-right); updates only on click, unit death, or combat end.
extends Control

# Selected unit panel (fixed bottom-right)
@onready var _selected_panel: PanelContainer = $SelectedUnitPanel
@onready var _selected_sprite: TextureRect = $SelectedUnitPanel/HBoxContainer/UnitSprite
@onready var _selected_label_display_name: Label = $SelectedUnitPanel/HBoxContainer/StatsVBox/SelectedLabelDisplayName
@onready var _selected_label_hp: Label = $SelectedUnitPanel/HBoxContainer/StatsVBox/SelectedLabelHP
@onready var _selected_label_damage: Label = $SelectedUnitPanel/HBoxContainer/StatsVBox/SelectedLabelDamage
@onready var _selected_label_reload: Label = $SelectedUnitPanel/HBoxContainer/StatsVBox/SelectedLabelReload
@onready var _selected_label_speed: Label = $SelectedUnitPanel/HBoxContainer/StatsVBox/SelectedLabelSpeed
@onready var _selected_label_total_dmg: Label = $SelectedUnitPanel/HBoxContainer/StatsVBox/SelectedLabelTotalDamage

var _selected_unit: Base_Unit


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_panel.visible = false


func _process(_delta: float) -> void:
	if _selected_unit == null:
		return
	if not is_instance_valid(_selected_unit) or _selected_unit.curr_hp <= 0:
		set_selected_unit(null)
	else:
		_refresh_selected_panel_labels()


## Set only on click, or when unit dies / combat ends. Pass null to hide.
func set_selected_unit(unit: Base_Unit) -> void:
	_selected_unit = unit
	if not unit or not is_instance_valid(unit):
		_selected_panel.visible = false
		return
	_selected_panel.visible = true
	_selected_sprite.texture = _get_unit_sprite_texture(unit)
	_refresh_selected_panel_labels()


func _get_unit_sprite_texture(unit: Base_Unit) -> Texture2D:
	if not unit or not is_instance_valid(unit):
		return null
	var sprite: AnimatedSprite2D = unit.get_node_or_null("AnimatedSprite2D")
	if not sprite or not sprite.sprite_frames:
		return null
	var anim := sprite.animation
	if anim.is_empty():
		return null
	return sprite.sprite_frames.get_frame_texture(anim, sprite.frame)


func _get_unit_display_name(u: Base_Unit) -> String:
	if u.unit_name != "":
		return u.unit_name
	if UNIT_GLOSSARY.has_entry(u.unit_glossary_id):
		var e := UNIT_GLOSSARY.get_entry(u.unit_glossary_id)
		var dn := str(e.get("display_name", ""))
		if dn != "":
			return dn
	return u.name


func _refresh_selected_panel_labels() -> void:
	if not _selected_unit or not is_instance_valid(_selected_unit):
		return
	var u: Base_Unit = _selected_unit
	_selected_label_display_name.text = _get_unit_display_name(u)
	_selected_label_hp.text = "HP: %d / %d" % [u.curr_hp, u.max_hp]
	_selected_label_speed.text = "Movement: %d" % [int(u.move_speed)]
	_selected_label_total_dmg.text = "Damage dealt: %d" % u.total_damage_dealt
	var atk := u.get_attack_stats()
	if atk.is_empty():
		_selected_label_damage.text = "Damage/shot: —"
		_selected_label_reload.text = "Reload: —"
	else:
		var effective_dmg := int(u.get_attack_damage() * u.dmg_dealt_mult)
		_selected_label_damage.text = "Damage/shot: %d" % effective_dmg
		_selected_label_reload.text = "Reload: %.2fs" % atk.reload_time
