extends Control
class_name ItemDetailsCard

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var icon_rect: TextureRect = $Panel/Margin/VBox/Icon
@onready var details_label: Label = $Panel/Margin/VBox/Details
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _mouse_was_inside: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_details(payload: Dictionary, anchor_global_pos: Vector2) -> void:
	var display_name := str(payload.get("display_name", "Item"))
	title_label.text = display_name
	icon_rect.texture = payload.get("icon", null) as Texture2D

	var lines: Array = payload.get("lines", [])
	var rendered: PackedStringArray = []
	for line in lines:
		if not (line is Dictionary):
			continue
		var label := str(line.get("label", ""))
		var value := str(line.get("value", ""))
		if label == "":
			rendered.append(value)
		else:
			rendered.append("%s: %s" % [label, value])
	details_label.text = "\n".join(rendered)

	visible = true
	await get_tree().process_frame
	_position_near(anchor_global_pos)
	_last_mouse_pos = get_viewport().get_mouse_position()
	_mouse_was_inside = panel.get_global_rect().has_point(_last_mouse_pos)

func hide_details() -> void:
	visible = false
	_mouse_was_inside = false

func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var has_moved := mouse_pos != _last_mouse_pos
	_last_mouse_pos = mouse_pos
	if not has_moved:
		return
	var inside := panel.get_global_rect().has_point(mouse_pos)
	if inside:
		_mouse_was_inside = true
	elif _mouse_was_inside:
		hide_details()

func _position_near(anchor_global_pos: Vector2) -> void:
	var panel_size := panel.size
	var vp_rect := get_viewport_rect()
	var desired := anchor_global_pos + Vector2(12, 12)
	var max_x := maxf(0.0, vp_rect.size.x - panel_size.x)
	var max_y := maxf(0.0, vp_rect.size.y - panel_size.y)
	global_position = Vector2(clampf(desired.x, 0.0, max_x), clampf(desired.y, 0.0, max_y))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_details()
		accept_event()
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		if not panel.get_global_rect().has_point(mb.position):
			hide_details()
		accept_event()
