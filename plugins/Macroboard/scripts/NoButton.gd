extends Control
class_name NoButton

func toggle_add_button():
	$AddButton.visible = not $AddButton.visible


func set_add_button(value: bool):
	$AddButton.visible = value


func _ready():
	pass


func _on_AddButton_pressed():
	# Search for Macroboard node
	var macroboard := get_parent()
	while macroboard.name != "Macroboard":
		macroboard = macroboard.get_parent()

	macroboard.edit_button(self)
