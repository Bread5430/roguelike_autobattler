extends Control
class_name BandwidthBar

const REMAINING_FILL := Color(0.32, 0.62, 0.95, 0.95)
const LOSS_FILL := Color(0.92, 0.28, 0.22, 0.9)
const TRACK_BG := Color(0.12, 0.12, 0.14, 0.9)

@onready var _remaining_bar: ProgressBar = $MarginContainer/VBox/BarStack/RemainingBar
@onready var _loss_rect: ColorRect = $MarginContainer/VBox/BarStack/LossRect
@onready var _label: Label = $MarginContainer/VBox/Label

var _remaining: int = 0
var _loss: int = 0
var _max_val: int = 0


func _ready() -> void:
	_remaining_bar.add_theme_stylebox_override("background", _make_style(TRACK_BG))
	_remaining_bar.add_theme_stylebox_override("fill", _make_style(REMAINING_FILL))
	_loss_rect.color = LOSS_FILL
	_loss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaining_bar.resized.connect(_layout_loss_rect)
	update_display(0, 0, 0)


func update_display(remaining: int, potential_losses: int, max_val: int) -> void:
	_remaining = remaining
	_loss = potential_losses
	_max_val = max_val
	var cap = maxi(1, max_val)
	_remaining_bar.max_value = float(cap)
	if max_val <= 0:
		_remaining_bar.value = 0.0
	else:
		_remaining_bar.value = float(clampi(remaining, 0, max_val))
	_label.text = "%d / %d" % [remaining, max_val]
	call_deferred("_layout_loss_rect")


func _layout_loss_rect() -> void:
	if _loss_rect == null or _remaining_bar == null:
		return
	var bar_size = _remaining_bar.size
	if bar_size.x <= 0.0:
		_loss_rect.visible = false
		return
	var cap = float(maxi(1, _max_val))
	var remaining_clamped = float(clampi(_remaining, 0, _max_val))
	var emptied = cap - remaining_clamped
	var loss_clamped = minf(float(clampi(_loss, 0, _max_val)), emptied)
	if loss_clamped <= 0.0:
		_loss_rect.visible = false
		return
	_loss_rect.visible = true
	var unit_w = bar_size.x / cap
	# Anchor to remaining's shrinking (right) edge; grow toward the track's fixed max end.
	_loss_rect.position = Vector2(remaining_clamped * unit_w, 0.0)
	_loss_rect.size = Vector2(loss_clamped * unit_w, bar_size.y)


func _make_style(color: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(2)
	return box
