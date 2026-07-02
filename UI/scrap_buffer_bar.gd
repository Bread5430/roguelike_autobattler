extends Control
class_name ScrapBufferBar

const NEGATIVE_COLOR := Color(0.95, 0.25, 0.25)

@onready var _bar: ProgressBar = $MarginContainer/VBox/ProgressBar
@onready var _label: Label = $MarginContainer/VBox/Label

var _default_label_color: Color = Color.WHITE


func _ready() -> void:
	_default_label_color = _label.get_theme_color("font_color")
	update_display(0, 0)


func update_display(current: int, max_val: int) -> void:
	if max_val <= 0:
		_bar.max_value = 1.0
		_bar.value = 0.0
	else:
		_bar.max_value = float(max_val)
		_bar.value = float(clampi(current, 0, max_val))
	_label.text = "%d / %d" % [current, max_val]
	if current < 0:
		_label.add_theme_color_override("font_color", NEGATIVE_COLOR)
	else:
		_label.remove_theme_color_override("font_color")
