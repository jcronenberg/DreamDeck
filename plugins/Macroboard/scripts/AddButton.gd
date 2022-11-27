extends Button

var row


func _ready():
	pass


func _on_AddButton_pressed():
	# Search for Macroboard node
	var macroboard := get_parent()
	while macroboard.name != "Macroboard":
		macroboard = macroboard.get_parent()

	macroboard.AddButton_pressed(row, get_parent().get_child_count() - 1)
