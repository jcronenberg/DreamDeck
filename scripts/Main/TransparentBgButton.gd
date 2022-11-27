extends Button


func _on_TransparentBgButton_pressed():
	get_tree().get_root().transparent_bg = !get_tree().get_root().transparent_bg
