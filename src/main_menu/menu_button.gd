extends Button


func _on_MenuButton_pressed():
	GlobalSignals.menu_open_requested.emit()
