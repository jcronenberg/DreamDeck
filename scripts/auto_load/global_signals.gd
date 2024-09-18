extends Node

signal entered_edit_mode
signal exited_edit_mode
signal config_changed
signal global_config_changed
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


func emit_config_changed():
	get_node("/root/Main/MainMenu").construct_config()
	config_changed.emit()


func emit_global_config_changed():
	get_node("/root/Main/MainMenu").edit_settings()
	global_config_changed.emit()
