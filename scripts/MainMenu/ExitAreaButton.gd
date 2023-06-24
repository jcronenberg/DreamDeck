extends Button


func _on_ExitAreaButton_pressed():
	get_node("../Menu").hide_menu()
