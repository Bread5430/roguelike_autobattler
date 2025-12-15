extends CanvasLayer

func post_ready():
	for i in get_children():
		if i.has_method("post_ready"):
			i.post_ready()
