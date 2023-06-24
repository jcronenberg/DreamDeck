extends Button


onready var menu := get_node("../Menu")


func _on_MenuButton_pressed():
# warning-ignore:standalone_ternary
	menu.hide_menu() if menu.visible else menu.show_menu()
