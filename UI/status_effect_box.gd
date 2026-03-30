extends Control
class_name StatusEffectBox
## Single status icon with bottom-anchored semi-transparent duration overlay.

const DEFAULT_ICON := preload("res://Assets/CardSprites/circle_aoe_spell.png")

@onready var _icon: TextureRect = $IconRoot/Icon
@onready var _highlight: ColorRect = $IconRoot/DurationHighlight
@onready var _stack_label: Label = $StackLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_effect(data: Dictionary) -> void:
	var tex: Texture2D = data.get("icon")
	if tex == null:
		tex = DEFAULT_ICON
	_icon.texture = tex
	var frac: float = float(data.get("duration_fraction", 1.0))
	frac = clampf(frac, 0.0, 1.0)
	_highlight.anchor_left = 0.0
	_highlight.anchor_right = 1.0
	_highlight.anchor_top = 1.0 - frac
	_highlight.anchor_bottom = 1.0
	_highlight.offset_left = 0.0
	_highlight.offset_top = 0.0
	_highlight.offset_right = 0.0
	_highlight.offset_bottom = 0.0
	var stacks: int = int(data.get("stacks", 1))
	if stacks > 1:
		_stack_label.text = "x%d" % stacks
		_stack_label.visible = true
	else:
		_stack_label.visible = false
