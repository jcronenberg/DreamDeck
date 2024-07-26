extends CenterContainer


func _on_button_pressed():
	get_node("/root/Main/LayoutPopup").new_panel()
	GlobalSignals.enter_edit_mode()
