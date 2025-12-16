extends Button

signal click_fin()


func _on_mouse_entered():
	self.modulate = Color(2,2,2)

func _on_mouse_exited():
	self.modulate = Color(1,1,1)


func _on_pressed():
	$click_snd.play()

func _on_click_snd_finished():
	emit_signal("click_fin")
