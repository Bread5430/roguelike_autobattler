extends CanvasLayer

@onready var gui: Control = $Gui
@onready var pause_menu: Control = $PauseMenu


func post_ready() -> void:
	for child in get_children():
		if child.has_method("post_ready"):
			child.post_ready()
