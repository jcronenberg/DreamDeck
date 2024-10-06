extends Node

signal entered_edit_mode
signal exited_edit_mode
signal activated_plugins_changed


var edit_state: bool = false


func toggle_edit_mode():
	if edit_state:
		exit_edit_mode()
	else:
		enter_edit_mode()


func enter_edit_mode():
	edit_state = true
	entered_edit_mode.emit()


func exit_edit_mode():
	edit_state = false
	exited_edit_mode.emit()


func get_edit_state() -> bool:
	return edit_state
