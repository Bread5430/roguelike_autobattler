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
@onready var _status_popup_container: VBoxContainer = $StatusPopupContainer

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
	if _selected_unit and is_instance_valid(_selected_unit):
		if _selected_unit.status_effect_popup.is_connected(_on_selected_unit_status_popup):
			_selected_unit.status_effect_popup.disconnect(_on_selected_unit_status_popup)
	_selected_unit = unit
	if not unit or not is_instance_valid(unit):
		_selected_panel.visible = false
		return
	_selected_panel.visible = true
	_selected_sprite.texture = _get_unit_sprite_texture(unit)
	_refresh_selected_panel_labels()
	unit.status_effect_popup.connect(_on_selected_unit_status_popup)


func _on_selected_unit_status_popup(
	effect_id: StringName,
	event_type: StringName,
	stacks: int,
	remaining_seconds: float,
	icon: Texture2D
) -> void:
	var text := _format_status_popup_text(effect_id, event_type, stacks, remaining_seconds)
	_spawn_status_popup_row(text, icon)


func _format_status_popup_text(
	effect_id: StringName,
	event_type: StringName,
	stacks: int,
	remaining_seconds: float
) -> String:
	var disp := STATUS_EFFECT_DATA.get_display_name(effect_id)
	match event_type:
		&"applied", &"stacked":
			return "%s +%d (%.1fs)" % [disp, stacks, remaining_seconds]
		&"expired":
			return "%s expired" % disp
	return disp


func _spawn_status_popup_row(text: String, icon: Texture2D) -> void:
	if not _status_popup_container:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon
		tex_rect.custom_minimum_size = Vector2(20, 20)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tex_rect)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(lbl)
	row.modulate = Color(1, 1, 0.85, 1)
	_status_popup_container.add_child(row)
	_status_popup_container.move_child(row, 0)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.75)
	tw.tween_callback(func(): row.queue_free())


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
