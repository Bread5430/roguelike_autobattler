extends Button

signal click_fin()
signal click_start()

func _ready() -> void:
	set_mouse_filter(Control.MOUSE_FILTER_STOP)

func _on_mouse_entered():
	self.modulate = Color(2,2,2)

func _on_mouse_exited():
	self.modulate = Color(1,1,1)


func _on_pressed():
	$click_snd.play()
	emit_signal("click_start")
	accept_event()

func _on_click_snd_finished():
	emit_signal("click_fin")
