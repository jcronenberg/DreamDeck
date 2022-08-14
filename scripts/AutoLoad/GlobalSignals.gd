extends Node

signal entered_edit_mode
signal exited_edit_mode


var edit_state: bool = false


func enter_edit_mode():
	edit_state = true
	emit_signal("entered_edit_mode")


func exit_edit_mode():
	edit_state = false
	emit_signal("exited_edit_mode")


func get_edit_state() -> bool:
	return edit_state
