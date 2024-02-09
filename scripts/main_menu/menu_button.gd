extends Button


@onready var menu := get_node("../Menu")


func _on_MenuButton_pressed():
	if menu.visible:
		await menu.hide_menu()
	else:
		await menu.show_menu()
