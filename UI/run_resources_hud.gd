extends PanelContainer
class_name RunResourcesHUD

@onready var _gold_label: Label = $MarginContainer/VBoxContainer/GoldLabel
@onready var _components_label: Label = $MarginContainer/VBoxContainer/ComponentsLabel


func update_values(gold: int, components: int) -> void:
	if not is_node_ready():
		return
	_gold_label.text = "Gold: %d" % gold
	_components_label.text = "Components: %d" % components


func set_map_visible(show: bool) -> void:
	visible = show
