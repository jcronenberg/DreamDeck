extends Control

var row
var column


func init(init_row, init_column):
	row = init_row
	column = init_column


func toggle_add_button():
	$AddButton.visible = not $AddButton.visible


func _ready():
	pass


func _on_AddButton_pressed():
	# Search for Macroboard node
	var macroboard := get_parent()
	while macroboard.name != "Macroboard":
		macroboard = macroboard.get_parent()

	macroboard.AddButton_pressed(row, column, self)
