extends Node

signal entered_edit_mode
signal exited_edit_mode
signal config_changed


var edit_state: bool = false


func toggle_edit_mode():
	if edit_state:
		exit_edit_mode()
	else:
		enter_edit_mode()


func enter_edit_mode():
	edit_state = true
	emit_signal("entered_edit_mode")


func exit_edit_mode():
	edit_state = false
	emit_signal("exited_edit_mode")


func get_edit_state() -> bool:
	return edit_state


func config_changed():
	get_node("/root/Main/MainMenu").construct_config()
	emit_signal("config_changed")
