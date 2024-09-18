class_name LayoutEditButtons
extends HBoxContainer

signal edit_panel_button_pressed
signal add_panel_button_pressed
signal delete_panel_button_pressed


func _on_edit_panel_button_pressed():
	edit_panel_button_pressed.emit()


func _on_add_panel_button_pressed():
	add_panel_button_pressed.emit()


func _on_delete_panel_button_pressed():
	delete_panel_button_pressed.emit()
